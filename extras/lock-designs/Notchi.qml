import QtQuick
import QtQuick.Shapes
import qs.Commons
import "../plugins/io.github.sirjul1337.lock-explorer/designs"

DesignBase {
    id: lock
    inputItem: field.input

    property bool entered: false
    property bool passwordRequestedByClick: false
    readonly property bool showPasswordField: inputEnabled && (passwordRequestedByClick
        || passwordText.length > 0 || authenticatingPassword || failureMessage.length > 0 || fido2Active)

    // Lock Explorer disables input after authentication, while the secure
    // surface is still on screen for its fade transition.
    property real openness: inputEnabled && entered ? 0 : 1
    Behavior on openness {
        NumberAnimation { duration: Style.duration(250); easing.type: Easing.OutCubic }
    }
    Timer {
        interval: Style.duration(45)
        running: lock.inputEnabled && !lock.entered
        onTriggered: lock.entered = true
    }

    Wallpaper {
        anchors.fill: parent
        lock: lock
        blur: 0
        dim: 0
        contrast: 0
        vignette: false
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
        onPositionChanged: if (!lock.screenAwake) lock.wakeRequested()
    }

    Rectangle {
        id: badge
        anchors.horizontalCenter: parent.horizontalCenter
        y: 6
        width: 36 + 44 * lock.openness
        height: 36
        radius: height / 2
        color: "#080a10"
        border.color: "#3b414d"

        Accessible.role: Accessible.Button
        Accessible.name: lock.tr("Enter Password")
        Accessible.onPressAction: tap.revealField()

        Shape {
            anchors.centerIn: parent
            width: 20
            height: 20
            antialiasing: true

            ShapePath {
                strokeColor: "#eef0f6"
                strokeWidth: 1.5
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                startX: 6.5
                startY: 11.5
                PathLine { x: 6.5; y: 6.5 - 2.5 * lock.openness }
                PathQuad { x: 10; y: 3 - 2.5 * lock.openness; controlX: 6.5; controlY: 3 - 2.5 * lock.openness }
                PathQuad { x: 13.5; y: 6.5 - 2.5 * lock.openness; controlX: 13.5; controlY: 3 - 2.5 * lock.openness }
                PathLine { x: 13.5; y: 11.5 - 4.5 * lock.openness }
            }

            Rectangle {
                x: 4
                y: 10
                width: 12
                height: 8
                radius: 2.5
                color: badge.color
                border.color: "#eef0f6"
                border.width: 1.5
            }
        }

        TapHandler {
            id: tap
            enabled: lock.inputEnabled
            onTapped: revealField()
            function revealField() {
                if (!lock.inputEnabled) return
                lock.passwordRequestedByClick = true
                lock.wakeRequested()
                lock.forcePasswordFocus()
            }
        }
    }

    PasswordField {
        id: field
        lock: lock
        anchors.horizontalCenter: badge.horizontalCenter
        anchors.top: badge.bottom
        anchors.topMargin: 7
        width: Math.max(0, Math.min(320, parent.width - 24))
        height: 45
        radius: height / 2
        color: badge.color
        textColor: "#eef0f6"
        mutedColor: "#bdc5d4"
        outlineColor: badge.border.color
        outlineThickness: 1
        showLockGlyph: false
        placeholder: lock.tr("Enter Password")
        opacity: lock.showPasswordField ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Style.duration(125); easing.type: Easing.OutCubic }
        }
    }

    Text {
        anchors.horizontalCenter: field.horizontalCenter
        anchors.top: field.bottom
        anchors.topMargin: 6
        visible: lock.inputEnabled && text.length > 0
        textFormat: Text.PlainText
        text: lock.failureMessage
        color: "#ffd4ca"
        style: Text.Outline
        styleColor: badge.color
        font.pixelSize: 13
    }
}
