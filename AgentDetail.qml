import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "ui" as UI

Item {
    id: root

    property var host: null
    property var model: null
    property int range: 7
    readonly property var detail: model ? model.agentDetail : ({
    })
    readonly property var days: (detail.days || []).slice(-range)
    readonly property real maximum: days.reduce(function(m, d) {
        return Math.max(m, d.tokens || 0);
    }, 1)
    readonly property real modelMaximum: (detail.models || []).reduce(function(m, d) {
        return Math.max(m, d.total || 0);
    }, 1)

    function t(k) {
        return host ? host.t(k) : k;
    }

    function number(n) {
        return n === undefined || n === null ? "—" : Number(n).toLocaleString(Qt.locale(), 'f', 0);
    }

    function compactCount(n) {
        return n > 1e+06 ? (n / 1e+06).toFixed(1) + "M" : n > 1000 ? (n / 1000).toFixed(1) + "k" : number(n);
    }

    Flickable {
        anchors.fill: parent
        contentHeight: content.implicitHeight
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: content

            width: parent.width
            spacing: 12

            RowLayout {
                Layout.fillWidth: true

                Image {
                    source: root.detail.id ? Qt.resolvedUrl("assets/providers/" + (root.detail.id === "agy" ? "antigravity.png" : root.detail.id + ".svg")) : ""
                    sourceSize: Qt.size(64, 64)
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    fillMode: Image.PreserveAspectFit
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    PlainLabel {
                        text: root.detail.name || root.detail.id || ""
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }

                    PlainLabel {
                        text: root.detail.tier || root.t("localUsage")
                        font.pixelSize: 10
                        color: "#9999a2"
                    }

                }

                UI.IconButton {
                    iconName: "refresh-cw"
                    hint: root.t("refresh")
                    enabled: !!root.model && !root.model.detailBusy && !root.model.quotaUpdating
                    onClicked: root.model.refreshQuotas(true)
                }

            }

            PlainLabel {
                visible: !!root.model && (root.model.detailBusy || root.model.quotaUpdating || !!root.model.detailError)
                text: root.model && (root.model.detailBusy || root.model.quotaUpdating) ? root.t("loading") : root.model ? root.model.detailError : ""
                color: "#d3b694"
                font.pixelSize: 11
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [{
                        "label": root.t("tokensToday"),
                        "value": root.detail.todayTokens,
                        "color": "#92cbb5"
                    }, {
                        "label": root.t("promptsToday"),
                        "value": root.detail.todayPrompts,
                        "color": "#ada3dc"
                    }, {
                        "label": root.t("sessionsToday"),
                        "value": root.detail.todaySessions,
                        "color": "#a3bfdc"
                    }]

                    Surface {
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 70
                        radius: 12

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6

                            PlainLabel {
                                text: modelData.label
                                font.pixelSize: 9
                                color: "#9c9ca6"
                            }

                            PlainLabel {
                                text: root.number(modelData.value)
                                font.pixelSize: 20
                                font.weight: Font.Medium
                                color: modelData.color
                            }

                        }

                    }

                }

            }

            Surface {
                Layout.fillWidth: true
                implicitHeight: 168
                radius: 14

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true

                        PlainLabel {
                            text: root.t("dailyTokens")
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }

                        NotchButton {
                            text: "7 " + root.t("days")
                            compact: true
                            selected: root.range === 7
                            accent: "#465f54"
                            onClicked: root.range = 7
                        }

                        NotchButton {
                            visible: (root.detail.days || []).length > 7
                            text: "30 " + root.t("days")
                            compact: true
                            selected: root.range === 30
                            accent: "#465f54"
                            onClicked: root.range = 30
                        }

                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        PlainLabel {
                            visible: root.days.length === 0
                            anchors.centerIn: parent
                            text: root.t("historyUnavailable")
                            font.pixelSize: 10
                            color: "#888891"
                        }

                        Row {
                            anchors.fill: parent
                            spacing: 4

                            Repeater {
                                model: root.days

                                Item {
                                    required property var modelData

                                    width: (parent.width - Math.max(0, root.days.length - 1) * 4) / Math.max(1, root.days.length)
                                    height: parent.height
                                    ToolTip.visible: hover.hovered
                                    ToolTip.text: modelData.date + " · " + root.number(modelData.tokens) + " tokens"

                                    Rectangle {
                                        anchors.bottom: day.top
                                        anchors.bottomMargin: 6
                                        width: Math.min(28, parent.width)
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        height: Math.max(2, (parent.height - 25) * (modelData.tokens || 0) / root.maximum)
                                        radius: Math.min(4, width / 2)
                                        color: modelData.tokens === null ? "#30404044" : "#86bca5"
                                    }

                                    PlainLabel {
                                        id: day

                                        anchors.bottom: parent.bottom
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.date.slice(8)
                                        font.pixelSize: 8
                                        color: "#85858f"
                                    }

                                    HoverHandler {
                                        id: hover
                                    }

                                }

                            }

                        }

                    }

                }

            }

            PlainLabel {
                text: root.t("modelBreakdown")
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            PlainLabel {
                visible: !(root.detail.models || []).length
                text: root.t("modelsUnavailable")
                font.pixelSize: 10
                color: "#9696a0"
            }

            Repeater {
                model: root.detail.models || []

                Surface {
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 78
                    radius: 12

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 7

                        RowLayout {
                            Layout.fillWidth: true

                            PlainLabel {
                                text: modelData.name
                                font.pixelSize: 11
                                Layout.fillWidth: true
                            }

                            PlainLabel {
                                text: (modelData.partial && modelData.total !== null ? "≥ " : "") + root.compactCount(modelData.total) + " tokens"
                                font.pixelSize: 10
                                color: "#a5bfae"
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
                                width: parent.width * modelData.total / root.modelMaximum
                                color: "#90bba5"
                            }

                        }

                        PlainLabel {
                            text: root.t("inputTokens") + " " + root.compactCount(modelData.inputTokens) + "  ·  " + root.t("outputTokens") + " " + root.compactCount(modelData.outputTokens) + "  ·  " + root.t("cacheRead") + " " + root.compactCount(modelData.cacheReadInputTokens) + "  ·  " + root.t("cacheWrite") + " " + root.compactCount(modelData.cacheCreationInputTokens)
                            font.pixelSize: 9
                            color: "#92929e"
                            Layout.fillWidth: true
                        }

                    }

                }

            }

            PlainLabel {
                text: root.t("usageDetailSource")
                font.pixelSize: 9
                color: "#82828c"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

        }

        ScrollBar.vertical: ScrollBar {
        }

    }

}
