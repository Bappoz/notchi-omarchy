import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "ui" as UI

Item {
    id: root

    property var host: null
    property var model: null
    readonly property bool hasWeather: typeof info.temperature === "number" && isFinite(info.temperature)
    readonly property var info: model ? model.weather : ({
    })

    function t(k) {
        return host ? host.t(k) : k;
    }

    function val(v, unit) {
        return v === undefined || v === null ? "—" : Math.round(v) + unit;
    }

    Component.onCompleted: Qt.callLater(function() {
        if (root.model)
            root.model.refreshWeather(false);

    })
    onModelChanged: {
        if (model)
            model.refreshWeather(false);

    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true

            Column {
                spacing: 3

                PlainLabel {
                    text: root.t("weather")
                    font.pixelSize: 19
                    font.weight: Font.Bold
                }

                PlainLabel {
                    text: root.info.fetched ? new Date(root.info.fetched * 1000).toLocaleTimeString(Qt.locale(), "HH:mm") + " · Open-Meteo" : root.t("weatherNoLocation")
                    font.pixelSize: 10
                    color: "#929aa8"
                }

            }

            Item {
                Layout.fillWidth: true
            }

            UI.IconButton {
                iconName: "map-pin"
                hint: root.t("weatherLocation")
                onClicked: root.host.handoff("omarchy.weather")
            }

            UI.IconButton {
                iconName: "refresh-cw"
                hint: root.t("refresh")
                enabled: !!root.model && !root.model.weatherBusy
                onClicked: root.model.refreshWeather(true)
            }

        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 151
            radius: 18

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 15

                UI.WeatherScene {
                    visible: root.hasWeather
                    Layout.preferredWidth: 160
                    Layout.fillHeight: true
                    kind: root.info.kind || "clear"
                    night: root.info.isDay === false
                    motion: !!root.host && root.host.motion && root.host.opened
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    PlainLabel {
                        text: root.val(root.info.temperature, "°")
                        font.pixelSize: 45
                        font.weight: Font.Light
                    }

                    PlainLabel {
                        text: root.hasWeather ? root.t("weather." + (root.info.kind || "clear")) : root.t("weatherUnavailable")
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    PlainLabel {
                        text: root.t("feelsLike") + " " + root.val(root.info.feelsLike, "°")
                        font.pixelSize: 10
                        color: "#c1d2dc"
                    }

                }

                Column {
                    spacing: 14

                    PlainLabel {
                        text: root.t("humidity") + "  " + root.val(root.info.humidity, "%")
                        font.pixelSize: 11
                        color: "#d0dbe2"
                    }

                    PlainLabel {
                        text: root.t("wind") + "  " + root.val(root.info.wind, " km/h")
                        font.pixelSize: 11
                        color: "#d0dbe2"
                    }

                }

            }

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: root.info.isDay === false ? "#29324e" : "#304b60"
                }

                GradientStop {
                    position: 1
                    color: root.info.isDay === false ? "#1f293c" : "#5a7784"
                }

            }

        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.info.forecast || []

                ColumnLayout {
                    required property var modelData

                    Layout.fillWidth: true
                    spacing: 6

                    PlainLabel {
                        text: modelData.time
                        font.pixelSize: 9
                        color: "#8f98a6"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    UI.Icon {
                        name: modelData.rain > 30 ? "cloud-rain" : "sun"
                        size: 15
                        opacity: 0.75
                        Layout.alignment: Qt.AlignHCenter
                    }

                    PlainLabel {
                        text: root.val(modelData.temperature, "°")
                        font.pixelSize: 11
                        Layout.alignment: Qt.AlignHCenter
                    }

                    PlainLabel {
                        text: modelData.rain + "%"
                        font.pixelSize: 8
                        color: "#89afca"
                        Layout.alignment: Qt.AlignHCenter
                    }

                }

            }

        }

        Item {
            Layout.fillHeight: true
        }

        PlainLabel {
            visible: !!root.info.error || !!root.info.stale
            text: root.info.error || root.t("weatherStale")
            font.pixelSize: 10
            color: "#d0b58b"
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true

            UI.Icon {
                name: "bell"
                size: 12
                opacity: 0.5
            }

            PlainLabel {
                text: root.t("weatherNoticePolicy")
                font.pixelSize: 9
                color: "#92929b"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

        }

    }

}
