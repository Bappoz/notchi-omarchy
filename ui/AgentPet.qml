import QtQuick
import "Knot.js" as Knot

Item {
    id: root

    property string provider: "claude"
    property bool working: false
    property string activity: working ? "working" : "idle"
    property bool motion: true
    property real phase: 0
    readonly property bool sleeping: activity === "idle" || activity === "away" || activity === "sleeping"
    readonly property string expression: activity
    readonly property string character: provider === "codex" ? "gpt" : "claude"

    implicitWidth: 80
    implicitHeight: 80
    onActivityChanged: art.requestPaint()
    onMotionChanged: art.requestPaint()
    onProviderChanged: art.requestPaint()

    FrameAnimation {
        property real elapsed: 0

        running: root.visible && root.motion
        onTriggered: {
            elapsed += frameTime;
            if (elapsed >= 0.04) {
                root.phase += elapsed;
                elapsed = 0;
            }
        }
    }

    Canvas {
        id: art

        property real tick: root.phase

        anchors.fill: parent
        onTickChanged: requestPaint()
        onPaint: {
            var c = getContext("2d"), s = Math.min(width / 96, height / 96), t = root.motion ? root.phase : 0;
            c.reset();
            c.translate((width - 96 * s) / 2, (height - 96 * s) / 2);
            c.scale(s, s);
            var gpt = root.provider === "codex", body = gpt ? "#84edbd" : "#d77b59", dark = gpt ? "#153e37" : "#542e27";
            var coding = root.activity === "working" || root.activity === "coding", thinking = root.activity === "thinking" || root.activity === "waiting", reading = root.activity === "reading", monitoring = root.activity === "monitoring";
            var bob = root.motion ? Math.round(Math.sin(t * (root.sleeping ? 1.4 : coding ? 5 : 2)) * (root.sleeping ? 1 : 0.7)) : 0;
            c.save();
            c.translate(0, bob);
            // Ground contact stays fixed; the torso and props share a restrained rig.
            rect(c, 22, 85, 53, 2, "#16000000");
            if (gpt) {
                c.save();
                c.translate(9, 5);
                c.fillStyle = body;
                for (var i = 0; i < Knot.spans.length; i++) {
                    var r = Knot.spans[i];
                    c.fillRect(r[0], r[1], r[2], 1);
                }
                // Solid original face panel: only two eyes are added below.
                poly(c, [[32, 26], [43, 26], [43, 28], [48, 28], [49, 30], [49, 46], [46, 49], [33, 49], [29, 47], [29, 30], [32, 28]], body);
                c.restore();
            } else {
                rect(c, 19, 31, 58, 33, body);
                rect(c, 8, 42, 12, 12, body);
                rect(c, 76, 42, 12, 12, body);
                rect(c, 22, 64, 7, 17, body);
                rect(c, 36, 64, 7, 17, body);
                rect(c, 52, 64, 7, 17, body);
                rect(c, 66, 64, 7, 17, body);
                rect(c, 21, 32, 54, 1, "#e99674");
            }
            var ey = gpt ? 39 : 42, ex1 = gpt ? 42 : 32, ex2 = gpt ? 53 : 58;
            var blink = root.motion && ((t % 5.2) > 4.98), eyeH = blink ? 1 : 7, scan = reading ? Math.floor(Math.sin(t * 1.8)) : thinking ? -1 : 0;
            if (root.sleeping) {
                rect(c, ex1 - 2, ey + 3, 7, 2, dark);
                rect(c, ex2 - 2, ey + 3, 7, 2, dark);
            } else {
                rect(c, ex1 + scan, ey + (blink ? 3 : 0), 3, eyeH, dark);
                rect(c, ex2 + scan, ey + (blink ? 3 : 0), 3, eyeH, dark);
            }
            if (gpt) {
                rect(c, 11, 53, 7, 11, body);
                rect(c, 78, 53, 7, 11, body);
            }
            if (root.sleeping) {
                // Rising pixel Zs; a still sleeping pose remains when motion is off.
                for (var z = 0; z < 3; z++) {
                    var drift = root.motion ? (t * .45 + z * .28) % 1 : z * .28;
                    var zx = 65 + z * 10, zy = 23 - z * 9 - Math.round(drift * 4), size = 7 - z;
                    c.save();
                    c.globalAlpha = root.motion ? .45 + .5 * Math.sin(drift * Math.PI) : .85;
                    rect(c, zx, zy, size, 1, "#d5e2e8");
                    rect(c, zx, zy + size - 1, size, 1, "#d5e2e8");
                    for (var diagonal = 1; diagonal < size - 1; diagonal++)
                        rect(c, zx + size - 1 - diagonal, zy + diagonal, 1, 1, "#d5e2e8");
                    c.restore();
                }
            } else if (coding) {
                // Small angled terminal screen, keyboard deck and alternating taps.
                poly(c, [[21, 57], [71, 57], [74, 77], [24, 77]], "#29373d");
                poly(c, [[25, 60], [68, 60], [70, 73], [27, 73]], "#15282e");
                rect(c, 29, 63, 5, 2, "#8ddfc0");
                rect(c, 36, 63, 17, 1, "#608f84");
                rect(c, 29, 67, 26, 1, "#6bac98");
                rect(c, 29, 70, 15, 1, "#466c65");
                poly(c, [[20, 77], [76, 77], [81, 83], [16, 83]], "#87989e");
                rect(c, 18, 83, 61, 2, "#45585f");
                for (var row = 0; row < 2; row++) for (var key = 0; key < 10; key++) rect(c, 24 + key * 4, 78 + row * 2, 3, 1, "#354a52")
                var tap = root.motion ? Math.floor(t * 8) % 2 : 0;
                if (!gpt) {
                    rect(c, 16, 52, 10, 13, body);
                    rect(c, 70, 52, 10, 13, body);
                }
                poly(c, [[15, 57], [21, 57], [33, 75 - tap], [28, 78 - tap], [20, 68]], body);
                poly(c, [[76, 57], [82, 57], [74, 68], [61, 78 - (1 - tap)], [56, 75 - (1 - tap)]], body);
            } else if (reading) {
                // Glasses stay aligned with the original eyes, with no mouth/brows.
                c.strokeStyle = "#293948";
                c.lineWidth = 2;
                c.strokeRect(ex1 - 4, ey - 3, 12, 13);
                c.strokeRect(ex2 - 4, ey - 3, 12, 13);
                stroke(c, [[ex1 + 8, ey + 1], [ex2 - 4, ey + 1]], "#293948", 2);
                rect(c, ex1 - 3, ey - 2, 9, 3, "#229ed5ee");
                rect(c, ex2 - 3, ey - 2, 9, 3, "#229ed5ee");
                poly(c, [[20, 58], [47, 61], [74, 58], [74, 81], [47, 85], [20, 81]], "#537d73");
                poly(c, [[23, 56], [47, 61], [47, 81], [23, 77]], "#fff1d8");
                poly(c, [[47, 61], [71, 56], [71, 77], [47, 81]], "#eddfc4");
                stroke(c, [[47, 61], [47, 81]], "#b4a58d", 1);
                for (var line = 0; line < 4; line++) {
                    stroke(c, [[27, 61 + line * 4], [42, 64 + line * 4]], "#b8a991", 1);
                    stroke(c, [[52, 64 + line * 4], [67, 61 + line * 4]], "#b8a991", 1);
                }
                var page = root.motion ? Math.max(0, Math.sin(t * 1.1) - 0.8) * 5 : 0;
                if (page > 0)
                    poly(c, [[47, 61], [47 + 22 * page, 56], [47 + 22 * page, 77], [47, 81]], "#fff5df");

                rect(c, 15, 61, 10, 10, body);
                rect(c, 70, 61, 10, 10, body);
                if (!gpt) {
                    rect(c, 14, 51, 8, 13, body);
                    rect(c, 74, 51, 8, 13, body);
                }
            } else if (monitoring) {
                var mx = 72 + Math.round(Math.sin(t * 1.8) * 2), my = 42 + Math.round(Math.cos(t * 1.8));
                if (!gpt)
                    rect(c, 75, 51, 9, 13, body);

                stroke(c, [[mx - 5, my + 9], [mx - 13, my + 24]], "#35434b", 7);
                rect(c, mx - 17, my + 17, 10, 8, body);
                c.beginPath();
                c.arc(mx, my, 12, 0, Math.PI * 2);
                c.fillStyle = "#3569b1cf";
                c.fill();
                c.strokeStyle = "#364751";
                c.lineWidth = 5;
                c.stroke();
                c.strokeStyle = "#d8bc78";
                c.lineWidth = 2;
                c.stroke();
                stroke(c, [[mx - 6, my - 6], [mx - 2, my - 8], [mx + 2, my - 8]], "#ccf5ffff", 2);
            } else if (thinking) {
                // Pixel cloud and two small thought puffs, with sequenced dots.
                rect(c, 56, 5, 27, 20, "#f4eddb");
                rect(c, 52, 9, 35, 12, "#f4eddb");
                rect(c, 59, 2, 20, 24, "#f4eddb");
                rect(c, 53, 27, 5, 5, "#f4eddb");
                rect(c, 48, 35, 3, 3, "#f4eddb");
                for (var dot = 0; dot < 3; dot++) rect(c, 60 + dot * 7, 12, 3, 3, (!root.motion || Math.floor(t * 3) % 3 === dot) ? dark : "#9b9284")
            } else if (root.activity === "completed") {
                rect(c, 73, 10, 3, 12, "#cbbd79");
                rect(c, 69, 14, 11, 3, "#cbbd79");
                rect(c, 14, 21, 2, 7, "#90b7b4");
                rect(c, 12, 23, 6, 2, "#90b7b4");
            }
            c.restore();
        }

        function rect(c, x, y, w, h, col) {
            c.fillStyle = col;
            c.fillRect(x, y, w, h);
        }

        function poly(c, points, col) {
            c.fillStyle = col;
            c.beginPath();
            c.moveTo(points[0][0], points[0][1]);
            for (var j = 1; j < points.length; j++) c.lineTo(points[j][0], points[j][1])
            c.closePath();
            c.fill();
        }

        function stroke(c, points, col, w) {
            c.strokeStyle = col;
            c.lineWidth = w;
            c.lineJoin = "round";
            c.lineCap = "square";
            c.beginPath();
            c.moveTo(points[0][0], points[0][1]);
            for (var j = 1; j < points.length; j++) c.lineTo(points[j][0], points[j][1])
            c.stroke();
        }

    }

}
