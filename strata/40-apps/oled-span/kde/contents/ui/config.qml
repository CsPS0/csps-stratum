import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: root
    twinFormLayouts: parentLayout

    property alias formLayout: root
    property alias cfg_Style: styleBox.currentIndex
    property alias cfg_Speed: speedSlider.value
    property alias cfg_Size: sizeSlider.value
    property alias cfg_Brightness: brightnessSlider.value
    property alias cfg_TopDim: topDimBox.checked
    property alias cfg_TopBand: topBandBox.value
    property alias cfg_Fps: fpsBox.value
    property alias cfg_PauseMaximized: pauseMaxBox.checked
    property alias cfg_PauseFullscreen: pauseFullBox.checked

    QQC2.ComboBox {
        id: styleBox
        Kirigami.FormData.label: "Style:"
        model: ["Topographic contours", "Silk", "Halftone"]
    }

    QQC2.Slider {
        id: speedSlider
        Kirigami.FormData.label: "Speed:"
        from: 0; to: 3; stepSize: 0.05
    }

    QQC2.Slider {
        id: sizeSlider
        Kirigami.FormData.label: "Pattern size:"
        from: 0.4; to: 2.5; stepSize: 0.05
    }

    QQC2.Slider {
        id: brightnessSlider
        Kirigami.FormData.label: "Brightness:"
        from: 0.2; to: 1.6; stepSize: 0.05
    }

    QQC2.CheckBox {
        id: topDimBox
        Kirigami.FormData.label: "Top panel:"
        text: "Keep the strip behind it dark"
    }

    QQC2.SpinBox {
        id: topBandBox
        Kirigami.FormData.label: "Top panel height (px):"
        from: 0; to: 200
        enabled: topDimBox.checked
    }

    QQC2.SpinBox {
        id: fpsBox
        Kirigami.FormData.label: "Frames per second:"
        from: 1; to: 60
    }

    QQC2.CheckBox {
        id: pauseMaxBox
        Kirigami.FormData.label: "Pause:"
        text: "While a window is maximized on this screen"
    }

    QQC2.CheckBox {
        id: pauseFullBox
        text: "While any window is fullscreen"
    }
}
