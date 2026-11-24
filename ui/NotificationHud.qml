import QtQuick
import qs.Commons
import ".." as App

Item {
    id: root
    objectName: "notch-notification-hud"

    required property var host
    property bool incoming: false
    readonly property bool muted: !incoming && !!host.model && host.model.notificationsMuted
    readonly property int count: host.model ? host.model.notificationCount : -1
    readonly property color tint: incoming || muted ? "#ffcf66" : "#75e2a7"
    property real slash: 0
    property bool initialized: false

    Accessible.role: Accessible.StaticText
    Accessible.name: label.text + (count >= 0 ? " · " + I18n.formatNumber(count) : "")

    function play() {
        if (!initialized) return
        slash = muted ? 1 : 0
        if (host.motion) swing.restart()
    }

    Component.onCompleted: {
        // A newly mounted HUD starts from the opposite bell state.
        if (host.motion && !incoming) slash = muted ? 0 : 1
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

    Rectangle {
        id: badge
        anchors.left: symbol.right
        anchors.leftMargin: 5
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(19, number.implicitWidth + 8)
        height: 17
        radius: height / 2
        color: root.tint
        visible: root.count >= 0

        App.PlainLabel {
            id: number
            objectName: "notch-notification-count"
            anchors.centerIn: parent
            text: root.count < 0 ? "" : root.count > 99 ? I18n.formatNumber(99) + "+" : I18n.formatNumber(root.count)
            color: "#261a0a"
            font.pixelSize: 10
            font.weight: Font.Bold
        }
    }

    App.PlainLabel {
        id: label
        anchors.left: badge.visible ? badge.right : symbol.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 17
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        text: root.incoming ? root.host.noticeLabel : root.host.t(root.muted ? "hud.notificationsMuted" : "hud.notificationsOn")
        elide: Text.ElideRight
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
