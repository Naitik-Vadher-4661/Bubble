import QtQuick
import QtQuick.Shapes

Shape {
    id: root
    property real size: 24
    property color color: "#f9e2af"
    property real strokeWidth: Math.max(1, size / 12)
    property bool emojiStyle: true
    width: size
    height: size
    clip: false
    preferredRendererType: Shape.CurveRenderer

    // Base star with rich golden gradient and warm amber border
    ShapePath {
        strokeColor: root.emojiStyle ? "#f5a938" : root.color
        strokeWidth: root.emojiStyle ? 0.8 : root.strokeWidth
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        scale: Qt.size(root.size / 24, root.size / 24)
        fillGradient: root.emojiStyle ? baseGradient : null
        fillColor: "transparent"

        PathSvg {
            path: "M12.759,1.356l2.524,5.756c0.193,0.441,0.611,0.742,1.091,0.786l6.148,0.551c0.696,0.101,0.973,0.954,0.469,1.446 L18.36,13.785c-0.375,0.315-0.546,0.81-0.443,1.288l1.346,6.302c0.118,0.692-0.608,1.221-1.23,0.892L12.668,19.125c-0.413-0.242-0.922-0.242-1.335,0 l-5.366,3.141c-0.621,0.326-1.348-0.201-1.23-0.892l1.346-6.302c0.101-0.478-0.068-0.973-0.443-1.288L1.007,9.896c-0.503-0.489-0.225-1.344,0.469-1.446 l6.148-0.551c0.48-0.043,0.898-0.345,1.091-0.786l2.524-5.756C11.552,0.728,12.448,0.728,12.759,1.356z"
        }
    }

    LinearGradient {
        id: baseGradient
        x1: 12; y1: 1; x2: 12; y2: 23
        GradientStop { position: 0.0; color: "#fff0a6" }
        GradientStop { position: 0.35; color: (root.color !== "" && root.color !== "#ffffff" && root.color !== "#000000") ? root.color : "#f9e2af" }
        GradientStop { position: 1.0; color: "#fab387" }
    }

    // Highlight facet on upper arm
    ShapePath {
        strokeColor: "transparent"
        fillColor: root.emojiStyle ? "#ffffff" : "transparent"
        scale: Qt.size(root.size / 24, root.size / 24)
        PathSvg {
            path: "M12.576,7.457l-0.427-4.241c-0.017-0.236-0.066-0.641,0.313-0.641c0.3,0,0.463,0.624,0.463,0.624l1.282,3.405 c0.484,1.296,0.285,1.74-0.182,2.002C13.489,8.906,12.697,8.672,12.576,7.457z"
        }
    }

    // 3D Shadow facet on bottom-right arm
    ShapePath {
        strokeColor: "transparent"
        fillColor: root.emojiStyle ? "#e59030" : "transparent"
        scale: Qt.size(root.size / 24, root.size / 24)
        PathSvg {
            path: "M17.865,13.408L21.544,10.538c0.182-0.152,0.51-0.394,0.247-0.669c-0.208-0.217-0.771,0.096-0.771,0.096l-3.219,1.258 c-0.96,0.332-1.597,0.823-1.654,1.442C16.074,13.489,16.815,14.124,17.865,13.408z"
        }
    }
}
