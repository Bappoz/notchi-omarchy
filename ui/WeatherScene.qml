import QtQuick

Item {
    id: root

    property string kind: "clear"
    property bool night: false
    property bool motion: true
    property real phase: 0

    implicitWidth: 140
    implicitHeight: 100
    onKindChanged: scene.requestPaint()
    onNightChanged: scene.requestPaint()

    FrameAnimation {
        property real elapsed: 0

        running: root.visible && root.motion
        onTriggered: {
            elapsed += frameTime;
            if (elapsed > 0.05) {
                root.phase += elapsed;
                elapsed = 0;
            }
        }
    }

    Canvas {
        id: scene

        property real tick: root.phase

        anchors.fill: parent
        onTickChanged: requestPaint()
        onPaint: {
            var c = getContext("2d"), w = width, h = height, t = root.motion ? root.phase : 0, r = Math.min(w, h), rain = root.kind === "rain" || root.kind === "storm", cloudy = root.kind !== "clear" && root.kind !== "dry";
            c.reset();
            c.save();
            c.translate(w * 0.46, h * 0.43);
            var sun = r * 0.22;
            c.fillStyle = root.night ? "#d5e6f3" : "#f2cd83";
            c.shadowColor = root.night ? "#466b9f" : "#dca94c";
            c.shadowBlur = 14;
            c.beginPath();
            c.arc(0, 0, sun, 0, Math.PI * 2);
            c.fill();
            c.shadowBlur = 0;
            if (!root.night) {
                c.strokeStyle = "#a6f4d69b";
                c.lineWidth = 2;
                for (var i = 0; i < 8; i++) {
                    var a = i * Math.PI / 4 + t * 0.1;
                    c.beginPath();
                    c.moveTo(Math.cos(a) * sun * 1.4, Math.sin(a) * sun * 1.4);
                    c.lineTo(Math.cos(a) * sun * 1.7, Math.sin(a) * sun * 1.7);
                    c.stroke();
                }
            } else {
                c.fillStyle = "#5b7791";
                c.beginPath();
                c.arc(-sun * 0.4, -sun * 0.3, sun * 0.9, 0, Math.PI * 2);
                c.fill();
            }
            c.restore();
            if (cloudy) {
                c.save();
                c.translate(w * 0.52 + Math.sin(t * 0.5) * 2, h * 0.53);
                c.fillStyle = root.kind === "storm" ? "#97a7bd" : "#d2e0e6";
                c.beginPath();
                c.moveTo(-r * 0.32, r * 0.1);
                c.bezierCurveTo(-r * 0.55, -r * 0.04, -r * 0.25, -r * 0.3, -r * 0.1, -r * 0.15);
                c.bezierCurveTo(0, -r * 0.42, r * 0.34, -r * 0.31, r * 0.3, -r * 0.1);
                c.bezierCurveTo(r * 0.54, -r * 0.08, r * 0.5, r * 0.16, r * 0.28, r * 0.15);
                c.lineTo(-r * 0.32, r * 0.15);
                c.fill();
                c.restore();
            }
            if (rain || root.kind === "snow") {
                for (var j = 0; j < 7; j++) {
                    var x = w * 0.3 + j * r * 0.08, y = h * 0.68 + ((t * 0.48 + j * 0.13) % 1) * h * 0.23;
                    c.globalAlpha = 0.3 + 0.6 * (1 - (t * 0.48 + j * 0.13) % 1);
                    c.strokeStyle = "#a2cce7";
                    c.lineWidth = 2;
                    c.beginPath();
                    c.moveTo(x, y);
                    c.lineTo(x - (root.kind === "snow" ? 0 : 2), y + (root.kind === "snow" ? 2 : 5));
                    c.stroke();
                }
                c.globalAlpha = 1;
            }
            if (root.kind === "storm" && (!root.motion || t % 4 < 0.45)) {
                c.fillStyle = "#f1d695";
                c.beginPath();
                c.moveTo(w * 0.53, h * 0.65);
                c.lineTo(w * 0.45, h * 0.82);
                c.lineTo(w * 0.52, h * 0.8);
                c.lineTo(w * 0.49, h * 0.96);
                c.lineTo(w * 0.65, h * 0.73);
                c.lineTo(w * 0.57, h * 0.75);
                c.lineTo(w * 0.61, h * 0.65);
                c.closePath();
                c.fill();
            }
        }
    }

}
