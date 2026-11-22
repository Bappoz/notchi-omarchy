import QtQuick
import ".." as App

Item {
    id: root

    required property var host

    Row {
        id: agents
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        opacity: 1 - host.alertProgress
        visible: opacity > 0

        Repeater {
            model: host.model ? host.model.activeProviders : []
            CompactAgent {
                required property string modelData
                provider: modelData
                motion: host.motion
            }
        }
    }

    Column {
        objectName: "notch-clock"
        anchors.horizontalCenter: parent.horizontalCenter
        y: (parent.height - height) / 2 - 5 * host.alertProgress
        spacing: 0
        opacity: 1 - host.alertProgress

        App.PlainLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: host.compactTime
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        App.PlainLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: host.compactDate
            font.pixelSize: 9
            color: "#b5b5bf"
        }
    }

    Icon {
        id: connectionIcon
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        name: host.connectionAlert ? host.signalIcon : ""
        color: host.signalTint
        size: 17
        opacity: host.connectionAlert ? host.alertProgress : 0
    }

    App.PlainLabel {
        anchors.left: parent.left
        anchors.leftMargin: host.connectionAlert ? 40 : 15
        anchors.right: signalMark.left
        anchors.rightMargin: 6
        y: (parent.height - height) / 2 + 6 * (1 - host.alertProgress)
        text: host.noticeLabel
        font.pixelSize: 12
        font.weight: Font.DemiBold
        opacity: host.alertProgress
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5
        opacity: 1 - host.alertProgress

        App.PlainLabel {
            anchors.verticalCenter: parent.verticalCenter
            text: host.model ? host.model.islandClock : ""
            visible: text.length > 0
            color: "#ffc17c"
            font.pixelSize: 11
            font.weight: Font.Medium
        }

        IslandSignal {
            visible: !!kind && kind !== "working" && kind !== "timer"
            kind: host.activityPeek ? "" : host.signalKind
            name: host.signalIcon
            tint: host.signalTint
            motion: host.motion
        }
    }

    IslandSignal {
        id: signalMark
        x: parent.width - width - 10
        anchors.verticalCenter: parent.verticalCenter
        kind: host.activityPeek ? host.signalKind : ""
        name: host.signalIcon
        tint: host.signalTint
        alertAt: host.activityPeek ? host.peekNotice.queuedAt : 0
        motion: host.motion
        opacity: host.peekNotice.kind === "agent" || host.connectionAlert ? 0 : host.alertProgress
    }

    CompactAgent {
        anchors.centerIn: signalMark
        provider: host.peekNotice.provider || "claude"
        motion: host.motion
        visible: opacity > 0
        opacity: host.peekNotice.kind === "agent" ? host.alertProgress : 0
    }

    Rectangle {
        anchors.centerIn: signalMark
        width: 25
        height: width
        radius: width / 2
        color: Qt.alpha(host.signalTint, .08)
        border.color: Qt.alpha(host.signalTint, .5)
        opacity: host.connectionAlert ? host.alertProgress : 0
        visible: opacity > 0

        Icon {
            anchors.centerIn: parent
            name: "check"
            color: host.signalTint
            size: 12
        }

        IslandOrbit {
            anchors.fill: parent
            radius: parent.radius
            tint: host.signalTint
            running: host.connectionAlert
            motion: host.motion
        }
    }

}
