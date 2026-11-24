import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import qs.Commons

Item {
    id: root

    required property var host
    required property bool available
    required property real leftEdge
    required property real rightEdge
    required property real centerY
    required property real screenWidth

    readonly property bool recording: !!host.model && host.model.screenRecording
    readonly property bool expanded: available && pointer.hovered
    property real progress: expanded ? 1 : 0
    property real recordingPulse: 0

    readonly property color fill: Qt.alpha(host.surfaceColor, 1)
    readonly property color recordColor: "#ff696e"
    readonly property real openAmount: Math.max(0, Math.min(1, progress))
    readonly property real triggerDiameter: 16 + 2 * openAmount
    readonly property real actionDiameter: 18
    readonly property real targetWidth: 24
    readonly property real budDistance: 13 + 8 * progress
    readonly property real stretch: 2.4 * Math.sin(Math.PI * openAmount)
    readonly property real rightRoom: screenWidth - rightEdge
    readonly property real leftRoom: leftEdge
    readonly property real openMargin: 21 + targetWidth / 2 + 8
    readonly property bool extendsRight: rightRoom >= openMargin + actions.length * 25 || rightRoom >= leftRoom
    readonly property real step: Math.min(25, (Math.max(rightRoom, leftRoom) - openMargin) / actions.length)
    readonly property real fullWidth: openMargin + actions.length * step
    readonly property var actions: [
        {key: "record", icon: "video", command: ["omarchy-menu", "toggle", "trigger.capture.screenrecord"]},
        {key: "awake", icon: "coffee", command: ["omarchy-shell", "idle", "toggle"]},
        {key: "night", icon: "moon", command: ["omarchy-shell", "nightlight", "toggle"]},
        {key: "dnd", icon: "bell-off", command: ["omarchy-shell", "notifications", "toggleDnd"]},
        {key: "reminder", icon: "timer", command: ["omarchy-reminder", "-i"]}
    ]

    function outward(distance) {
        return extendsRight ? distance : width - distance
    }

    function actionTravel(index) {
        var delay = .19 + index * .065
        return Math.max(0, (progress - delay) / (1 - delay))
    }

    function actionDistance(index) {
        return budDistance + step * (index + 1) * actionTravel(index)
    }

    visible: available && step >= actionDiameter + 1
    width: expanded || progress > .001 ? fullWidth : 25
    height: 26
    x: extendsRight ? rightEdge : leftEdge - width
    y: Math.max(0, centerY - height / 2)

    Behavior on progress {
        NumberAnimation {
            duration: root.host.motion && root.available ? Style.duration(root.expanded ? 395 : 255) : 0
            easing.type: Easing.Bezier
            easing.bezierCurve: root.expanded ? [0.25, 0.58, 0.28, 1.04, 1, 1] : [0.42, 0, 0.24, 1, 1, 1]
        }
    }

    SequentialAnimation on recordingPulse {
        running: root.visible && root.recording && root.host.motion
        loops: Animation.Infinite
        onRunningChanged: if (!running) root.recordingPulse = 0
        NumberAnimation { from: 0; to: 1; duration: Style.duration(780); easing.type: Easing.OutCubic }
    }

    HoverHandler {
        id: pointer
    }

    Repeater {
        model: root.actions.length

        Shape {
            id: bridge

            required property int index
            readonly property real near: index === 0 ? root.budDistance : root.actionDistance(index - 1)
            readonly property real far: root.actionDistance(index)
            readonly property real separation: Math.abs(far - near)
            readonly property real strength: Math.max(0, 1 - separation / (root.actionDiameter + 3))
            readonly property real rim: 5.8 * Math.sqrt(strength)
            readonly property real neck: 2.8 * strength

            x: Math.min(root.outward(near), root.outward(far))
            width: separation
            height: root.height
            visible: root.host.motion && separation > .4 && strength > 0
                && root.actionTravel(index) > .02 && root.openAmount < 1

            ShapePath {
                strokeWidth: -1
                fillColor: root.fill
                startX: 0
                startY: bridge.height / 2 - bridge.rim
                PathQuad {
                    x: bridge.width; y: bridge.height / 2 - bridge.rim
                    controlX: bridge.width / 2; controlY: bridge.height / 2 + bridge.rim - 2 * bridge.neck
                }
                PathLine { x: bridge.width; y: bridge.height / 2 + bridge.rim }
                PathQuad {
                    x: 0; y: bridge.height / 2 + bridge.rim
                    controlX: bridge.width / 2; controlY: bridge.height / 2 - bridge.rim + 2 * bridge.neck
                }
                PathLine { x: 0; y: bridge.height / 2 - bridge.rim }
            }
        }
    }

    Repeater {
        model: root.actions

        DotButton {
            required property var modelData
            required property int index
            objectName: "notch-quick-" + modelData.key
            readonly property bool isRecording: modelData.key === "record" && root.recording
            readonly property bool isMuted: modelData.key === "dnd" && root.host.model && root.host.model.notificationsMuted
            readonly property real travel: Math.min(1, root.actionTravel(index))

            x: root.outward(root.actionDistance(index)) - width / 2
            diameter: root.triggerDiameter + (root.actionDiameter - root.triggerDiameter) * travel
            glyphOpacity: Math.max(0, Math.min(1, (travel - .38) / .42))
            visible: travel > .025
            enabled: root.expanded && travel > .8
            label: root.host.t(isRecording ? "stopRecord" : modelData.key)
            glyph: modelData.icon
            tint: isRecording ? root.recordColor : isMuted ? "#ffc17c" : "#efeff1"
            stopMark: isRecording
            onClicked: root.host.model.exec(isRecording
                ? ["omarchy-capture-screenrecording", "--stop-recording"] : modelData.command)
        }
    }

    DotButton {
        objectName: "notch-quick-trigger"
        x: root.outward(root.budDistance) - width / 2
        diameter: root.triggerDiameter
        stretch: root.stretch
        label: root.host.t("settings")
        glyph: "settings"
        tint: "#c2cdec"
        gear: true
        Accessible.description: root.recording ? root.host.t("screenRecording") : ""
        recordMark: root.recording
        onClicked: {
            root.host.held = true
            root.host.openTab("settings")
        }
    }

    component DotButton: AbstractButton {
        id: button

        required property string label
        required property real diameter
        property real stretch: 0
        property string glyph: ""
        property color tint: "white"
        property real glyphOpacity: 1
        property bool recordMark: false
        property bool stopMark: false
        property bool gear: false
        readonly property bool highlighted: enabled && (hovered || activeFocus)
        property real emphasis: highlighted ? 1 : 0

        Behavior on emphasis {
            NumberAnimation {
                duration: root.host.motion ? Style.duration(125) : 0
                easing.type: Easing.OutCubic
            }
        }

        width: root.targetWidth
        height: root.height
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        Accessible.name: label
        Keys.onReturnPressed: clicked()
        ToolTip.visible: hovered && enabled
        ToolTip.delay: 650
        ToolTip.text: label

        background: Rectangle {
            anchors.centerIn: parent
            width: button.diameter + button.stretch
            height: button.diameter - button.stretch * .62
            radius: height / 2
            scale: 1 + .11 * button.emphasis
            color: Qt.tint(root.fill, Qt.alpha("#9299c0", .32 * button.emphasis))
            border.color: Qt.alpha("#c2cdec", .54 * button.emphasis)
        }

        contentItem: Item {
            Icon {
                anchors.centerIn: parent
                name: button.glyph
                size: 11
                color: button.tint
                opacity: button.glyphOpacity
                rotation: button.gear ? 42 * button.emphasis : 0
                scale: 1 + .08 * button.emphasis
                visible: name !== "" && !button.stopMark
            }
            Rectangle {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: button.recordMark ? 6 : 0
                anchors.verticalCenterOffset: button.recordMark ? -6 : 0
                width: button.stopMark ? 6 : 4
                height: width
                radius: button.stopMark ? 1 : width / 2
                color: root.recordColor
                opacity: button.glyphOpacity
                visible: button.recordMark || button.stopMark
            }
            Rectangle {
                anchors.centerIn: parent
                width: 5 + root.recordingPulse * 11
                height: width
                radius: width / 2
                color: "transparent"
                border.color: root.recordColor
                opacity: (1 - root.recordingPulse) * .8
                visible: button.recordMark && root.host.motion
            }
        }
    }
}
