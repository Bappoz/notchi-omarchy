import QtQuick

Item {
    id: root

    required property string provider
    property bool motion: true
    property real eyeHeight: 3.5
    readonly property bool claude: provider === "claude"

    implicitWidth: 22
    implicitHeight: 20
    Accessible.name: claude ? "Claude" : "Codex"
    Accessible.role: Accessible.Graphic

    Image {
        anchors.centerIn: parent
        width: 16
        height: 16
        source: root.claude ? "" : Qt.resolvedUrl("../assets/providers/codex.svg")
        sourceSize: Qt.size(32, 32)
        opacity: .93
    }

    Item {
        visible: root.claude
        anchors.centerIn: parent
        width: 20
        height: 17

        Rectangle {
            x: 3; y: 2; width: 14; height: 11; radius: 3
            gradient: Gradient {
                GradientStop { position: 0; color: "#ffc299" }
                GradientStop { position: 1; color: "#d87c56" }
            }
        }

        Repeater {
            model: [1, 16]
            Rectangle {
                required property int modelData
                x: modelData; y: 6; width: 3; height: 4; radius: 1
                color: "#e99b75"
            }
        }

        Repeater {
            model: [4, 7.5, 11, 14.5]
            Rectangle {
                required property real modelData
                x: modelData; y: 12; width: 1.7; height: 3; radius: .7
                color: "#d87c56"
            }
        }

        Repeater {
            model: [7, 12]
            Rectangle {
                required property int modelData
                x: modelData; y: 8.5 - height / 2; width: 1.6
                height: root.eyeHeight; radius: .8
                color: "#522e29"
            }
        }
    }

    SequentialAnimation on eyeHeight {
        running: root.claude && root.motion && root.visible
        loops: Animation.Infinite
        PauseAnimation { duration: 3100 }
        NumberAnimation { from: 3.5; to: 1; duration: 85; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1; to: 3.5; duration: 115; easing.type: Easing.OutSine }
        onStopped: root.eyeHeight = 3.5
    }
}
