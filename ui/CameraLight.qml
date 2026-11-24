import QtQuick

Item {
    id: root
    implicitWidth: 16
    implicitHeight: 18
    readonly property color tint: "#81eb9f"

    Rectangle {
        id: halo
        anchors.centerIn: parent
        width: 16
        height: width
        radius: width / 2
        color: Qt.alpha(parent.tint, .16)
        Rectangle {
            anchors.centerIn: halo
            anchors.alignWhenCentered: false
            width: 7
            height: width
            radius: width / 2
            color: root.tint
        }
    }
}
