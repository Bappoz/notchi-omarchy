import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool enabledSource: false
    property bool quiet: false
    property bool quietReady: false
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

    Timer { id: retry; interval: 30000 }
}
