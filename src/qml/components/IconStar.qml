import QtQuick
import QtQuick.Shapes
import Bubble

Shape {
    id: root
    property real size: 24
    property color color: Theme.accent
    property real strokeWidth: Math.max(1, size / 16)
    property bool filled: true
    width: size
    height: size
    clip: false
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeColor: root.color
        strokeWidth: root.strokeWidth
        fillColor: root.filled ? root.color : "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        scale: Qt.size(root.size / 24, root.size / 24)

        PathSvg {
            path: "M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a.53.53 0 0 0 .4.29l5.16.753a.53.53 0 0 1 .294.904l-3.733 3.638a.53.53 0 0 0-.152.469l.882 5.14a.53.53 0 0 1-.77.56l-4.614-2.426a.53.53 0 0 0-.494 0L7.14 18.728a.53.53 0 0 1-.77-.56l.882-5.14a.53.53 0 0 0-.152-.47L3.367 8.92a.53.53 0 0 1 .294-.905l5.16-.752a.53.53 0 0 0 .4-.29z"
        }
    }
}
