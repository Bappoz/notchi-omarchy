import QtQuick
import QtQuick.Layouts
import ".." as App

Item {
    id: root
    required property var host
    readonly property var voice: host.model.voice
    readonly property bool listening: voice.phase === "listening"
    readonly property bool preparing: voice.phase === "preparing"
    readonly property color tint: listening ? "#b79bff" : "#a7c8ff"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 17
        spacing: 10

        Icon {
            name: root.listening || root.preparing ? "emblem-voice" : root.voice.phase === "opening" ? "app-window" : "sparkles"
            color: root.listening || root.preparing ? "white" : root.tint
            size: 18
        }

        App.PlainLabel {
            Layout.fillWidth: true
            text: host.t("voice." + (root.voice.phase || "listening"))
                + (root.voice.phase === "opening" ? " " + root.voice.appName : "")
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        Row {
            visible: root.listening
            spacing: 3

            Repeater {
                model: [0.38, 0.65, 1.0, 0.77, 0.52, 0.34]
                Rectangle {
                    required property real modelData
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 4 + 19 * modelData * root.voice.level
                    radius: width / 2
                    color: root.tint

                    Behavior on height {
                        NumberAnimation { duration: root.host.motion ? 90 : 0; easing.type: Easing.OutCubic }
                    }
                }
            }
        }

        CameraLight { visible: host.model.cameraInUse }
    }
}
