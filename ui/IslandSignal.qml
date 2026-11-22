import QtQuick

Item {
    id: root

    property string kind: ""
    property string name: ""
    property color tint: "#d7d7df"
    property bool motion: true
    property double alertAt: 0
    property real tilt: 0

    implicitWidth: 26
    implicitHeight: 22

    Waveform {
        anchors.centerIn: parent
        width: 23
        height: 20
        maximumHeight: 15
        playing: root.kind === "media"
        motionEnabled: root.motion
        color: "#a2e9cc"
        opacity: playing ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation { duration: root.motion ? 180 : 0; easing.type: Easing.OutCubic }
        }
    }

    Icon {
        id: glyph
        anchors.centerIn: parent
        size: 15
        color: root.tint
        rotation: root.tilt
        opacity: root.kind === "media" || root.name === "" ? 0 : 1
        visible: opacity > 0

        Behavior on name {
            enabled: root.motion && glyph.visible
            SequentialAnimation {
                NumberAnimation { target: glyph; property: "scale"; to: .65; duration: 65 }
                PropertyAction {}
                NumberAnimation { target: glyph; property: "scale"; to: 1; duration: 140; easing.type: Easing.OutCubic }
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: root.motion ? 170 : 0 }
        }
    }

    Binding { target: glyph; property: "name"; value: root.name }

    SequentialAnimation {
        id: ring
        NumberAnimation { target: root; property: "tilt"; to: -15; duration: 95; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "tilt"; to: 11; duration: 125; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "tilt"; to: -6; duration: 100; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "tilt"; to: 0; duration: 140; easing.type: Easing.OutCubic }
    }

    onAlertAtChanged: if (alertAt && motion) ring.restart()
    onMotionChanged: if (!motion) { ring.stop(); tilt = 0 }
}
