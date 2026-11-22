import QtQuick
import QtQuick.Layouts
import "ui" as UI

Item {
    id: root

    property var host: null
    property var model: null
    readonly property var player: model ? model.player : null
    readonly property var activeAgent: model ? model.activeAgent : null
    readonly property int pendingTasks: model ? model.tasks.filter(function(task) { return !task.done }).length : 0
    readonly property string trackKey: model ? model.lyricsTrackKey : ""

    function t(key) { return host ? host.t(key) : key }

    onTrackKeyChanged: {
        if (!host || !host.motion || !visible) return
        trackArrival.restart()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 12
                color: "#24242d"

                UI.Icon {
                    anchors.centerIn: parent
                    name: root.player ? "music-2" : root.activeAgent ? "" : "calendar"
                    color: root.player ? "#a9e8cf" : root.activeAgent ? "#cdbaff" : "#b4b8ca"
                    size: 18
                }

                Row {
                    anchors.centerIn: parent
                    visible: !root.player && !!root.activeAgent
                    Repeater {
                        model: root.model ? root.model.activeProviders : []
                        UI.CompactAgent {
                            required property string modelData
                            provider: modelData
                            width: 19
                            motion: !!root.host && root.host.motion
                        }
                    }
                }

                Image {
                    anchors.fill: parent
                    anchors.margins: 3
                    source: root.player ? root.player.trackArtUrl : ""
                    sourceSize: Qt.size(80, 80)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }
            }

            ColumnLayout {
                id: track
                Layout.fillWidth: true
                spacing: 3

                PlainLabel {
                    Layout.fillWidth: true
                    text: root.player ? (root.player.trackTitle || root.t("media"))
                        : root.activeAgent ? root.t("agentsWorking") : (root.host ? root.host.compactTime : "")
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                PlainLabel {
                    Layout.fillWidth: true
                    text: root.player ? (root.player.trackArtist || root.player.identity || "")
                        : root.activeAgent ? (root.activeAgent.provider === "claude" ? "Claude" : "Codex")
                        : (root.host ? root.host.compactDate : "")
                    visible: text.length > 0
                    font.pixelSize: 11
                    color: "#b5b5bf"
                }

                SequentialAnimation {
                    id: trackArrival
                    NumberAnimation { target: track; property: "opacity"; to: .45; duration: 65 }
                    NumberAnimation { target: track; property: "opacity"; to: 1; duration: 155; easing.type: Easing.OutCubic }
                }
            }

            UI.IconButton {
                iconName: root.host && root.host.held ? "pin-off" : "pin"
                hint: root.t(root.host && root.host.held ? "unpin" : "pin")
                selected: root.host ? root.host.held : false
                onClicked: if (root.host) root.host.held = !root.host.held
            }

            UI.IconButton {
                objectName: "quick-menu"
                iconName: "ellipsis"
                hint: root.t("more")
                onClicked: if (root.host) root.host.showMenu()
            }
        }

        RowLayout {
            visible: !!root.player
            Layout.alignment: Qt.AlignHCenter
            spacing: 12

            UI.IconButton {
                iconName: "backward-fill"
                hint: root.t("previous")
                enabled: !!root.player && root.player.canGoPrevious
                onClicked: root.model.previous()
            }
            UI.IconButton {
                objectName: "quick-play-pause"
                iconName: root.player && root.player.isPlaying ? "pause-fill" : "play-fill"
                hint: root.t("play")
                filled: true
                circular: true
                implicitWidth: 34
                implicitHeight: 34
                enabled: !!root.player && root.player.canTogglePlaying
                onClicked: root.model.toggleMedia()
            }
            UI.IconButton {
                iconName: "forward-fill"
                hint: root.t("next")
                enabled: !!root.player && root.player.canGoNext
                onClicked: root.model.next()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: [
                    { tab: "focus", icon: "timer", label: root.model && root.model.remaining > 0 ? root.model.countdown : root.t("focus") },
                    { tab: "daily", icon: "list-todo", label: root.t("nav.daily") + (root.pendingTasks ? " " + root.pendingTasks : "") },
                    { tab: "agents/activity", icon: "sparkles", label: root.t("nav.agents") }
                ]

                NotchButton {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    iconName: modelData.icon
                    text: modelData.label
                    compact: true
                    onClicked: root.host.openTab(modelData.tab)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            NotchButton {
                Layout.fillWidth: true
                iconName: "circle-dot"
                compact: true
                text: root.model && (root.model.stopwatchStart || root.model.stopwatchElapsed) ? root.model.stopwatchText : root.t("stopwatch")
                Accessible.name: root.model && root.model.stopwatchStart ? root.t("stopwatchStop") : root.t("stopwatchStart")
                enabled: !!root.model
                onClicked: root.model.toggleStopwatch()
            }

            UI.IconButton {
                visible: !!root.model && root.model.stopwatchElapsed > 0 && !root.model.stopwatchStart
                iconName: "undo-2"
                hint: root.t("reset")
                onClicked: root.model.stopwatchElapsed = 0
            }
        }

        Item { Layout.fillHeight: true }
    }
}
