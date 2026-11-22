import QtQuick
import QtQuick.Controls
import qs.Commons

AbstractButton {
    id: root

    property string iconName: "sparkles"
    property int iconSize: 15
    property bool selected: false
    property bool circular: false
    property bool filled: false
    property bool flatSelection: false
    property real idleOpacity: 0.58
    property bool glyphMotion: true
    property real glyphRotation: 0
    property color tint: "white"
    property string hint: ""

    implicitWidth: 28
    implicitHeight: 26
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: hint
    Accessible.role: Accessible.Button
    scale: down ? 0.9 : hovered && circular ? 1.06 : 1
    ToolTip.visible: hovered && hint !== ""
    ToolTip.delay: 500
    ToolTip.text: hint
    Keys.onReturnPressed: clicked()

    Behavior on scale {
        NumberAnimation {
            duration: root.glyphMotion ? Style.duration(150) : 0
            easing.type: Easing.OutCubic
        }

    }

    contentItem: Item {
        Icon {
            anchors.centerIn: parent
            name: root.iconName
            size: root.iconSize
            rotation: root.glyphRotation
            Behavior on rotation {
                NumberAnimation { duration: root.glyphMotion ? Style.duration(240) : 0; easing.type: Easing.OutCubic }
            }
            color: root.filled ? "#000000" : root.tint
            opacity: root.enabled ? (root.selected || root.hovered || root.filled ? 1 : root.idleOpacity) : 0.2
        }

    }

    background: Rectangle {
        radius: root.circular ? width / 2 : 6
        color: root.filled ? "white" : root.selected && !root.flatSelection ? "#2effffff" : root.hovered || root.activeFocus ? "#16ffffff" : "transparent"
        border.color: root.activeFocus ? "#88ffffff" : "transparent"
    }

}
