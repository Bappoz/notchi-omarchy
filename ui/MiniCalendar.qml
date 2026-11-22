import QtQuick
import QtQuick.Layouts
import ".." as App
import "Month.js" as Month
import qs.Commons

ColumnLayout {
    id: root
    required property date today
    readonly property var locale: Qt.locale(I18n.formatLocale)
    readonly property var days: Month.days(today)
    spacing: 7

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: "#20ffffff"
    }

    App.PlainLabel {
        Layout.alignment: Qt.AlignHCenter
        text: root.today.toLocaleDateString(root.locale, "MMMM yyyy")
        color: "#edf0f7"
        font.pixelSize: 12
        font.weight: Font.DemiBold
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 7
        rowSpacing: 2
        columnSpacing: 2

        Repeater {
            model: 7

            App.PlainLabel {
                required property int index
                Layout.fillWidth: true
                Layout.preferredWidth: 24
                horizontalAlignment: Text.AlignHCenter
                text: root.locale.standaloneDayName(index + 1, Locale.NarrowFormat)
                color: "#a4a8b5"
                font.pixelSize: 9
            }
        }

        Repeater {
            model: root.days

            Item {
                required property date modelData
                readonly property bool current: modelData.toDateString() === root.today.toDateString()
                Layout.fillWidth: true
                Layout.preferredWidth: 24
                Layout.preferredHeight: 21

                App.PlainLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 1
                    text: parent.modelData.getDate()
                    color: parent.current ? "#ffc1b8"
                        : parent.modelData.getMonth() === root.today.getMonth() ? "#e1e3ee" : "#838694"
                    font.pixelSize: 10
                    font.weight: parent.current ? Font.Bold : Font.Normal
                }

                Rectangle {
                    objectName: parent.current ? "mini-calendar-today" : ""
                    visible: parent.current
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    width: 4
                    height: width
                    radius: width / 2
                    color: "#ff9b94"
                }
            }
        }
    }
}
