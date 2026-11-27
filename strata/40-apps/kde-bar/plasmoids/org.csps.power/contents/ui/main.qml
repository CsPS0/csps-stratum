// A power glyph at the right end of the top bar, as on Windows. Click: KDE's leave screen.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    toolTipMainText: "Shut down, restart or log out"

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source) => disconnectSource(source)
    }

    fullRepresentation: MouseArea {
        Layout.preferredWidth: glyph.implicitWidth + 8
        Layout.fillHeight: true
        hoverEnabled: true
        onClicked: exec.connectSource("qdbus6 org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt.promptAll")

        PlasmaComponents.Label {
            id: glyph
            anchors.centerIn: parent
            text: ""
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: parent.containsMouse ? "#FFFFFF" : "#E6E6E6"
        }
    }
}
