import "." as Local
import "ui/IslandEvents.js" as Events
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import Quickshell.Services.Mpris

Item {
  id: root
  property bool pollingEnabled: true
  property var shell: null
  property var manifest: null
  property var snapshot: ({})
  property var telemetry: ({})
  readonly property var sessions: telemetry.sessions || []
  readonly property var activeAgent: sessions.find(function(session) { return session.working }) || null
  readonly property var activeProviders: ["claude", "codex"].filter(function(provider) {
    return sessions.some(function(session) { return session.provider === provider && session.working })
  })
  property var lastAgentStates: null
  property int noticeEpoch: 0
  property var previousConnections: ({})
  property bool connectionProbeBusy: false
  property bool volumeHudActive: false
  property int volumeHudLevel: 0
  property bool volumeHudMuted: false
  readonly property bool notificationsMuted: notificationSource.quiet
  property int notificationCount: notificationSource.count
  readonly property alias notificationHudActive: notificationHudTimer.running
  property double lastOsdVolumeAt: 0
  property bool cameraInUse: false
  property bool screenRecording: false
  property var previousPower: null
  property bool osdHandoverChecked: false
  property string osdHandoverProbeOutput: ""
  property string osdHandoverEnableOutput: ""

  // Upgrades from 0.6.3 or earlier via `omarchy plugin update` rescan plugins
  // without re-running `enablePlugin`, leaving `omarchy.osd` enabled alongside
  // Notchi's replacement OSD. Complete the one-time handover via Omarchy IPC.
  Process {
    id: osdHandoverProbe
    command: ["omarchy-shell", "shell", "listPlugins"]
    stdout: StdioCollector { onStreamFinished: root.osdHandoverProbeOutput = text.slice(0, 200000) }
    onExited: function(code) {
      if (code !== 0 || !root.pollingEnabled) return
      var plugins
      try { plugins = JSON.parse(root.osdHandoverProbeOutput || "[]") } catch (e) { return }
      if (Events.needsOsdHandover(plugins) && !osdHandoverEnable.running) {
        root.osdHandoverEnableOutput = ""
        osdHandoverEnable.running = true
      }
    }
  }
  Process {
    id: osdHandoverEnable
    command: ["omarchy-shell", "shell", "enablePlugin", "bappoz.notch", "{}"]
    stdout: StdioCollector { onStreamFinished: root.osdHandoverEnableOutput = text.trim() }
    onExited: function(code) {
      if (code === 0 && root.osdHandoverEnableOutput === "ok")
        root.exec(["omarchy-shell", "shell", "rescanPlugins"])
    }
  }
  Timer {
    interval: 1500
    repeat: false
    running: root.pollingEnabled && !root.osdHandoverChecked
    onTriggered: {
      root.osdHandoverChecked = true
      if (!osdHandoverProbe.running) {
        root.osdHandoverProbeOutput = ""
        osdHandoverProbe.running = true
      }
    }
  }

  // The same read-only status used by Omarchy's recording indicator. One
  // probe serves every Notchi instance, including recordings started elsewhere.
  Process {
    id: recordingStatus
    command: ["omarchy-capture-screenrecording", "--status"]
    onExited: function(code) { root.screenRecording = code === 0 }
  }
  Timer {
    interval: 1500
    repeat: true
    triggeredOnStart: true
    running: root.pollingEnabled
    onTriggered: if (!recordingStatus.running) recordingStatus.running = true
  }

  function showVolume(level, muted, allowEarlySession) {
    if (!sessionAvailable && !allowEarlySession) return
    volumeHudLevel = Math.max(0, Math.min(100, level))
    volumeHudMuted = muted
    volumeHudActive = true
    volumeHudTimer.restart()
  }

  function observePower(sample) {
    var previous = previousPower
    previousPower = sample
    var event = Events.powerEvent(previous, sample)
    if (event) enqueueNotice({kind: event, level: sample.level, tab: "system"})
  }

  Timer { id: volumeHudTimer; interval: 1450; onTriggered: root.volumeHudActive = false }

  Local.Hardware { service: root }
  Local.Voice { id: voiceAssistant; service: root }
  readonly property alias voice: voiceAssistant
  signal voiceTabRequested()


  function observeConnections(sample) {
    var previous = previousConnections
    previousConnections = sample
    for (var event of Events.newConnections(previous, sample)) enqueueNotice(event)
  }

  function pollConnections() {
    if (connectionProbeBusy || !sessionAvailable) return
    connectionProbeBusy = true
    var epoch = noticeEpoch
    job.createObject(root, {
      argv: ["/usr/bin/python3", eventAdapter, "connections"],
      callback: function(sample) {
        connectionProbeBusy = false
        if (noticeClock() && sessionAvailable && epoch === noticeEpoch) observeConnections(sample)
      }
    })
  }

  Timer {
    interval: 3000
    repeat: true
    running: root.pollingEnabled && root.sessionAvailable
    triggeredOnStart: true
    onTriggered: root.pollConnections()
  }
  property bool telemetryBusy:false
  readonly property bool quotaUpdating:quotaProcess.running
  function pollTelemetry() {
    if (telemetryBusy) return
    telemetryBusy = true
    var epoch = noticeEpoch
    job.createObject(root, {argv: ["python3", backendPath, "telemetry"], callback: function(data) {
      telemetryBusy = false
      if (!data.ok) return
      telemetry = data
      if (epoch !== noticeEpoch || !sessionAvailable) return
      observeAgents(data.sessions || [])
    }})
  }

  function observeAgents(rows) {
    var previous = lastAgentStates
    lastAgentStates = Events.agentStates(rows)
    if (!previous) return
    for (var event of Events.agentEvents(previous, rows)) enqueueNotice(event)
  }
  function refreshQuotas(force){
    if(quotaProcess.running)return
    quotaProcess.command=["omarchy-agent-usage-update"].concat(force?["--force"]:[]).concat(["claude","codex","agy"])
    quotaProcess.running=true
  }
  Process{id:quotaProcess;onExited:function(code){if(code!==0)root.feedback="Não foi possível atualizar todas as cotas; veja a idade dos valores.";root.refresh();if(root.agentDetail.id)root.loadAgentDetail(root.agentDetail.id)}}
  Timer{interval:2500;running:root.pollingEnabled;repeat:true;triggeredOnStart:true;onTriggered:root.pollTelemetry()}
  Timer{interval:300000;running:root.pollingEnabled;repeat:true;triggeredOnStart:true;onTriggered:root.refreshQuotas(false)}

  property var agentDetail:({})
  property bool detailBusy:false
  property int detailRequest:0
  property string detailError:""
  function loadAgentDetail(id){
    if(busy>=4){detailRequest++;agentDetail=({id:id});detailBusy=false;detailError="Aguarde as operações em andamento";return}
    var request=++detailRequest
    if(agentDetail.id!==id)agentDetail=({id:id});detailBusy=true;detailError="";busy++
    job.createObject(root,{argv:["python3",backendPath,"agent-detail",id],callback:function(data){
      busy--
      if(request!==detailRequest)return
      detailBusy=false
      if(data.ok){agentDetail=data.agentDetail;detailError=""}else detailError=data.error||"Unavailable"
    }})
  }
  property var tasks:[]
  property color taskColor:"#88c8ae"
  property var taskQueue:[]
  property bool taskBusy:false
  property int taskRevision:0
  function taskAction(change, callback){
    if(taskQueue.length>30)return
    taskRevision++;taskQueue=taskQueue.concat([{change:change,callback:callback}]);runTask()
  }
  function runTask(){
    if(taskBusy||!taskQueue.length)return
    var request=taskQueue[0],change=request.change;taskQueue=taskQueue.slice(1);taskBusy=true
    job.createObject(root,{argv:["python3",backendPath,"daily-tasks"],inputText:JSON.stringify(change),callback:function(data){
      taskBusy=false;taskRevision++
      if(data.ok){tasks=data.tasks;taskColor=data.taskColor}else feedback=data.error||"Falha ao salvar tarefa"
      if(request.callback)request.callback(!!data.ok)
      runTask()
    }})
  }
  property bool weatherBusy:false
  function refreshWeather(force){
    if(weatherBusy||(!pollingEnabled&&!force))return
    weatherBusy=true
    var epoch = noticeEpoch
    job.createObject(root,{argv:["python3",backendPath,"weather-panel"].concat(force?["force"]:[]),callback:function(data){
      weatherBusy=false
      if(data.ok&&data.weather){weather=data.weather;if(data.weatherAlert && epoch === noticeEpoch)enqueueNotice({kind:"weather",event:data.weatherAlert,tab:"weather"})}
    }})
  }
  Timer{interval:60000;running:root.pollingEnabled;repeat:true;triggeredOnStart:true;onTriggered:root.refreshWeather(false)}
  property var noticeQueue: []
  property var currentNotice: ({})
  property var recentNotice: ({})
  property var noticeSeen: []
  property double lastNoticePoll: Date.now()
  property double sessionConfirmedAt: 0
  readonly property bool sessionAvailable: !pollingEnabled || sessionConfirmedAt > 0
  readonly property string eventAdapter: decodeURIComponent(Qt.resolvedUrl("island_events.py").toString().replace(/^file:\/\//, ""))

  onSessionAvailableChanged: if (!sessionAvailable) clearNotices()

  function clearNotices() {
    noticeEpoch++
    lastAgentStates = null
    previousPower = null
    volumeHudActive = false
    notificationHudTimer.stop()
    previousConnections = ({})
    noticeQueue = []
    noticeSeen = []
    recentNotice = ({})
    dismissNotice()
  }

  function dismissNotice() {
    noticeTimer.stop()
    currentNotice = ({})
  }

  function noticeClock() {
    var now = Date.now()
    var gap = now - lastNoticePoll
    lastNoticePoll = now
    if (gap < 0 || gap > 8000) {
      sessionConfirmedAt = 0
      clearNotices()
      return 0
    }
    if (now - sessionConfirmedAt > 5000) sessionConfirmedAt = 0
    return now
  }

  function enqueueNotice(value) {
    var now = noticeClock()
    if (!now || !sessionAvailable || Events.priority[value.kind] === undefined) return false
    var group = [value.kind, value.provider || value.source || value.deviceId || ""].join(":")
    var id = value.kind === "weather" ? value.event.id : group
    if (noticeSeen.some(function(seen) { return seen.id === id && now - seen.at < 6000 })) return false
    noticeSeen = noticeSeen.filter(function(seen) { return now - seen.at < 6000 })
      .concat([{id: id, at: now}]).slice(-40)
    noticeQueue = Events.queue(noticeQueue, Object.assign({group: group, queuedAt: now}, value))
    pumpNotices()
    return true
  }

  function pumpNotices() {
    var now = noticeClock()
    if (!now || !sessionAvailable) return
    noticeQueue = noticeQueue.filter(function(event) { return now - event.queuedAt < 16000 })
    if (recentNotice.kind && now - recentNotice.queuedAt >= 300000) recentNotice = ({})
    if (!noticeQueue.length || expandedCount > 0) return
    var next = noticeQueue[0]
    var batteryOverNotification = next.kind === "lowBattery" && currentNotice.kind === "notification"
    var screenshotOverNotification = next.kind === "screenshot" && ["notification", "chat"].includes(currentNotice.kind)
    var incomingCall = next.kind === "call" && currentNotice.kind !== "call"
    if (noticeTimer.running && !incomingCall && !batteryOverNotification && !screenshotOverNotification) return
    noticeQueue = noticeQueue.slice(1)
    if (batteryOverNotification || screenshotOverNotification) noticeQueue = Events.queue(noticeQueue, currentNotice)
    currentNotice = next
    recentNotice = next
    noticeTimer.restart()
  }

  Timer {
    id: noticeTimer
    interval: root.currentNotice.kind === "screenshot" ? 1800 : 4800
    onTriggered: {
      root.currentNotice = ({})
      root.pumpNotices()
    }
  }

  Timer { interval: 1000; running: true; repeat: true; onTriggered: root.pumpNotices() }

  Process {
    id: sessionProbe
    property double startedAt: 0
    command: ["/usr/bin/python3", root.eventAdapter, "session"]
    onStarted: startedAt = Date.now()
    onExited: function(code) { root.sessionConfirmedAt = code === 0 && Date.now() - startedAt < 3600 ? startedAt : 0 }
  }

  Timer {
    interval: 2400
    running: root.pollingEnabled
    repeat: true
    triggeredOnStart: true
    onTriggered: sessionProbe.running = true
  }

  NotificationSource {
    id: notificationSource
    enabledSource: root.pollingEnabled && root.preferences.desktopNotices === "true"
    countNeeded: root.pollingEnabled && (root.notificationHudActive
      || ["notification", "chat"].includes(root.currentNotice.kind))
    onReceived: function(event) { root.enqueueNotice(event) }
    onQuietChanged: {
      if (quiet) root.clearDesktopNotices()
      if (quietReady && root.noticeClock() && root.sessionAvailable) notificationHudTimer.restart()
    }
    onEnabledSourceChanged: if (!enabledSource) root.clearDesktopNotices()
  }

  Timer { id: notificationHudTimer; interval: 1500 }

  function clearDesktopNotices() {
    noticeQueue = noticeQueue.filter(function(event) { return !event.source })
    if (currentNotice.source) dismissNotice()
    if (recentNotice.source) recentNotice = ({})
  }

  property var clips: []
  property var ports: []
  property var lyrics: []
  property bool lyricsSynced: true
  property string lyricsState: "idle"
  property string lyricsError: ""
  property int lyricsRequest: 0
  property string loadedLyricsKey: ""
  readonly property string lyricsTrackKey: player ? JSON.stringify([player.trackArtist,player.trackTitle,player.trackAlbum,Math.round(player.length||0)]) : ""
  onLyricsTrackKeyChanged: {
    lyricsRequest++
    lyrics=[]; lyricsState="idle"; lyricsError=""; loadedLyricsKey=""
  }
  property var audioDevices: []
  property var weather: ({})
  property var markets: []
  property var marketWarnings: []
  property var prayers: []
  property var homeDevices: []
  property var spotifyDevices: []
  property var integrationSettings: ({})
  property string feedback: ""
  property int busy: 0
  property int expandedCount: 0
  property bool refreshing: false
  property string requestedTab: "quick"
  property string selectedPlayer: ""
  readonly property var players: Mpris.players.values
  readonly property var player: {
    var all = players
    for (var i=0; i<all.length; i++) if (all[i].uniqueId === selectedPlayer) return all[i]
    for (var j=0; j<all.length; j++) if (all[j].isPlaying) return all[j]
    return all.length ? all[0] : null
  }
  readonly property string backendPath: decodeURIComponent(Qt.resolvedUrl("backend.py").toString().replace(/^file:\/\//, ""))
  readonly property var metrics: snapshot.metrics || ({})
  readonly property var agents: snapshot.agents || []
  readonly property var shelf: snapshot.shelf || []
  readonly property var clocks: snapshot.clocks || []
  readonly property var batteries: snapshot.batteries || []
  readonly property var systemBattery: snapshot.systemBattery || null
  readonly property var timer: snapshot.timer || ({})
  readonly property var preferences: snapshot.settings || ({})
  property double now: Date.now()/1000
  readonly property int remaining: Math.max(0, Math.ceil(Number(timer.end || 0)-now))
  readonly property string countdown: formatDuration(remaining)
  property double stopwatchStart: 0
  property double stopwatchElapsed: 0
  readonly property string stopwatchText: formatDuration(Math.max(0, Math.floor((stopwatchElapsed
    + (stopwatchStart ? now * 1000 - stopwatchStart : 0)) / 1000)))
  readonly property string islandClock: remaining > 0 ? countdown : stopwatchStart ? stopwatchText : ""

  function formatDuration(seconds) {
    return Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0")
  }

  function toggleStopwatch() {
    updateClock()
    if (stopwatchStart) {
      stopwatchElapsed += Math.max(0, now * 1000 - stopwatchStart)
      stopwatchStart = 0
    } else {
      stopwatchStart = now * 1000
    }
  }

  function updateClock() {
    var hadTimer = remaining > 0
    now = Date.now() / 1000
    if (hadTimer && !remaining) enqueueNotice({kind: "timer", tab: "focus"})
  }

  Component.onCompleted: Local.Runtime.model = root
  Component.onDestruction: if(Local.Runtime.model === root)Local.Runtime.model = null

  Component { id: job; Job {} }

  function refresh() {
    if (refreshing || !pollingEnabled) return
    refreshing = true
    var revision=taskRevision
    job.createObject(root, {argv: ["python3", backendPath, "status"], callback: function(data) {
      refreshing = false
      if (data.ok) {applyStatus(data,revision);if(data.timerMigrationWarning)feedback=data.timerMigrationWarning}
      else feedback = String(data.error || "Não foi possível ler o sistema")
    }})
  }
  function applyStatus(data,revision){
    updateClock()
    snapshot=data
    if(revision===taskRevision&&!taskBusy&&!taskQueue.length){tasks=data.tasks||[];taskColor=data.taskColor||"#88c8ae"}
  }
  function action(name, args, callback, inputText) {
    if (busy >= 4) { feedback = "Aguarde as operações em andamento"; return }
    busy++
    job.createObject(root, {argv: ["python3",backendPath,name].concat(args || []), inputText: inputText || "", callback:function(data) {
      busy--
      feedback = String(data.ok ? (data.message || "") : data.error || "Operação indisponível")
      if (data.clipboard) clips = data.clipboard
      if (data.ports) ports = data.ports
      if (data.lyrics) {
        lyrics = data.lyrics; lyricsSynced = data.synced !== false
        lyricsState = "ready"; lyricsError = ""; loadedLyricsKey = lyricsTrackKey
      }
      if (data.integrationSettings)integrationSettings=data.integrationSettings
      if (data.weather) weather=data.weather
      if (data.markets) markets=data.markets
      if (data.marketWarnings) marketWarnings=data.marketWarnings
      if (data.prayers) prayers=data.prayers
      if (data.homeDevices) homeDevices=data.homeDevices
      if (data.spotifyDevices) spotifyDevices=data.spotifyDevices
      if (data.audioDevices) audioDevices = data.audioDevices
      if (callback) callback(data)
      refresh()
      feedbackTimer.restart()
    }})
  }
  function loadLyrics(force) {
    if (!player || !player.trackTitle || !player.trackArtist) return
    var key=lyricsTrackKey
    if (!force && ((lyricsState==="loading" && loadedLyricsKey===key) || (lyricsState==="ready" && loadedLyricsKey===key))) return
    if (busy>=4) { lyricsState="error";lyricsError="Aguarde as operações em andamento";return }
    var request=++lyricsRequest
    loadedLyricsKey=key; lyrics=[]; lyricsState="loading"; lyricsError=""; busy++
    job.createObject(root, {argv:["python3",backendPath,"lyrics-online"],inputText:JSON.stringify({artist:player.trackArtist,title:player.trackTitle,album:player.trackAlbum||"",duration:String(player.length||0)}),callback:function(data){
      busy--
      // A response for the previous song must never replace the current lyrics.
      if(request!==lyricsRequest || key!==lyricsTrackKey)return
      if(data.ok && data.lyrics && data.lyrics.length) {
        lyrics=data.lyrics; lyricsSynced=data.synced!==false; lyricsState="ready"
      } else {
        lyricsState="error"; lyricsError=String(data.error||"Letra não encontrada para esta faixa")
      }
    }})
  }
  function exec(argv) { Quickshell.execDetached(argv) }
  function panel(id) { exec(["omarchy-shell","shell","toggle",id]) }
  function toggleMedia() { if (player && player.canTogglePlaying) player.togglePlaying() }
  function next() { if (player && player.canGoNext) player.next() }
  function previous() { if (player && player.canGoPrevious) player.previous() }
  function expanded(value) { expandedCount = Math.max(0, expandedCount + (value ? 1 : -1)); if(value) refresh() }

  Timer { interval: root.expandedCount > 0 ? 8000 : 60000; running: root.pollingEnabled; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
  Timer { interval: 1000; running: root.remaining > 0 || root.stopwatchStart > 0 || root.expandedCount > 0; repeat: true; onTriggered: root.updateClock() }
  Timer { id: feedbackTimer; interval: 7000; onTriggered: root.feedback = "" }

  ShellIpc {
    target: "bappoz.notch.service"
    function refresh(): void { root.refresh() }
    function voice(): void { voiceAssistant.toggle() }
    function cancelVoice(): void { voiceAssistant.cancel() }
    function event(kind: string): string {
      var routes = {report: "", transfer: "", call: "", attention: "agents/activity", done: "agents/activity"}
      if (!Object.prototype.hasOwnProperty.call(routes, kind)) return "unsupported"
      return root.enqueueNotice({kind: kind, tab: routes[kind]}) ? "queued" : "ignored"
    }
    function status(): string { return JSON.stringify({loaded:true,busy:root.busy,players:root.players.length,files:root.shelf.length,agents:root.agents.length,systemBattery:root.systemBattery,lyricsState:root.lyricsState,lyricLines:root.lyrics.length}) }
  }
}
