import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "ui" as UI

Item {
    id: root

    property var host: null
    property var model: null
    readonly property var sessions: model ? model.sessions : []

    function t(k) {
        return host ? host.t(k) : k;
    }

    function amount(v) {
        return v === null || v === undefined ? "—" : v >= 1e+06 ? (v / 1e+06).toFixed(1) + "M" : v >= 1000 ? (v / 1000).toFixed(1) + "k" : String(v);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 95
            radius: 12
            color: "#639d88"
            clip: true

            Canvas {
                anchors.fill: parent
                onPaint: {
                    var c = getContext("2d");
                    c.fillStyle = "#36d4efcf";
                    for (var x = 4; x < width; x += 17) for (var y = 7; y < height; y += 19) {
                        c.fillRect(x + (y % 3) * 2, y, 1, 3);
                        c.fillRect(x + 3, y + 2, 1, 2);
                    }
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 36

                Repeater {
                    model: root.sessions.slice(0, 5)

                    UI.AgentPet {
                        required property var modelData

                        provider: modelData.provider
                        activity: modelData.activity || "working"
                        motion: !!root.host && root.host.motion && root.host.opened
                    }

                }

            }

        }

        RowLayout {
            Layout.fillWidth: true

            PlainLabel {
                text: root.t("sessions")
                font.pixelSize: 13
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }

            PlainLabel {
                text: root.sessions.filter(function(s) {
                    return s.working;
                }).length + " " + root.t("working")
                font.pixelSize: 10
                color: "#a3c3b3"
            }

        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6
            clip: true
            model: root.sessions

            PlainLabel {
                anchors.centerIn: parent
                visible: list.count === 0
                text: root.t("noSessions")
                font.pixelSize: 12
                color: "#82828a"
            }

            ScrollBar.vertical: ScrollBar {
            }

            delegate: Surface {
                required property var modelData

                width: ListView.view.width
                height: 65
                radius: 10

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 10

                    UI.AgentPet {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        provider: modelData.provider
                        activity: modelData.activity || (modelData.working ? "working" : "idle")
                        motion: !!root.host && root.host.motion && root.host.opened
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true

                            PlainLabel {
                                text: modelData.project
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                            }

                            PlainLabel {
                                text: modelData.workspace !== null ? "WS " + modelData.workspace : root.t("workspaceUnknown")
                                font.pixelSize: 9
                                color: "#909097"
                            }

                        }

                        PlainLabel {
                            text: (modelData.provider === "claude" ? "Claude" : "Codex") + " · " + (modelData.model || "—") + " · " + root.t("activity." + (modelData.activity || "idle"))
                            font.pixelSize: 10
                            color: modelData.working ? "#90c9ac" : "#87878d"
                            Layout.fillWidth: true
                        }

                    }

                    Column {
                        spacing: 4

                        PlainLabel {
                            text: root.t("tokens") + " " + root.amount(modelData.tokens)
                            font.pixelSize: 10
                        }

                        PlainLabel {
                            text: root.t("context") + " " + root.amount(modelData.contextTokens) + (modelData.contextWindow ? " / " + root.amount(modelData.contextWindow) : "")
                            font.pixelSize: 10
                            color: "#a0a0a7"
                        }

                    }

                }

            }

        }

    }

}
