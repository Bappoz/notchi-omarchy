import QtQuick
import qs.Commons
import ".." as App

Item {
    id: root
    objectName: "notch-notification-hud"

    required property var host
    readonly property bool muted: !!host.model && host.model.notificationsMuted
    readonly property color tint: muted ? "#ff947e" : "#f1f3f9"
    property real slash: 0
    property bool initialized: false

    Accessible.role: Accessible.StaticText
    Accessible.name: label.text

    function play() {
        if (!initialized) return
        slash = muted ? 1 : 0
        if (host.motion) swing.restart()
    }

    Component.onCompleted: {
        // A newly mounted HUD starts from the opposite bell state.
        if (host.motion) slash = muted ? 0 : 1
        initialized = true
        Qt.callLater(play)
    }
    onMutedChanged: play()

    Behavior on slash {
        enabled: root.initialized
        NumberAnimation { duration: root.host.motion ? Style.duration(150) : 0; easing.type: Easing.OutCubic }
    }

    Item {
        id: symbol
        anchors.left: parent.left
        anchors.leftMargin: 19
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 24

        Icon {
            anchors.centerIn: parent
            name: "bell"
            size: 22
            color: root.tint
            transform: Rotation {
                id: pivot
                origin.x: 11
                origin.y: 4
                angle: 0
            }
        }

        Item {
            x: 2
            y: 1
            width: 29
            height: 5
            rotation: 45
            transformOrigin: Item.Left

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * root.slash
                height: 5
                radius: 2.5
                color: "#080a10"
                visible: width > 0
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * root.slash
                height: 2
                radius: 1
                color: root.tint
                visible: width > 0
            }
        }
    }

    App.PlainLabel {
        id: label
        anchors.left: symbol.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 17
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        text: root.host.t(root.muted ? "hud.notificationsMuted" : "hud.notificationsOn")
        color: root.tint
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }

    SequentialAnimation {
        id: swing
        NumberAnimation { target: pivot; property: "angle"; to: root.muted ? 13 : -16; duration: Style.duration(65); easing.type: Easing.OutCubic }
        NumberAnimation { target: pivot; property: "angle"; to: root.muted ? -5 : 11; duration: Style.duration(95); easing.type: Easing.OutCubic }
        NumberAnimation { target: pivot; property: "angle"; to: 0; duration: Style.duration(110); easing.type: Easing.OutCubic }
    }
}
