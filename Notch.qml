import "." as Local
import "ui" as UI
import "ui/Motion.js" as Motion
import "ui/CardTransform.js" as CardTransform
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
    id: root

    readonly property var model: Local.Runtime.model
    readonly property var player: model ? model.player : null
    property bool opened: false
    readonly property var peekNotice: model ? model.currentNotice : ({})
    readonly property bool activityPeek: !opened && focusedScreen && !!peekNotice.kind
    readonly property var recentNotice: model ? model.recentNotice : ({})
    readonly property string signalKind: activityPeek ? peekNotice.kind
        : player && player.isPlaying ? "media"
        : model && model.activeAgent ? "working"
        : recentNotice.kind || (model && model.islandClock ? "timer" : "")
    readonly property string signalIcon: {
        var icons = {
            "done": "circle-check",
            "attention": "bell", "weather": "cloud-sun", "timer": "timer",
            "call": "headphones", "transfer": "arrow-down-to-line",
            "chat": "bell", "report": "file-text", "notification": "bell",
            "wifi": "wifi", "headphones": "headphones"
        };
        return icons[signalKind] || "";
    }
    readonly property color signalTint: {
        var source = activityPeek ? peekNotice.source : (recentNotice.kind === signalKind ? recentNotice.source : "");
        if (signalKind === "media" || source === "WhatsApp") return "#50df9b";
        if (signalKind === "wifi") return "#78bbff";
        if (signalKind === "headphones") return "#7ce9b9";
        if (source === "Discord") return "#9c9dff";
        if (signalKind === "working" || signalKind === "agent")
            return (activityPeek ? peekNotice.provider === "claude" : model && model.activeProviders.includes("claude"))
                ? "#ef9d77" : "#84edbd";
        if (["media", "call", "done", "transfer"].includes(signalKind)) return "#a2e9cc";
        if (["attention", "timer"].includes(signalKind)) return "#ffc17c";
        return "#c5c8d8";
    }
    readonly property string noticeLabel: {
        var notice = peekNotice.kind ? peekNotice : recentNotice;
        if (!notice.kind) return "";
        if (notice.kind === "weather")
            return t("weatherAlert." + notice.event.kind);
        if (notice.provider)
            return (notice.provider === "claude" ? "Claude" : "Codex") + " · " + t("island." + notice.kind);
        return (notice.source ? notice.source + " · " : "") + t("island." + notice.kind);
    }
    readonly property string islandState: opened ? "expanded" : activityPeek ? "alert"
        : signalKind || (model && model.islandClock) ? "compact" : "idle"
    property real alertProgress: activityPeek ? 1 : 0
    Behavior on alertProgress {
        NumberAnimation { duration: root.motion ? Style.duration(300) : 0; easing.type: Easing.OutCubic }
    }
    property bool held: false
    property bool replayPinned: false
    property bool grabReady: false
    property bool focusPrimed: false
    property string currentTab: "quick"
    property string subtab: ""
    property int direction: 1
    readonly property var tabs: ["home", "files", "clipboard", "focus", "camera", "agents", "calendar", "tools", "system", "daily", "weather", "quick"]
    readonly property bool motion: setting("animations", true) && (!model || model.preferences.animations !== "false") && Style.duration(100)>0
    readonly property string theme: model && model.preferences.theme ? model.preferences.theme : setting("theme", "glass")
    readonly property string animationStyle: model && model.preferences.animationStyle ? model.preferences.animationStyle : setting("animationStyle", "fluid")
    readonly property var animationProfile: Motion.profile(animationStyle)
    readonly property bool spatial: motion && animationStyle.indexOf("3D") >= 0
    readonly property bool spatialTransition: spatial && progress > .001 && progress < .999
    readonly property bool hoverEnabled: !model || model.preferences.hover !== "false"
    readonly property var islandScreen: root.QsWindow.window ? root.QsWindow.window.screen : null
    readonly property string screenName: islandScreen ? islandScreen.name : ""
    property int fullscreenRevision: 0
    readonly property bool fullscreen: {
        var revision = fullscreenRevision;
        var monitor = islandScreen ? Hyprland.monitorFor(islandScreen) : null;
        var workspace = monitor ? monitor.activeWorkspace : null;
        if (!workspace) return false;
        var windows = Hyprland.toplevels.values;
        for (var i = 0; i < windows.length; i++) {
            var window = windows[i];
            if (window.workspace && window.workspace.id === workspace.id
                    && window.lastIpcObject && (Number(window.lastIpcObject.fullscreen) & 2))
                return true;
        }
        return false;
    }
    onFullscreenChanged: if (fullscreen) close()
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event && ["fullscreen", "openwindow", "closewindow", "movewindowv2",
                          "workspacev2", "focusedmonv2"].includes(String(event.name)))
                fullscreenRefresh.restart();
        }
    }
    Timer {
        id: fullscreenRefresh
        interval: 80
        onTriggered: { Hyprland.refreshToplevels(); fullscreenSettle.restart(); }
    }
    Timer { id: fullscreenSettle; interval: 250; onTriggered: root.fullscreenRevision++ }
    readonly property bool focusedScreen: !Hyprland.focusedMonitor || Hyprland.focusedMonitor.name === screenName
    readonly property string compactTime: clock.date.toLocaleTimeString(Qt.locale(I18n.formatLocale), "HH:mm")
    readonly property string compactDate: clock.date.toLocaleDateString(Qt.locale(I18n.formatLocale), "ddd d")
    readonly property int topInset: 8
    readonly property bool topBar: bar && bar.position === "top"
    readonly property bool connectionAlert: activityPeek && ["wifi", "headphones"].includes(peekNotice.kind)
    readonly property int expandedWidth: currentTab === "quick" ? 376 : currentTab === "agents" ? 748 : 708
    readonly property int expandedHeight: Math.max(42, Math.min(
        currentTab === "quick" ? (player ? 190 : 150) : Motion.height(currentTab, subtab),
        window.height - topInset - 50))
    property real pillWidth: {
        var agents = model ? model.activeProviders.length : 0;
        var statusWidth = model && model.islandClock ? 44 : 0;
        if (signalIcon) statusWidth += 26;
        return Math.max(166, 104 + 2 * Math.max(agents * 23, statusWidth));
    }
    Behavior on pillWidth {
        NumberAnimation { duration: root.motion ? Style.duration(220) : 0; easing.type: Easing.OutCubic }
    }
    readonly property bool pageReady: page.status === Loader.Ready
    readonly property bool pageError: page.status === Loader.Error
    property real reveal: opened ? 1 : 0
    readonly property real progress: Math.max(0, Math.min(1, reveal))

    function t(key) {
        return strings.t(key);
    }

    function openOnFocusedScreen() {
        if (!focusedScreen) return;
        held = true;
        if (!opened) openTab("quick");
    }

    function toggleOnFocusedScreen() {
        if (focusedScreen)
            toggle();

    }

    function showRequestedTab() {
        if (focusedScreen) {
            held = true;
            openTab(model ? model.requestedTab : "quick");
        }

    }

    function open() {
        if (opened || fullscreen)
            return ;

        if (bar && bar.requestPopout)
            bar.requestPopout(root);

        opened = true;
        if (model)
            model.expanded(true);

    }

    function close() {
        if (!opened)
            return ;

        moreMenu.close();
        opened = false;
        held = false;
        if (model)
            model.expanded(false);

        if (bar && bar.releasePopout)
            bar.releasePopout(root);

    }

    function toggle() {
        if (opened) {
            close();
        } else {
            held = true;
            openTab("quick");
        }
    }

    function showMenu() { moreMenu.open(); }

    function activateIsland() {
        if (activityPeek && model) {
            var tab = peekNotice.tab || "quick";
            model.dismissNotice();
            held = true;
            openTab(tab);
        } else {
            toggle();
        }
    }

    function openTab(tab) {
        var parts = String(tab).split("/");
        if (parts[0] === "tools" && parts[1] === "camera")
            parts = ["camera"];

        var next = tabs.indexOf(parts[0]) >= 0 || parts[0] === "settings" ? parts[0] : "home";
        direction = tabs.indexOf(next) >= tabs.indexOf(currentTab) ? 1 : -1;
        subtab = parts[1] || "";
        currentTab = next;
        // Navigation preserves whether the panel was opened by hover or pinned.
        moreMenu.close();
        open();
        Qt.callLater(page.inject);
        if (!held) leaveTimer.restart();
    }

    function replay() {
        replayPinned = held;
        close();
        replayTimer.restart();
    }

    function handoff(id) {
        close();
        if (model)
            model.panel(id);

    }

    function runAction(args) {
        close();
        if (model)
            model.exec(args);

    }

    moduleName: "bappoz.notch"
    implicitWidth: topBar ? pillWidth : vertical ? barSize : 24
    implicitHeight: barSize
    onOpenedChanged: {
        if (opened) hoverTimer.stop();
        grabReady = false;
        focusPrimed = false;
        if (opened)
            primeTimer.restart();
        else
            leaveTimer.stop();
    }
    onHeldChanged: {
        if (held && opened) {
            primeTimer.restart();
        } else if (opened) {
            leaveTimer.restart();
        }
    }
    Component.onDestruction: {
        if (opened && model) {
            model.expanded(false);
        }
    }

    ShellIpc {
        target: "bappoz.notch"

        function open(): void { root.broadcast("openOnFocusedScreen"); }
        function close(): void { root.broadcast("close"); }
        function toggle(): void { root.broadcast("toggleOnFocusedScreen"); }
        function tab(name: string): void {
            if (root.model) root.model.requestedTab = name;
            root.broadcast("showRequestedTab");
        }
        function status(): string {
            var widgets = root.bar && root.bar.moduleWidgets
                ? root.bar.moduleWidgets(root.moduleName) : [root];
            return JSON.stringify({
                opened: root.opened, tab: root.currentTab, screen: root.screenName,
                state: root.islandState, fullscreen: root.fullscreen, activityPeek: root.activityPeek, service: !!root.model, pageReady: root.pageReady, pageError: root.pageError,
                pageMode: page.item && "mode" in page.item ? page.item.mode : "",
                pageHasModel: !!page.item && !!page.item.model,
                animation: root.animationStyle, y: card.y, width: card.width, height: card.height,
                instances: widgets.map(function(widget) {
                    return {screen: widget.screenName, opened: widget.opened,
                        tab: widget.currentTab, pageReady: widget.pageReady,
                        pageError: widget.pageError};
                })
            });
        }
    }

    UI.IconButton {
        anchors.centerIn: parent
        visible: !root.topBar
        implicitWidth: 24
        implicitHeight: 24
        iconName: "circle-dot"
        hint: root.t("island.open")
        onClicked: root.toggle()
    }

    Translations {
        id: strings

        directory: Qt.resolvedUrl("i18n")
    }

    QtObject {
        id: clock

        property date date: new Date()
    }

    Timer {
        interval: Math.max(50, 60000 - Date.now() % 60000)
        running: true
        repeat: false
        onTriggered: {
            clock.date = new Date();
            interval = Math.max(50, 60000 - Date.now() % 60000);
            restart();
        }
    }

    Timer {
        id: replayTimer

        interval: 350
        onTriggered: {
            root.held = root.replayPinned;
            root.open();
            if (!root.held) leaveTimer.restart();
        }
    }

    Timer {
        id: primeTimer

        interval: 100
        onTriggered: {
            root.focusPrimed = true;
            root.grabReady = true;
            card.forceActiveFocus();
        }
    }

    Timer {
        id: hoverTimer

        interval: Math.max(100, Math.min(1000, Number(root.setting("hoverDelay", 220))))
        onTriggered: {
            if (root.hoverEnabled && !root.opened && !root.activityPeek && pillInput.containsMouse)
                root.openTab("quick");
        }
    }

    Timer {
        id: leaveTimer

        interval: 330
        onTriggered: {
            if (root.opened && !root.held && !surfaceHover.hovered && !moreMenu.visible) {
                root.close();
            }
        }
    }

    PanelWindow {
        id: window

        screen: root.islandScreen
        visible: !!root.islandScreen && !root.fullscreen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "bappoz-notch"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.opened ? (root.held && !root.focusPrimed ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand) : WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        HyprlandFocusGrab {
            windows: root.QsWindow.window ? [window, root.QsWindow.window] : [window]
            active: root.opened && root.held && root.grabReady
            onCleared: root.close()
        }

        Item {
            id: card

            anchors.horizontalCenter: parent.horizontalCenter
            y: root.topInset - 3 * root.progress
            readonly property real compactWidth: root.pillWidth + (282 - root.pillWidth) * root.alertProgress
            readonly property real compactHeight: 38 + 8 * root.alertProgress
            readonly property real targetWidth: Math.max(0, Math.min(root.expandedWidth, window.width - 24))
            property real expandedTargetWidth: targetWidth
            property real expandedTargetHeight: root.expandedHeight
            Behavior on expandedTargetWidth {
                enabled: root.opened
                NumberAnimation { duration: root.motion ? Style.duration(240) : 0; easing.type: Easing.OutCubic }
            }
            Behavior on expandedTargetHeight {
                enabled: root.opened
                NumberAnimation { duration: root.motion ? Style.duration(240) : 0; easing.type: Easing.OutCubic }
            }
            width: Math.max(0, Math.min(window.width - 16, compactWidth + (expandedTargetWidth - compactWidth) * Math.max(0, root.reveal)))
            height: Math.max(0, Math.min(window.height - y, compactHeight + (expandedTargetHeight - compactHeight) * Math.max(0, root.reveal)))
            clip: true
            focus: root.opened
            Keys.onEscapePressed: root.close()
            Keys.onPressed: function(event) {
                if ((event.modifiers & Qt.ControlModifier) && event.key >= Qt.Key_1 && event.key <= Qt.Key_8) {
                    root.openTab(root.tabs[event.key - Qt.Key_1]);
                    event.accepted = true;
                }
            }

            // Keep the live controls and input region in an untransformed plane.
            // Only their visual snapshot rotates; perspective never affects hit testing.
            Item {
                id: liveSurface
                objectName: "notch-live-surface"
                anchors.fill: parent
            Rectangle {
                anchors.fill: parent
                radius: (19 + 4 * root.alertProgress) + 9 * root.progress
                color: root.theme === "midnight" ? "#09090c" : root.theme === "frosted" ? "#f52a2a32" : "#f518181f"
                border.width: 1
                border.color: Qt.tint("#34343f", Qt.alpha(root.signalTint, .28 * root.alertProgress))
            }

            UI.IslandOrbit {
                objectName: "notch-orbit"
                anchors.fill: parent
                radius: 19 + 4 * root.alertProgress + 9 * root.progress
                tint: root.signalTint
                opacity: 1 - root.progress
                running: root.progress < .99 && ["media", "working"].includes(root.signalKind)
                alertAt: root.activityPeek ? root.peekNotice.queuedAt : 0
                motion: root.motion
            }

            UI.IslandCompact {
                id: pill
                objectName: "notch-pill"
                width: card.compactWidth
                height: card.compactHeight
                anchors.horizontalCenter: parent.horizontalCenter
                host: root
                opacity: Math.max(0, 1 - root.progress * 3.5)
                visible: opacity > 0

                MouseArea {
                    id: pillInput
                    objectName: "notch-pill-input"
                    anchors.fill: parent
                    enabled: !root.opened
                    hoverEnabled: enabled
                    cursorShape: Qt.PointingHandCursor
                    onEntered: if (root.hoverEnabled && !root.activityPeek) hoverTimer.restart()
                    onExited: hoverTimer.stop()
                    onClicked: root.activateIsland()
                    onWheel: function(event) {
                        if (root.model && event.angleDelta.y)
                            root.model.exec(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", event.angleDelta.y > 0 ? "2%+" : "2%-"]);
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: root.t("island.open")
                    Accessible.onPressAction: root.activateIsland()
                }
            }

            HoverHandler {
                id: surfaceHover
                objectName: "notch-surface-hover"

                onHoveredChanged: {
                    if (hovered) {
                        leaveTimer.stop();
                    } else {
                        leaveTimer.restart();
                    }
                }
            }

            DropArea {
                anchors.fill: parent
                onEntered: function(drag) {
                    if (drag.hasUrls) {
                        root.openTab("files");
                    }
                }
                onDropped: function(drop) {
                    if (root.model && drop.hasUrls) {
                        root.model.action("shelf-add", drop.urls.map(String));
                        drop.acceptProposedAction();
                    }
                }
            }

            Item {
                id: content

                width: Math.max(0, card.expandedTargetWidth - (root.currentTab === "quick" ? 32 : 56))
                height: Math.max(0, card.expandedTargetHeight - 22)
                enabled: root.opened
                anchors.horizontalCenter: parent.horizontalCenter
                y: 11 + (root.spatial ? 0 : root.animationProfile.offset * (1 - root.progress))
                opacity: Math.max(0, Math.min(1, (root.progress - 0.1) / 0.65))
                scale: root.spatial ? 1 : root.animationProfile.scale + (1 - root.animationProfile.scale) * root.progress
                transformOrigin: Item.Top
                layer.enabled: root.motion && root.progress < 0.999 && root.progress > 0.01

                UI.Header {
                    id: header
                    visible: root.currentTab !== "quick"
                    height: visible ? implicitHeight : 0
                    enabled: !root.spatialTransition

                    anchors.top: parent.top
                    width: parent.width
                    host: root
                    model: root.model
                    onMoreRequested: {
                        moreMenu.open();
                    }
                }

                Loader {
                    id: page
                    enabled: !root.spatialTransition

                    property real arrival: 1

                    function inject() {
                        if (item) {
                            item.host = root;
                            item.model = Qt.binding(function() {
                                return root.model;
                            });
                            if ("mode" in item)
                                item.mode = root.subtab || "main";

                        }
                    }

                    clip: true
                    active: root.opened || (root.progress > .001 && root.currentTab !== "camera")
                    opacity: arrival
                    source: {
                        var files = {
                            "quick": "Quick.qml",
                            "home": "Home.qml",
                        "system": "System.qml",
                        "daily": "Daily.qml",
                        "weather": "Weather.qml",
                            "calendar": "Calendar.qml",
                            "files": "Files.qml",
                            "clipboard": "Clipboard.qml",
                            "focus": "Focus.qml",
                            "camera": "Mirror.qml",
                            "agents": "Agents.qml",
                            "tools": "Tools.qml",
                            "settings": "Settings.qml"
                        };
                        return Qt.resolvedUrl(files[root.currentTab] || "Home.qml");
                    }
                    onLoaded: {
                        inject();
                        arrival = 0;
                        arrive.restart();
                    }

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: header.bottom
                        topMargin: 4
                        bottom: parent.bottom
                    }

                    NumberAnimation {
                        id: arrive

                        target: page
                        property: "arrival"
                        to: 1
                        duration: root.motion ? Style.duration(210) : 0
                        easing.type: Easing.OutCubic
                    }

                    transform: Translate {
                        x: root.direction * 14 * (1 - page.arrival)
                    }

                }

                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 16
                    blur: root.animationProfile.blur / 16 * (1 - root.progress)
                    autoPaddingEnabled: false
                }

            }

            Rectangle {
                anchors.fill: parent
                radius: 19 + 9 * root.progress
                color: Qt.rgba(0, 0, 0, Math.max(0, (root.animationProfile.shade || 0) * (1 - root.progress)))
                visible: root.spatial && root.progress < 0.995
            }

            }
            ShaderEffectSource {
                anchors.fill: parent
                sourceItem: liveSurface
                live: root.spatialTransition
                hideSource: root.spatialTransition
                visible: root.spatialTransition
                enabled: false
                transform: Matrix4x4 {
                    matrix: CardTransform.matrix(card.width, root.reveal, root.animationProfile)
                }
            }

        }

        Popup {
            id: moreMenu
            onClosed: if (root.opened && !root.held) leaveTimer.restart()

            parent: window.contentItem
            x: Math.max(8, card.x + card.width - width - 12)
            y: card.y + 40
            width: 204
            padding: 6
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

            background: Rectangle {
                color: "#fa29292b"
                radius: 12
                border.color: "#35ffffff"
                border.width: 1
            }

            contentItem: Column {
                spacing: 2

                Repeater {
                    model: [{
                        "id": "quick",
                        "icon": "circle-dot",
                        "key": "island.open"
                    }, {
                        "id": "home",
                        "icon": "music-2",
                        "key": "media"
                    }, {
                        "id": "daily",
                        "icon": "list-todo",
                        "key": "nav.daily"
                    }, {
                        "id": "calendar",
                        "icon": "calendar",
                        "key": "calendar"
                    }, {
                        "id": "tools",
                        "icon": "terminal",
                        "key": "tools"
                    }, {
                        "id": "settings",
                        "icon": "settings",
                        "key": "settings"
                    }, {
                        "id": "pin",
                        "icon": root.held ? "pin-off" : "pin",
                        "key": root.held ? "unpin" : "pin"
                    }, {
                        "id": "close",
                        "icon": "x",
                        "key": "close"
                    }]

                    Rectangle {
                        required property var modelData

                        objectName: "menu-" + modelData.id
                        width: 192
                        height: 28
                        radius: 6
                        color: menuHover.hovered ? "#22ffffff" : "transparent"

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 9
                            spacing: 9

                            UI.Icon {
                                name: modelData.icon
                                size: 14
                                opacity: 0.8
                            }

                            PlainLabel {
                                text: root.t(modelData.key)
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }

                        }

                        HoverHandler {
                            id: menuHover
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (modelData.id === "pin") {
                                    root.held = !root.held;
                                    moreMenu.close();
                                } else if (modelData.id === "close") {
                                    root.close();
                                } else {
                                    root.openTab(modelData.id);
                                }
                            }
                        }

                    }

                }

            }

        }

        Rectangle {
            visible: root.opened && !!root.model && root.model.feedback !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            y: card.y + card.height + 8
            width: Math.min(480, feedback.implicitWidth + 30)
            height: 30
            radius: 15
            color: "#f029292b"
            border.color: "#22ffffff"

            PlainLabel {
                id: feedback

                anchors.fill: parent
                anchors.margins: 10
                text: root.model ? root.model.feedback : ""
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

        }

        mask: Region {
            item: card

            Region {
                item: moreMenu.visible ? moreMenu.contentItem : null
                intersection: Intersection.Combine
            }

        }

    }

    Behavior on reveal {
        NumberAnimation {
            id: revealAnimation

            duration: root.motion ? Style.duration(root.opened ? root.animationProfile.duration : Math.min(260, root.animationProfile.duration * 0.7)) : 0
            easing.type: Easing.Bezier
            easing.bezierCurve: root.opened ? root.animationProfile.curve : Motion.closingCurve
        }

    }

}
