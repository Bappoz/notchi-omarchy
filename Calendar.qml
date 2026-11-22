import QtQuick
import QtQuick.Layouts
import qs.Commons
import "ui" as UI
import "ui/Month.js" as Month

Item {
    id: root

    property var host: null
    property var model: null
    property date shown: new Date()
    property date today: new Date()
    readonly property color tint: "#ff9b94"
    readonly property var locale: Qt.locale(I18n.formatLocale)
    readonly property var days: Month.days(shown)

    function t(key) {
        return host ? host.t(key) : key;
    }

    function step(delta) {
        shown = new Date(shown.getFullYear(), shown.getMonth() + delta, 1, 12);
    }

    Rectangle {
        anchors.fill: parent
        radius: 16
        border.color: "#20ffffff"
        gradient: Gradient {
            GradientStop { position: 0; color: "#23242b" }
            GradientStop { position: 1; color: "#1a1b20" }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 16

        ColumnLayout {
            Layout.preferredWidth: 360
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true

                PlainLabel {
                    text: root.shown.toLocaleDateString(root.locale, "MMMM yyyy")
                    font.pixelSize: 14
                    color: root.tint
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                UI.IconButton {
                    iconName: "chevron-left"
                    iconSize: 12
                    onClicked: root.step(-1)
                }

                UI.IconButton {
                    iconName: "chevron-right"
                    iconSize: 12
                    onClicked: root.step(1)
                }

            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 7
                columnSpacing: 3
                rowSpacing: 2

                Repeater {
                    model: 7

                    PlainLabel {
                        required property int index

                        text: root.locale.standaloneDayName(index + 1, Locale.NarrowFormat)
                        font.pixelSize: 9
                        color: "#74747c"
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }

                }

                Repeater {
                    model: root.days

                    Rectangle {
                        required property date modelData
                        readonly property bool isToday: modelData.toDateString() === root.today.toDateString()

                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        radius: 11
                        color: isToday ? root.tint : "transparent"

                        PlainLabel {
                            anchors.centerIn: parent
                            text: modelData.getDate()
                            font.pixelSize: 10
                            font.weight: parent.isToday ? Font.Bold : Font.Normal
                            color: parent.isToday ? "#000000" : modelData.getMonth() === root.shown.getMonth() ? "#d7d7dc" : "#4a4a50"
                        }

                    }

                }

            }

            NotchButton {
                text: root.t("calendarFull")
                iconName: "calendar"
                compact: true
                plain: true
                Layout.fillWidth: true
                onClicked: root.host.handoff("omarchy.clock")
            }

        }

        Rectangle {
            width: 1
            Layout.fillHeight: true
            color: "#14ffffff"
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 9

            RowLayout {
                UI.Icon {
                    name: "globe"
                    size: 13
                    color: root.tint
                }

                PlainLabel {
                    text: root.t("world")
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

            }

            Repeater {
                model: root.model ? root.model.clocks : []

                RowLayout {
                    required property var modelData

                    Layout.fillWidth: true

                    PlainLabel {
                        text: modelData.name
                        font.pixelSize: 10
                        color: "#8e8e93"
                        Layout.fillWidth: true
                    }

                    PlainLabel {
                        text: modelData.time
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }

                }

            }

            Item {
                Layout.fillHeight: true
            }

            NotchButton {
                text: root.t("world")
                iconName: "globe"
                compact: true
                Layout.fillWidth: true
                onClicked: root.host.handoff("omarchy.elsewhen")
            }

            RowLayout {
                Layout.fillWidth: true

                NotchButton {
                    text: root.t("reminder")
                    compact: true
                    Layout.fillWidth: true
                    onClicked: root.host.runAction(["omarchy-reminder", "-i"])
                }

                UI.IconButton {
                    iconName: "sun"
                    hint: root.t("weather")
                    onClicked: root.host.handoff("omarchy.weather")
                }

            }

            NotchButton {
                text: "Google Calendar"
                iconName: "calendar"
                compact: true
                plain: true
                Layout.fillWidth: true
                onClicked: root.host.handoff("tobiasz-p.next-event")
            }

        }

    }

}
