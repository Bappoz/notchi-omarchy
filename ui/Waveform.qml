import QtQuick

Item {
    id: root

    property bool playing: false
    property bool motionEnabled: true
    property real phase: 0
    property color color: "white"
    property int barCount: 5
    property real maximumHeight: height
    property real energy: playing ? 1 : 0

    Behavior on energy {
        NumberAnimation { duration: root.motionEnabled ? 190 : 0; easing.type: Easing.OutCubic }
    }

    implicitWidth: 26
    implicitHeight: 20

    FrameAnimation {
        running: root.visible && root.energy > 0 && root.motionEnabled
        onTriggered: root.phase += frameTime
    }

    Row {
        anchors.centerIn: parent
        spacing: 3

        Repeater {
            model: root.barCount

            Item {
                required property int index

                width: 3
                height: root.maximumHeight

                Rectangle {
                    // FrameAnimation already supplies a new height each frame.
                    // A second animation here restarts before its first tick,
                    // freezing the bars at their initial height on fast displays.

                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    radius: 2
                    height: 4 + root.energy * (Math.max(4, root.maximumHeight *
                        (0.38 + 0.62 * Math.abs(Math.sin(root.phase * (3 + index * 0.7) + index * 1.3)))) - 4)
                    color: root.color
                    opacity: 0.35 + root.energy * .55
                }

            }

        }

    }

}
