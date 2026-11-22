import QtQuick
import QtQuick.Layouts
import "Navigation.js" as Nav
import qs.Commons

Rectangle {
    id: root
    required property var host
    readonly property real slotWidth: Math.max(21, Math.min(33, (parent.width - 12) / Nav.dock.length))
    implicitWidth: dock.implicitWidth + 12
    implicitHeight: 36
    radius: height / 2
    color: "#16171c"
    border.color: "#23ffffff"

    Rectangle {
        property int index: Nav.dock.findIndex(function(item) { return item.id === root.host.currentTab; })
        x: 6 + index * root.slotWidth + 2
        anchors.verticalCenter: parent.verticalCenter
        width: root.slotWidth - 4
        height: 27
        radius: 9
        visible: index >= 0
        color: "#3b3c42"
        Behavior on x { NumberAnimation { duration: root.host.motion ? Style.duration(235) : 0; easing.type: Easing.OutCubic } }
    }

    RowLayout {
        id: dock
        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: Nav.dock
            IconButton {
                required property var modelData
                objectName: "tab-" + modelData.id
                Layout.preferredWidth: root.slotWidth
                Layout.preferredHeight: 29
                iconName: modelData.icon
                iconSize: root.slotWidth < 27 ? 15 : 18
                hint: root.host.t(modelData.key)
                selected: root.host.currentTab === modelData.id
                idleOpacity: .83
                flatSelection: true
                glyphMotion: root.host.motion
                enabled: !modelData.action || !!root.host.model
                onClicked: {
                    if (modelData.action === "voice") {
                        root.host.held = true
                        root.host.model.voice.toggle()
                    } else {
                        root.host.openTab(modelData.id === "agents" ? "agents/activity" : modelData.id)
                    }
                }
            }
        }
    }
}
