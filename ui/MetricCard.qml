import QtQuick
import QtQuick.Layouts
import qs.Commons
import ".." as App

App.Surface {
    id: root

    property string label: ""
    property string iconName: "cpu"
    property real value: 0
    property string detail: ""
    property color accent: "#93c7ae"
    property bool available: true

    radius: 13
    implicitHeight: 87

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 7

            Icon {
                name: root.iconName
                size: 14
                color: root.accent
            }

            App.PlainLabel {
                text: root.label
                font.pixelSize: 10
                color: "#a6a6b0"
                Layout.fillWidth: true
            }

            App.PlainLabel {
                text: root.available ? Math.round(root.value) + "%" : "—"
                font.pixelSize: 17
                font.weight: Font.Medium
                color: root.accent
            }

        }

        Rectangle {
            Layout.fillWidth: true
            height: 4
            radius: 2
            color: "#18ffffff"

            Rectangle {
                height: 4
                radius: 2
                width: parent.width * Math.max(0, Math.min(100, root.value)) / 100
                color: root.accent

                Behavior on width {
                    NumberAnimation {
                        duration: Style.duration(300)
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

        App.PlainLabel {
            text: root.detail
            font.pixelSize: 9
            color: "#85858f"
            Layout.fillWidth: true
        }

    }

}
