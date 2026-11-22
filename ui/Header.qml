import QtQuick
import QtQuick.Layouts
import ".." as App
import "Navigation.js" as Nav

Item {
    id: root

    required property var host
    property var model: null
    readonly property var section: Nav.page(host.currentTab)

    implicitHeight: 31

    RowLayout {
        anchors.fill: parent
        spacing: 8

        Icon {
            name: root.section.icon
            color: name.startsWith("emblem-") ? "white" : root.section.color
            size: 17
        }

        App.PlainLabel {
            Layout.fillWidth: true
            text: root.host.t(root.section.key)
            color: "#eef0f6"
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }


        App.PlainLabel {
            text: root.host.compactTime
            font.pixelSize: 11
            color: "#b4b8c6"
        }

        Battery {
            visible: !!root.model && !!root.model.systemBattery
            level: visible ? root.model.systemBattery.percent : 0
            charging: visible && root.model.systemBattery.charging
        }

        SettingsButton { host: root.host }
    }
}
