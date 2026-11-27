// Folder, terminal, gauge and gear glyphs in a grey pill next to the clock, as on the Windows top
// bar (yasb quick_apps): Dolphin, WezTerm, System Monitor, System Settings.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    readonly property var apps: [
        { glyph: "", name: "Dolphin", cmd: "dolphin" },
        { glyph: "", name: "WezTerm", cmd: "wezterm" },
        { glyph: "", name: "System Monitor", cmd: "plasma-systemmonitor" },
        { glyph: "", name: "System Settings", cmd: "systemsettings" }
    ]

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source) => disconnectSource(source)
    }

    fullRepresentation: Item {
        Layout.preferredWidth: pill.width + 8
        Layout.fillHeight: true

        Rectangle {
            id: pill
            anchors.centerIn: parent
            width: row.implicitWidth + 6
            height: parent.height - 4
            radius: 8
            color: Qt.rgba(1, 1, 1, 0.06)

            Row {
                id: row
                anchors.centerIn: parent
                Repeater {
                    model: root.apps
                    PlasmaComponents.Label {
                        required property var modelData
                        width: implicitWidth + 10
                        height: pill.height
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.glyph
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: hover.containsMouse ? "#FFFFFF" : "#B4B6B8"
                        PlasmaCore.ToolTipArea {
                            anchors.fill: parent
                            mainText: parent.modelData.name
                        }
                        MouseArea {
                            id: hover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: exec.connectSource("setsid -f " + parent.modelData.cmd + " >/dev/null 2>&1")
                        }
                    }
                }
            }
        }
    }
}
