import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool enabledSource: false
    property bool quiet: false
    property bool quietReady: false
    property bool countNeeded: false
    property int count: -1
    readonly property string adapterPath: decodeURIComponent(Qt.resolvedUrl("island_events.py").toString().replace(/^file:\/\//, ""))
    signal received(var event)

    FileView {
        id: quietFile
        path: Quickshell.env("HOME") + "/.local/state/omarchy/notifications/quiet.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                var dnd = JSON.parse(text()).dnd;
                if (typeof dnd === "boolean") root.quiet = dnd;
            } catch (error) {
                // A new store is empty. Keep the last state if a reload is incomplete.
            }
            root.quietReady = true;
        }
        onLoadFailed: root.quietReady = true
    }

    Process {
        id: monitor
        running: root.enabledSource && !retry.running
        command: ["/usr/bin/python3", root.adapterPath]
        stdout: SplitParser {
            onRead: function(line) {
                if (root.quiet || line.length > 160) return;
                try { root.received(JSON.parse(line)); }
                catch (error) {}
            }
        }
        stderr: SplitParser { onRead: function(line) {} }
        onExited: if (root.enabledSource) retry.restart()
    }

    onEnabledSourceChanged: if (!enabledSource) retry.stop()
    onCountNeededChanged: if (!countNeeded) count = -1

    // Read the daemon's numeric count while a bell HUD needs it. No message
    // text or history is needed, and a missing daemon leaves the count unknown.
    Process {
        id: countReader
        command: ["omarchy-shell", "-q", "notifications", "count"]
        stdout: StdioCollector { id: countOutput }
        onExited: function(code) {
            if (!root.countNeeded) return;
            var value = countOutput.text.trim();
            root.count = code === 0 && /^\d{1,6}$/.test(value) ? Number(value) : -1;
        }
    }

    Timer {
        interval: 400
        repeat: true
        triggeredOnStart: true
        running: root.countNeeded
        onTriggered: if (!countReader.running) countReader.running = true
    }

    Timer { id: retry; interval: 30000 }
}
