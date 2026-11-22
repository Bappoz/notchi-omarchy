import QtQuick

IconButton {
    id: root
    required property var host
    objectName: "notch-settings"
    iconName: "settings"
    iconSize: 16
    tint: "#c2cdec"
    selected: host.currentTab === "settings"
    circular: true
    hint: host.t("settings")
    glyphRotation: selected ? 90 : hovered ? 42 : 0
    glyphMotion: host.motion
    onClicked: host.openTab(selected ? host.settingsReturnTab : "settings")
}
