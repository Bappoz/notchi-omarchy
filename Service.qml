import "." as Local
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
  property var lastWorking: []
  property bool telemetryBusy:false
  readonly property bool quotaUpdating:quotaProcess.running
  signal agentActivityStarted(string provider, string activity)
  function pollTelemetry(){
    if(telemetryBusy)return
    telemetryBusy=true
    job.createObject(root,{argv:["python3",backendPath,"telemetry"],callback:function(data){
      telemetryBusy=false
      if(!data.ok)return
      var current=(data.sessions||[]).filter(function(s){return s.working}).map(function(s){return s.id})
      var started=(data.sessions||[]).filter(function(s){return s.working&&root.lastWorking.indexOf(s.id)<0})
      telemetry=data;lastWorking=current
      if(started.length)enqueueNotice({kind:"agent",provider:started[0].provider,activity:started[0].activity||"working"})
    }})
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
    job.createObject(root,{argv:["python3",backendPath,"weather-panel"].concat(force?["force"]:[]),callback:function(data){
      weatherBusy=false
      if(data.ok&&data.weather){weather=data.weather;if(data.weatherAlert)enqueueNotice({kind:"weather",event:data.weatherAlert})}
    }})
  }
  Timer{interval:60000;running:root.pollingEnabled;repeat:true;triggeredOnStart:true;onTriggered:root.refreshWeather(false)}
  property var noticeQueue:[]
  property var currentNotice:({})
  property var noticeSeen:[]
  property double lastNoticePoll:Date.now()
  signal noticeReady()
  function enqueueNotice(value){
    var id=value.kind==="weather"?value.event.id:"agent:"+value.provider+":"+Math.floor(Date.now()/5000)
    if(noticeSeen.indexOf(id)>=0)return
    noticeSeen=noticeSeen.concat([id]).slice(-40)
    // Keep notices brief and bounded. Weather never interrupts an active agent notice.
    value.queuedAt=Date.now()
    noticeQueue=noticeQueue.filter(function(n){return !(n.kind===value.kind&&(n.kind==="weather"||n.provider===value.provider))}).concat([value]).slice(-4)
    pumpNotices()
  }
  function pumpNotices(){
    var now=Date.now(),gap=now-lastNoticePoll;lastNoticePoll=now
    if(gap>20000){noticeQueue=[];currentNotice=({});return}
    noticeQueue=noticeQueue.filter(function(n){return now-n.queuedAt<20000})
    if(!noticeQueue.length||noticeTimer.running||expandedCount>0)return
    currentNotice=noticeQueue[0];noticeQueue=noticeQueue.slice(1)
    noticeReady();noticeTimer.start()
  }
  Timer{id:noticeTimer;interval:5400;onTriggered:root.currentNotice=({})}
  Timer{interval:1000;running:true;repeat:true;onTriggered:root.pumpNotices()}

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
  property string requestedTab: "home"
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
  readonly property string countdown: Math.floor(remaining/60) + ":" + String(remaining%60).padStart(2,"0")

  Component.onCompleted: Local.Runtime.model = root
  Component.onDestruction: if(Local.Runtime.model === root)Local.Runtime.model = null

  Component { id: job; Job {} }

  function refresh() {
    if (refreshing || !pollingEnabled) return
    refreshing = true
    var revision=taskRevision
    job.createObject(root, {argv: ["python3", backendPath, "status"], callback: function(data) {
      refreshing = false
      if (data.ok) applyStatus(data,revision)
      else feedback = String(data.error || "Não foi possível ler o sistema")
    }})
  }
  function applyStatus(data,revision){
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
  Timer { interval: 1000; running: root.remaining > 0 || root.expandedCount > 0; repeat: true; onTriggered: root.now = Date.now()/1000 }
  Timer { id: feedbackTimer; interval: 7000; onTriggered: root.feedback = "" }

  ShellIpc {
    target: "bappoz.notch.service"
    function refresh(): void { root.refresh() }
    function status(): string { return JSON.stringify({loaded:true,busy:root.busy,players:root.players.length,files:root.shelf.length,agents:root.agents.length,systemBattery:root.systemBattery,lyricsState:root.lyricsState,lyricLines:root.lyrics.length}) }
  }
}
