import QtQuick

Canvas {
    id: root

    property real radius: 19
    property color tint: "white"
    property bool running: false
    property bool motion: true
    property double alertAt: 0
    property real phase: 0
    property real flash: 0
    readonly property real intensity: Math.max(running ? .65 : 0, flash)

    visible: intensity > 0
    onTintChanged: requestPaint()
    onIntensityChanged: requestPaint()
    onPhaseChanged: requestPaint()
    onRadiusChanged: requestPaint()

    FrameAnimation {
        property real elapsed: 0
        running: root.visible && root.motion
        onTriggered: {
            elapsed += frameTime;
            if (elapsed < .024) return;
            root.phase = (root.phase + elapsed * (root.flash > .1 ? .8 : .24)) % 1;
            elapsed = 0;
        }
    }

    SequentialAnimation {
        id: sweep
        NumberAnimation { target: root; property: "flash"; to: 1; duration: 150; easing.type: Easing.OutCubic }
        PauseAnimation { duration: 240 }
        NumberAnimation { target: root; property: "flash"; to: 0; duration: 800; easing.type: Easing.OutCubic }
    }

    onAlertAtChanged: if (alertAt && motion) sweep.restart()
    onMotionChanged: if (!motion) { sweep.stop(); flash = 0; phase = 0 }

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        if (!visible || width < 8 || height < 8) return;
        var inset = 2, w = width - 2 * inset, h = height - 2 * inset;
        var r = Math.min(radius - inset, h / 2, w / 2);
        var straight = w - 2 * r, side = h - 2 * r, arc = Math.PI * r / 2;
        var perimeter = 2 * (straight + side) + 4 * arc;

        function point(fraction) {
            var d = ((fraction % 1 + 1) % 1) * perimeter;
            if (d < straight) return [r + d, 0];
            d -= straight;
            if (d < arc) return corner(w - r, r, d / r - Math.PI / 2);
            d -= arc;
            if (d < side) return [w, r + d];
            d -= side;
            if (d < arc) return corner(w - r, h - r, d / r);
            d -= arc;
            if (d < straight) return [w - r - d, h];
            d -= straight;
            if (d < arc) return corner(r, h - r, d / r + Math.PI / 2);
            d -= arc;
            if (d < side) return [0, h - r - d];
            return corner(r, r, (d - side) / r + Math.PI);
        }

        function corner(x, y, angle) {
            return [x + r * Math.cos(angle), y + r * Math.sin(angle)];
        }

        ctx.translate(inset, inset);
        ctx.lineWidth = 1.65;
        ctx.lineCap = "round";
        var tail = .27, segments = 36;
        var first = point(phase - tail), head = point(phase);
        var gradient = ctx.createLinearGradient(first[0], first[1], head[0], head[1]);
        gradient.addColorStop(0, Qt.rgba(tint.r, tint.g, tint.b, 0));
        gradient.addColorStop(.45, Qt.rgba(tint.r, tint.g, tint.b, intensity * .14));
        gradient.addColorStop(.8, Qt.rgba(tint.r, tint.g, tint.b, intensity * .55));
        gradient.addColorStop(1, Qt.rgba(tint.r, tint.g, tint.b, intensity));
        ctx.strokeStyle = gradient;
        ctx.beginPath();
        ctx.moveTo(first[0], first[1]);
        for (var i = 1; i <= segments; ++i) {
            var next = point(phase - tail + tail * i / segments);
            ctx.lineTo(next[0], next[1]);
        }
        ctx.stroke();
    }
}
