import QtQuick
import QtQuick.Shapes
import ".." as App

Item {
    id: root
    required property int level
    required property string caption
    property bool showCaption: true
    property color tint: level <= 20 ? "#ffb16a" : "#83e9ab"
    property bool motion: true
    property real sweep: Math.max(0, Math.min(360, level * 3.6))
    implicitWidth: showCaption ? 43 : 36
    implicitHeight: showCaption ? 51 : 36
    Accessible.role: Accessible.StaticText
    Accessible.name: caption + " " + level + "%"

    Behavior on sweep { NumberAnimation { duration: root.motion ? 210 : 0; easing.type: Easing.OutCubic } }

    Shape {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 36
        height: width
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: "#30343a"
            strokeWidth: 2.6
            PathAngleArc { centerX: 18; centerY: 18; radiusX: 15; radiusY: 15; startAngle: -90; sweepAngle: 360 }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.tint
            strokeWidth: 2.6
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: 18; centerY: 18; radiusX: 15; radiusY: 15; startAngle: -90; sweepAngle: root.sweep }
        }

        App.PlainLabel {
            anchors.centerIn: parent
            text: root.level + "%"
            font.pixelSize: 10
            font.weight: Font.Bold
        }
    }

    App.PlainLabel {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 38
        visible: root.showCaption
        text: root.caption
        color: "#aeb3bf"
        font.pixelSize: 9
    }
}
