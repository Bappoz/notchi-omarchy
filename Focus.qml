import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "ui" as UI

Item {
    id: root

    property var host: null
    property var model: null
    readonly property color tint: "#ffc17c"
    property int minutes: 25
    readonly property bool active: !!model && model.remaining > 0
    readonly property real fraction: active ? Math.max(0, Math.min(1, model.remaining / (model.timer.duration || 1))) : 1

    function t(key) {
        return host ? host.t(key) : key;
    }

    onFractionChanged: ring.requestPaint()
    onActiveChanged: ring.requestPaint()

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
            Layout.preferredWidth: 124
            Layout.maximumWidth: 160
            Layout.fillWidth: false
            spacing: 7

            PlainLabel {
                text: root.t("focus")
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: root.tint
                Layout.alignment: Qt.AlignHCenter
            }

            GridLayout {
                columns: 2
                rowSpacing: 7
                columnSpacing: 7
                Layout.fillWidth: true

                Repeater {
                    model: [1, 5, 10, 15, 25, 50]

                    NotchButton {
                        required property int modelData

                        text: modelData + " min"
                        compact: true
                        Layout.fillWidth: true
                        selected: root.minutes === modelData
                        accent: "#42434b"
                        onClicked: root.minutes = modelData
                    }

                }

            }

            Field {
                id: custom

                Layout.fillWidth: true
                implicitHeight: 23
                padding: 4
                text: String(root.minutes)
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
                inputMethodHints: Qt.ImhDigitsOnly
                onEditingFinished: {
                    if (acceptableInput) {
                        root.minutes = Number(text);
                    }
                }
                Accessible.name: root.t("minutes")

                validator: IntValidator {
                    bottom: 1
                    top: 240
                }

            }

        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Canvas {
                id: ring

                width: 124
                height: 124
                anchors.centerIn: parent
                onPaint: {
                    var c = getContext("2d"), center = width / 2, r = 55;
                    c.reset();
                    c.lineWidth = 7;
                    c.lineCap = "round";
                    c.beginPath();
                    c.arc(center, center, r, 0, Math.PI * 2);
                    c.strokeStyle = "rgba(255,255,255,.10)";
                    c.stroke();
                    c.beginPath();
                    c.arc(center, center, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * root.fraction);
                    c.strokeStyle = root.active ? root.tint : "rgba(255,193,124,.35)";
                    c.stroke();
                }
            }

            PlainLabel {
                anchors.centerIn: parent
                text: root.active ? root.model.countdown : root.minutes + ":00"
                font.pixelSize: 32
                font.weight: Font.DemiBold
                font.letterSpacing: -1
            }

        }

        ColumnLayout {
            Layout.preferredWidth: 124
            Layout.maximumWidth: 160
            Layout.fillWidth: false
            spacing: 7

            Field {
                id: message

                Layout.fillWidth: true
                implicitHeight: 26
                padding: 6
                placeholderText: root.t("timerLabel")
                font.pixelSize: 9
                maximumLength: 180
            }

            NotchButton {
                text: root.t("start")
                iconName: "play-fill"
                iconTint: root.tint
                selected: true
                enabled: !!root.model
                accent: "#42434b"
                Layout.fillWidth: true
                onClicked: root.model.action("timer-start", [], null, JSON.stringify({minutes:root.minutes,label:message.text || root.t("pauseLabel")}))
            }

            NotchButton {
                text: root.t("reset")
                iconName: "refresh-cw"
                iconTint: root.tint
                Layout.fillWidth: true
                enabled: root.active
                onClicked: root.model.action("timer-cancel", [])
            }

            NotchButton {
                text: root.t("reminder")
                iconName: "timer"
                compact: true
                plain: true
                Layout.fillWidth: true
                onClicked: root.host.runAction(["omarchy-reminder", "-i"])
            }

        }

    }

}
