import QtQuick
import Quickshell
import Quickshell.Io
import "ui/VoiceCommands.js" as Commands

Item {
    id: root

    required property var service
    readonly property string adapter: decodeURIComponent(Qt.resolvedUrl("voice.py").toString().replace(/^file:\/\//, ""))
    property string phase: ""
    property real level: 0
    property bool recorderStarted: false
    property string appName: ""
    property var guide: null

    function toggle() {
        if (!service.sessionAvailable) return
        if (phase === "listening" || phase === "preparing") {
            phase = "processing"
            if (recorderStarted) recorder.write("stop\n")
        } else if (!recorder.running) {
            feedback.stop()
            guide = null
            level = 0
            recorderStarted = false
            phase = "preparing"
            recorder.running = true
        }
    }

    function cancel() {
        if (recorder.running) recorder.signal(15)
        if (finder.running) finder.running = false
        feedback.stop()
        phase = ""
        guide = null
    }

    function finish(next) {
        phase = next
        feedback.restart()
    }

    function handle(transcript) {
        if (!service.sessionAvailable) return
        var result = Commands.resolve(transcript, DesktopEntries.applications.values)
        if (!result) { finish("unsupported"); return }

        if (result.action === "app") {
            appName = result.app.name
            result.app.execute()
            finish("opening")
            if (!finder.running) {
                finder.command = ["/usr/bin/python3", adapter, "guide"].concat(Commands.windowClasses(result.app))
                finder.running = true
            }
            return
        }
        if (result.action === "tab") {
            service.requestedTab = result.tab
            service.voiceTabRequested()
        } else if (["raise", "lower", "mute", "volume"].includes(result.action)) {
            var value = result.action === "raise" ? "5%+" : result.action === "lower" ? "5%-" : result.level + "%"
            var command = result.action === "mute" ? ["set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
                : ["set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", value]
            service.exec(["wpctl"].concat(command))
        } else if (service.player) {
            if (result.action === "next") service.next()
            else if (result.action === "play" && service.player.canPlay) service.player.play()
            else if (result.action === "pause" && service.player.canPause) service.player.pause()
        } else {
            finish("noMedia")
            return
        }
        finish("")
    }

    Timer { id: feedback; interval: 2500; onTriggered: { root.phase = ""; root.guide = null } }

    Process {
        id: recorder
        command: ["/usr/bin/python3", root.adapter]
        stdinEnabled: true
        onStarted: {
            root.recorderStarted = true
            if (root.phase === "processing") write("stop\n")
        }
        stdout: SplitParser {
            onRead: function(line) {
                var event
                try { event = JSON.parse(line) } catch (error) { return }
                if (!root.phase || !root.service.sessionAvailable) return
                if (event.level !== undefined) {
                    root.level = event.level
                    if (root.phase === "preparing") root.phase = "listening"
                } else if (event.phase) root.phase = event.phase
                else if (event.text) root.handle(event.text)
                else if (event.error) root.finish(event.error)
            }
        }
        onExited: {
            if (root.phase === "preparing" || root.phase === "listening" || root.phase === "processing")
                root.finish("unavailable")
        }
    }

    Process {
        id: finder
        stdout: SplitParser {
            onRead: function(line) {
                if (!root.service.sessionAvailable || root.phase !== "opening") return
                try { root.guide = JSON.parse(line) } catch (error) { return }
                feedback.restart()
            }
        }
    }

    Connections {
        target: root.service
        function onSessionAvailableChanged() { if (!root.service.sessionAvailable) root.cancel() }
    }
}
