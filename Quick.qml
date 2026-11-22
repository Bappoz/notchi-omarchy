import QtQuick
import QtQuick.Layouts
import "ui" as UI

Item {
    id: root

    property var host: null
    property var model: null
    readonly property var player: model ? model.player : null
    readonly property var agent: model ? model.activeAgent : null
    readonly property bool stopwatchVisible: !!model && !!(model.stopwatchStart || model.stopwatchElapsed)

    function t(key) { return host ? host.t(key) : key }

    RowLayout {
        anchors.fill: parent
        spacing: 9

        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: 12
            color: "#1e1f25"
            border.color: "#18ffffff"

            UI.Icon {
                anchors.centerIn: parent
                name: root.player ? "emblem-music" : root.agent ? "emblem-agents" : "emblem-calendar"
                size: 20
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

            TapHandler {
                cursorShape: Qt.PointingHandCursor
                onTapped: if (root.host) root.host.openTab(root.player ? "home" : root.agent ? "agents/activity" : "calendar")
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            PlainLabel {
                Layout.fillWidth: true
                text: root.player ? (root.player.trackTitle || root.t("media"))
                    : root.agent ? root.t("agentsWorking") : (root.host ? root.host.compactTime : "")
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            PlainLabel {
                Layout.fillWidth: true
                text: root.player ? (root.player.trackArtist || root.player.identity || "")
                    : root.agent ? (root.agent.provider === "claude" ? "Claude" : "Codex")
                    : (root.host ? root.host.compactDate : "")
                color: "#b4b7c3"
                font.pixelSize: 11
                visible: text.length > 0
            }
        }

        RowLayout {
            visible: !!root.player
            spacing: 0

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
                selected: true
                circular: true
                glyphMotion: !!root.host && root.host.motion
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

        NotchButton {
            visible: !!root.model && root.model.remaining > 0
            iconName: "emblem-focus"
            text: visible ? root.model.countdown : ""
            compact: true
            plain: true
            motionEnabled: !!root.host && root.host.motion
            Accessible.name: root.t("focus") + " " + text
            onClicked: root.host.openTab("focus")
        }

        NotchButton {
            objectName: "quick-stopwatch"
            iconName: "emblem-stopwatch"
            text: root.stopwatchVisible ? root.model.stopwatchText : ""
            compact: true
            plain: true
            motionEnabled: !!root.host && root.host.motion
            Accessible.name: root.t(root.model && root.model.stopwatchStart ? "stopwatchStop" : "stopwatchStart")
            enabled: !!root.model
            onClicked: root.model.toggleStopwatch()
        }

        UI.IconButton {
            visible: root.stopwatchVisible && !root.model.stopwatchStart
            iconName: "undo-2"
            hint: root.t("reset")
            onClicked: root.model.stopwatchElapsed = 0
        }

        UI.SettingsButton { objectName: "quick-settings"; host: root.host; visible: !!root.host }
    }
}
