import QtQuick
import QtQuick.Layouts
import "ui" as UI

Item {
    id: root

    property var host: null
    property var model: null
    readonly property var stats: model ? model.telemetry : ({
    })
    readonly property var metrics: stats.metrics || ({
    })

    function t(k) {
        return host ? host.t(k) : k;
    }

    function gb(n) {
        return (Number(n || 0) / 1.07374e+09).toFixed(1) + " GiB";
    }

    function speed(n) {
        return n > 1.04858e+06 ? (n / 1.04858e+06).toFixed(1) + " MB/s" : Math.round((n || 0) / 1024) + " KB/s";
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 9

        RowLayout {
            Layout.fillWidth: true

            PlainLabel {
                text: root.t("system")
                font.pixelSize: 18
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }

            Rectangle {
                width: 5
                height: 5
                radius: 3
                color: root.stats.metrics ? "#99c9af" : "#777780"
            }

            PlainLabel {
                text: root.t("liveSystem")
                font.pixelSize: 9
                color: "#92929c"
            }

        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            UI.MetricCard {
                Layout.fillWidth: true
                label: "CPU"
                iconName: "cpu"
                available: !!root.stats.metrics
                value: root.metrics.cpu || 0
                detail: root.t("cpuDetail")
                accent: "#9acdb8"
            }

            UI.MetricCard {
                Layout.fillWidth: true
                label: root.t("memory")
                iconName: "memory-stick"
                available: !!root.stats.metrics
                value: root.metrics.memory || 0
                detail: (root.metrics.memoryGB || 0) + " / " + (root.metrics.totalGB || 0) + " GiB"
                accent: "#b7a8dd"
            }

        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            UI.MetricCard {
                Layout.fillWidth: true
                label: root.t("diskFree")
                iconName: "hard-drive"
                available: !!root.stats.disk && root.stats.disk.total > 0
                value: available ? 100 * root.stats.disk.free / root.stats.disk.total : 0
                detail: root.gb(root.stats.disk ? root.stats.disk.free : 0) + " " + root.t("free")
                accent: "#9abedc"
            }

            UI.MetricCard {
                Layout.fillWidth: true
                label: root.t("battery")
                iconName: "battery"
                available: !!root.stats.systemBattery
                value: available ? root.stats.systemBattery.percent : 0
                detail: available ? root.t(root.stats.systemBattery.charging ? "batteryCharging" : "batteryDischarging") : root.t("unavailable")
                accent: "#d2c08e"
            }

        }

        Surface {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 49
            radius: 13

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                UI.Icon {
                    name: "globe"
                    size: 15
                    color: "#9fb7c8"
                }

                Column {
                    spacing: 4

                    PlainLabel {
                        text: root.t("network")
                        font.pixelSize: 11
                    }

                    PlainLabel {
                        text: root.stats.network ? root.stats.network.interface : "—"
                        font.pixelSize: 9
                        color: "#85858f"
                    }

                }

                Canvas {
                    property var samples: root.stats.network ? root.stats.network.history : []

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    onSamplesChanged: requestPaint()
                    onPaint: {
                        var c = getContext("2d");
                        c.reset();
                        var max = 1;
                        for (var i = 0; i < samples.length; i++) max = Math.max(max, samples[i][0], samples[i][1])
                        for (var n = 0; n < 2; n++) {
                            c.beginPath();
                            c.strokeStyle = n === 0 ? "#9cc8ba" : "#9896b9";
                            c.lineWidth = 1.5;
                            for (var j = 0; j < samples.length; j++) {
                                var x = j * width / Math.max(1, samples.length - 1), y = height - 2 - samples[j][n] / max * (height - 4);
                                if (j)
                                    c.lineTo(x, y);
                                else
                                    c.moveTo(x, y);
                            }
                            c.stroke();
                        }
                    }
                }

                Column {
                    spacing: 5

                    PlainLabel {
                        text: "↓ " + root.speed(root.stats.network ? root.stats.network.download : 0)
                        font.pixelSize: 10
                        color: "#9cc8ba"
                    }

                    PlainLabel {
                        text: "↑ " + root.speed(root.stats.network ? root.stats.network.upload : 0)
                        font.pixelSize: 10
                        color: "#b0aacf"
                    }

                }

            }

        }

    }

}
