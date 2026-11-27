// Login splash: a still of the OLED Span contours (the desktop's wallpaper) with a thin grey
// spinner, so the desktop seems to fade in over it. ksplash sets `stage` as Plasma starts.
import QtQuick
import QtQuick.Shapes

Rectangle {
    id: root
    color: "black"

    property int stage

    onStageChanged: {
        if (stage === 2)
            spinnerIn.running = true;
        else if (stage === 5)
            spinnerOut.running = true;
    }

    Image {
        anchors.fill: parent
        source: "images/contours.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        smooth: true
    }

    // A quarter arc, 2 px, that turns once a second, on a small black disc so the contour lines
    // don't run through it.
    Rectangle {
        anchors.centerIn: spinner
        width: 52
        height: 52
        radius: 26
        color: "black"
        opacity: spinner.opacity
    }

    Shape {
        id: spinner
        width: 32
        height: 32
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.72)
        opacity: 0
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            strokeColor: "#8E9194"
            strokeWidth: 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: 16
                centerY: 16
                radiusX: 13
                radiusY: 13
                startAngle: 0
                sweepAngle: 90
            }
        }

        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: 1000
            loops: Animation.Infinite
            running: true
        }
    }

    OpacityAnimator { id: spinnerIn; target: spinner; from: 0; to: 1; duration: 300 }
    OpacityAnimator { id: spinnerOut; target: spinner; from: 1; to: 0; duration: 300 }
}
