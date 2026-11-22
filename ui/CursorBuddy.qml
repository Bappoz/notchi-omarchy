import QtQuick
import QtQuick.Layouts
import ".." as App

Item {
    id: root
    required property var guide
    required property var screen
    required property string label
    property bool motion: true
    readonly property real screenX: screen ? screen.x : 0
    readonly property real screenY: screen ? screen.y : 0
    property real travel: 0

    function start() {
        flight.stop()
        if (!guide) return
        travel = motion ? 0 : 1
        if (motion) flight.restart()
    }

    onGuideChanged: start()
    onMotionChanged: if (!motion) { flight.stop(); travel = 1 }
    Component.onCompleted: start()
    visible: !!guide
    enabled: false
    x: guide ? guide.start.x + (guide.target.x - guide.start.x) * travel - screenX : 0
    y: guide ? guide.start.y + (guide.target.y - guide.start.y) * travel - screenY
        - 32 * Math.sin(Math.PI * travel) : 0

    NumberAnimation {
        id: flight
        target: root
        property: "travel"
        to: 1
        duration: 660
        easing.type: Easing.InOutCubic
    }

    Icon {
        name: "cursor-buddy"
        color: "#cbb8ff"
        size: 25
    }

    Rectangle {
        x: parent.x + labelText.implicitWidth + 44 > (root.screen ? root.screen.width : 0)
            ? -width - 5 : 25
        y: 16
        width: labelText.width + 18
        height: 25
        radius: 10
        color: "#171325"
        border.color: "#6f5d9b"
        opacity: Math.max(0, (root.travel - .7) / .3)
        App.PlainLabel {
            id: labelText
            anchors.centerIn: parent
            width: Math.min(150, implicitWidth)
            text: root.label
            color: "#eaddff"
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
    }
}
