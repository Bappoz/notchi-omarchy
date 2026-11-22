import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Item {
    id: root

    required property var service
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink && sink.ready ? sink.audio : null
    readonly property var battery: UPower.displayDevice
    readonly property var powerSample: {
        var device = battery
        if (!device || !device.ready || !device.isPresent || device.state === UPowerDeviceState.Unknown
                || device.percentage < 0 || device.percentage > 1) return null
        return {
            level: Math.round(device.percentage * 100),
            plugged: !UPower.onBattery,
            charging: device.state === UPowerDeviceState.Charging,
            full: device.state === UPowerDeviceState.FullyCharged
        }
    }
    property var previousVolume: null

    function reset() {
        previousVolume = null
        service.previousPower = null
        service.cameraInUse = false
        if (camera.running) camera.running = false
    }

    PwObjectTracker { objects: root.sink && root.service.pollingEnabled ? [root.sink] : [] }

    Connections {
        target: root.audio
        enabled: root.service.pollingEnabled
        function onVolumeChanged() { volumeSample.restart() }
        function onMutedChanged() { volumeSample.restart() }
    }

    onAudioChanged: {
        previousVolume = null
        volumeSample.restart()
    }
    onPowerSampleChanged: powerSampleTimer.restart()

    Timer {
        id: volumeSample
        interval: 45
        onTriggered: {
            if (!root.audio || !root.service.pollingEnabled || !root.service.sessionAvailable) return
            var level = Math.round(root.audio.volume * 100)
            var muted = root.audio.muted
            if (!Number.isFinite(level)) return
            var previous = root.previousVolume
            root.previousVolume = {level: level, muted: muted}
            if (previous && (level !== previous.level || muted !== previous.muted)
                    && Date.now() - root.service.lastOsdVolumeAt > 220)
                root.service.showVolume(level, muted)
        }
    }

    Timer {
        id: powerSampleTimer
        interval: 750
        onTriggered: {
            if (root.service.pollingEnabled && root.service.sessionAvailable)
                root.service.observePower(root.powerSample)
        }
    }

    Process {
        id: camera
        command: ["/usr/bin/python3", root.service.eventAdapter, "camera"]
        property int epoch: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.service.sessionAvailable && camera.epoch === root.service.noticeEpoch)
                    root.service.cameraInUse = text.trim() === "true"
            }
        }
    }

    Timer {
        interval: 1800
        running: root.service.pollingEnabled && root.service.sessionAvailable
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (camera.running) return
            camera.epoch = root.service.noticeEpoch
            camera.running = true
        }
    }

    Connections {
        target: root.service
        function onNoticeEpochChanged() { root.reset() }
        function onSessionAvailableChanged() {
            if (root.service.sessionAvailable) {
                volumeSample.restart()
                powerSampleTimer.restart()
            }
        }
    }
}
