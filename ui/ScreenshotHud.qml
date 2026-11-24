import QtQuick
import qs.Commons
import ".." as App

Item {
    id: root
    objectName: "notch-screenshot-hud"

    required property var host
    readonly property color tint: "#a7eaff"
    property real shutter: 0

    Accessible.role: Accessible.StaticText
    Accessible.name: caption.text

    Component.onCompleted: if (host.motion) expose.start()

    SequentialAnimation {
        id: expose
        NumberAnimation { target: root; property: "shutter"; from: 0; to: 1; duration: Style.duration(95); easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "shutter"; to: 0; duration: Style.duration(245); easing.type: Easing.OutCubic }
    }

    Item {
        id: viewfinder
        width: 36
        height: 32
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            anchors.centerIn: parent
            width: 31 + 5 * root.shutter
            height: 25 + 4 * root.shutter
            radius: 7
            color: Qt.alpha(root.tint, .07 + .38 * root.shutter)
            border.color: Qt.alpha(root.tint, .56 + .44 * root.shutter)
        }

        Icon {
            anchors.centerIn: parent
            name: "camera"
            size: 17
            scale: 1 - .17 * root.shutter
            color: Qt.tint(root.tint, Qt.alpha("white", root.shutter))
        }
    }

    App.PlainLabel {
        id: caption
        anchors.left: viewfinder.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 17
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        text: root.host.t("island.screenshot")
        color: root.tint
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }
}
