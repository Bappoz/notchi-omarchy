import QtQuick
import QtQuick.Layouts
import ".." as App

Item {
    id: root
    required property var host
    property string kind: host.displayedHud
    readonly property var notice: host.peekNotice
    readonly property var device: notice.device || null
    readonly property bool volume: kind === "volume"
    readonly property bool camera: kind === "camera"
    readonly property bool bluetooth: kind === "headphones" || kind === "bluetooth"
    readonly property var cells: device && bluetooth ? device.batteries : []
    readonly property bool muted: host.model ? host.model.volumeHudMuted : false
    readonly property int level: volume ? (host.model ? host.model.volumeHudLevel : 0) : notice.level || 0
    readonly property color tint: volume ? "#f1f3f9" : kind === "lowBattery" ? "#ff9c6f"
        : bluetooth ? "#97c3ff" : kind === "charging" ? "#9af0c3" : "#81eb9f"
    readonly property string glyph: volume ? (muted ? "speaker-muted" : level < 34 ? "volume-1" : "speaker-high")
        : camera ? "video" : kind === "headphones" ? (device && device.inEar ? "emblem-earbuds" : "emblem-headset")
        : kind === "bluetooth" ? "emblem-bluetooth"
        : kind === "lowBattery" ? "battery" : kind === "chargeFull" ? "circle-check" : "battery-charging"

    Accessible.role: Accessible.StaticText
    Accessible.name: volume ? host.t(muted ? "hud.muted" : "volume") + " " + level + "%"
        : camera ? host.t("hud.camera") : primary.text + " " + secondary.text

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.bluetooth ? 17 : 16
        anchors.rightMargin: 17
        spacing: root.bluetooth ? 12 : 10

        Icon {
            name: root.glyph
            color: root.bluetooth ? "white" : root.tint
            size: root.bluetooth ? 29 : 20
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            App.PlainLabel {
                id: primary
                Layout.fillWidth: true
                visible: !root.volume && !root.camera
                text: root.bluetooth ? (root.device && root.device.name ? root.device.name : host.t("island." + root.kind))
                    : root.kind ? host.t("hud." + root.kind) : ""
                color: "#f2f2f7"
                font.pixelSize: root.bluetooth ? 13 : 11
                font.weight: Font.DemiBold
            }

            App.PlainLabel {
                id: secondary
                visible: root.bluetooth && !!root.device && !!root.device.name
                text: host.t("hud.connected")
                color: "#aeb3bf"
                font.pixelSize: 10
            }
        }

        Rectangle {
            visible: root.volume
            Layout.preferredWidth: Math.min(100, root.width * .36)
            Layout.preferredHeight: 6
            radius: 3
            color: "#35363c"

            Rectangle {
                width: parent.width * (root.muted ? 0 : root.level / 100)
                height: parent.height
                radius: parent.radius
                color: root.tint
                Behavior on width { NumberAnimation { duration: host.motion ? 145 : 0; easing.type: Easing.OutCubic } }
            }
        }

        App.PlainLabel {
            visible: ["charging", "lowBattery", "chargeFull"].includes(root.kind)
            text: root.level + "%"
            color: root.tint
            font.pixelSize: 13
            font.weight: Font.Bold
        }

        CameraLight {
            visible: !!host.model && host.model.cameraInUse
            Layout.preferredWidth: 16
            Layout.preferredHeight: 18
        }

        Repeater {
            model: root.cells
            LevelRing {
                required property var modelData
                level: modelData.level
                caption: host.t("hud.battery." + modelData.label)
                showCaption: root.cells.length > 1
                motion: host.motion
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: implicitHeight
            }
        }
    }
}
