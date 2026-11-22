import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Commons as Commons

// Omarchy sends both native shortcut events and command-line OSDs here.
Item {
    id: root
    property var service: null
    property bool opened: false
    property string glyph: ""
    property string message: ""
    property real fraction: -1
    readonly property var targetScreen: Quickshell.screens.find(function(screen) {
        return Hyprland.focusedMonitor && screen.name === Hyprland.focusedMonitor.name
    }) || Quickshell.screens[0] || null
    readonly property var icons: ({
        brightness: "󰍹", display: "󰍹", keyboard: "󰌌", touchpad: "󰟸",
        touch: "󰝁", touchscreen: "󰝁", microphone: "󰍬", mic: "󰍬",
        "microphone-muted": "󰍭", "microphone-off": "󰍭", "mic-muted": "󰍭", "mic-off": "󰍭",
        reboot: "󰜉", restart: "󰜉", shutdown: "󰐥", power: "󰐥", poweroff: "󰐥",
        logout: "󰍃", "sign-out": "󰍃", leave: "󰍃",
        media: "󰝚", player: "󰝚", "media-source": "󰝚", "player-source": "󰝚",
        "media-play": "󰐊", "player-play": "󰐊", "media-pause": "󰏤", "player-pause": "󰏤",
        "media-next": "󰒭", "player-next": "󰒭", "media-previous": "󰒮", "player-previous": "󰒮"
    })

    function open(payload) {
        var data
        try { data = JSON.parse(payload || "{}") } catch (error) { return }
        if (!data || typeof data !== "object") return
        var icon = String(data.icon || "")
        var key = icon.toLowerCase()
        var muted = ["volume-muted", "volume-mute", "muted", "mute", "", "󰝟"].includes(key)
        var volume = muted || ["volume", "volume-low", "volume-medium", "volume-high",
                              "", "", "", "󰕿", "󰖀", "󰕾", "󰋋"].includes(key)
        var progress = data.value !== undefined && data.value !== null && data.value !== "" && Number.isFinite(Number(data.value))
        var maximum = Math.max(1, Number(data.max) || 100)
        var percent = progress ? Math.max(0, Math.min(100, Math.round(Number(data.value) * 100 / maximum))) : 0
        if (volume && progress && service) {
            service.lastOsdVolumeAt = Date.now()
            service.showVolume(percent, muted, true)
            return
        }
        fraction = progress && !data.message ? percent / 100 : -1
        glyph = Object.prototype.hasOwnProperty.call(icons, key) ? icons[key] : icon
        message = String(data.message || (fraction >= 0 ? data.progressText || I18n.formatNumber(percent) + "%" : ""))
        opened = true
        hideTimer.stop()
        hideTimer.interval = data.duration === "" || data.duration === undefined || !Number.isFinite(Number(data.duration))
            ? 1200 : Math.max(0, Math.min(2147483647, Number(data.duration)))
        if (hideTimer.interval > 0) hideTimer.start()
    }

    function close() {
        opened = false
        hideTimer.stop()
        if (service) service.volumeHudActive = false
    }

    ShellIpc {
        target: "osd"
        function show(payload: string): string { root.open(payload); return "ok" }
        function close(): string { root.close(); return "ok" }
        function state(): string { return root.opened || (root.service && root.service.volumeHudActive) ? "open" : "closed" }
        function ping(): string { return "ok" }
    }

    Timer { id: hideTimer; onTriggered: root.opened = false }

    PanelWindow {
        visible: root.opened && !!root.targetScreen
        screen: root.targetScreen
        anchors.bottom: true
        margins.bottom: 66
        implicitWidth: card.implicitWidth
        implicitHeight: card.implicitHeight
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "omarchy-osd"
        color: "transparent"
        mask: Region {}

        Rectangle {
            id: card
            anchors.fill: parent
            implicitWidth: row.implicitWidth + 32
            implicitHeight: row.implicitHeight + 24
            color: Commons.Color.background
            radius: Style.cornerRadius
            border.color: Qt.alpha(Commons.Color.popups.text, .22)

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 14

                Text {
                    visible: text.length > 0
                    text: root.glyph
                    textFormat: Text.PlainText
                    color: Commons.Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: 26
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    visible: root.fraction >= 0
                    width: 142
                    height: 5
                    radius: 3
                    color: Qt.alpha(Commons.Color.popups.text, .27)
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: parent.width * Math.max(0, root.fraction)
                        height: parent.height
                        radius: parent.radius
                        color: Commons.Color.accent
                        Behavior on width { NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic } }
                    }
                }

                Text {
                    visible: text.length > 0
                    text: root.message
                    textFormat: Text.PlainText
                    color: Commons.Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    width: Math.min(implicitWidth, 325)
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
