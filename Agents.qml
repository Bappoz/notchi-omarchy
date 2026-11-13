import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "ui" as UI

Item {
    id: root

    property var host: null
    property var model: null
    property string mode: "main"
    property string section: "quotas"
    property string provider: ""
    readonly property var agents: model ? model.agents : []

    function t(k) {
        return host ? host.t(k) : k;
    }

    function resetTime(value) {
        var d = new Date(value);
        return isNaN(d.getTime()) ? "—" : d.toLocaleString(Qt.locale(), "ddd HH:mm");
    }

    objectName: "agents-page"
    onModeChanged: {
        section = mode === "activity" ? "activity" : mode.indexOf("detail-") === 0 ? "detail" : "quotas";
        if (section === "detail" && model)
            model.loadAgentDetail(mode.slice(7));

    }
    onModelChanged: {
        if (model && mode.indexOf("detail-") === 0)
            model.loadAgentDetail(mode.slice(7));

    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            NotchButton {
                objectName: "quota-back"
                text: root.t("quotaAccounts")
                iconName: "chart-no-axes-combined"
                compact: true
                selected: root.section === "quotas"
                accent: "#505052"
                onClicked: root.host.openTab("agents")
            }

            NotchButton {
                text: root.t("sessions")
                iconName: "sparkles"
                compact: true
                selected: root.section === "activity"
                accent: "#505052"
                onClicked: root.host.openTab("agents/activity")
            }

            Item {
                Layout.fillWidth: true
            }

            UI.IconButton {
                iconName: "refresh-cw"
                hint: root.t("refresh")
                enabled: !!root.model && !root.model.quotaUpdating
                onClicked: root.model.refreshQuotas(true)
            }

            UI.IconButton {
                iconName: "maximize-2"
                hint: root.t("agentFull")
                onClicked: root.host.handoff("omarchy.agents")
            }

        }

        Loader {
            visible: root.section === "detail"
            active: visible
            Layout.fillWidth: true
            Layout.fillHeight: true
            source: "AgentDetail.qml"
            onLoaded: {
                item.host = root.host;
                item.model = root.model;
            }
        }

        Loader {
            visible: root.section === "activity"
            active: visible
            Layout.fillWidth: true
            Layout.fillHeight: true
            source: "Activity.qml"
            onLoaded: {
                item.host = root.host;
                item.model = root.model;
            }
        }

        ColumnLayout {
            visible: root.section === "quotas"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                NotchButton {
                    text: root.t("all")
                    compact: true
                    selected: root.provider === ""
                    accent: "#505052"
                    onClicked: root.provider = ""
                }

                Repeater {
                    model: root.agents

                    NotchButton {
                        required property var modelData

                        text: modelData.name
                        compact: true
                        selected: root.provider === modelData.id
                        accent: "#505052"
                        onClicked: root.provider = modelData.id
                    }

                }

                Item {
                    Layout.fillWidth: true
                }

            }

            ListView {
                id: list

                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8
                clip: true
                model: root.agents.filter(function(r) {
                    return root.provider === "" || root.provider === r.id;
                })

                ScrollBar.vertical: ScrollBar {
                }

                delegate: Surface {
                    id: card

                    required property var modelData

                    objectName: "provider-" + modelData.id
                    color: cardHover.hovered ? "#14ffffff" : "#0dffffff"
                    Accessible.role: Accessible.Button
                    Accessible.name: root.t("agentDetails") + " " + modelData.name
                    width: ListView.view.width
                    height: content.implicitHeight + 24
                    radius: 12

                    HoverHandler {
                        id: cardHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: root.host.openTab("agents/detail-" + card.modelData.id)
                    }

                    ColumnLayout {
                        id: content

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 9

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Image {
                                source: Qt.resolvedUrl(card.modelData.id === "agy" ? "assets/providers/antigravity.png" : "assets/providers/" + card.modelData.id + ".svg")
                                sourceSize: Qt.size(48, 48)
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                                fillMode: Image.PreserveAspectFit
                            }

                            PlainLabel {
                                text: card.modelData.name
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                            }

                            PlainLabel {
                                text: (card.modelData.stale ? root.t("stale") : root.t("updated")) + (card.modelData.fetchedAt ? " · " + new Date(card.modelData.fetchedAt).toLocaleTimeString(Qt.locale(), "HH:mm") : "")
                                font.pixelSize: 9
                                color: card.modelData.stale ? "#e6ad6c" : "#89bd9f"
                            }

                            UI.Icon {
                                name: "chevron-right"
                                size: 12
                                opacity: 0.5
                            }

                        }

                        Repeater {
                            model: card.modelData.limits

                            RowLayout {
                                required property var modelData

                                Layout.fillWidth: true
                                spacing: 10

                                PlainLabel {
                                    text: modelData.label
                                    font.pixelSize: 10
                                    color: "#adadb4"
                                    Layout.preferredWidth: 125
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 4
                                    radius: 2
                                    color: "#22ffffff"

                                    Rectangle {
                                        height: 4
                                        radius: 2
                                        width: parent.width * Math.max(0, modelData.percent) / 100
                                        color: card.modelData.stale ? "#898990" : modelData.percent > 90 ? "#ff9f0a" : "#86c89b"
                                    }

                                }

                                PlainLabel {
                                    text: modelData.percent.toFixed(1) + "% " + root.t("used")
                                    font.pixelSize: 10
                                    Layout.preferredWidth: 82
                                    horizontalAlignment: Text.AlignRight
                                }

                                PlainLabel {
                                    text: root.resetTime(modelData.resetsAt)
                                    font.pixelSize: 9
                                    color: "#84848d"
                                    Layout.preferredWidth: 80
                                    horizontalAlignment: Text.AlignRight
                                }

                            }

                        }

                        PlainLabel {
                            visible: card.modelData.note !== "" || card.modelData.limits.length === 0
                            text: card.modelData.note || root.t("quotaUnavailable")
                            font.pixelSize: 10
                            color: "#bca38b"
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }

                    }

                }

            }

            PlainLabel {
                text: root.model && root.model.quotaUpdating ? root.t("quotaRefreshing") : root.t("quotaSource")
                font.pixelSize: 9
                color: "#787880"
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }

        }

    }

}
