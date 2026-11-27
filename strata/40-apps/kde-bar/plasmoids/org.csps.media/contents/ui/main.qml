// "♫ Track  ⏮ ⏯ ⏭  ▁▃▅▂" for the current media player, as on the Windows menu bar.
// The player comes from Plasma's MPRIS model (the one the media controller uses). The visualizer
// reads levels from ~/.local/share/kde-bar/cava-levels.py on 127.0.0.1:47836, about 20 times a
// second and only while playing; the widget starts the helper when it doesn't answer, and the
// helper stops cava and exits on its own a few seconds after playback stops. Without cava the
// bars stay flat. Hidden when no player has a track.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.mpris as Mpris

PlasmoidItem {
    id: root

    readonly property int bars: 12
    readonly property var player: mpris.currentPlayer
    readonly property string track: player ? (player.track || "") : ""
    readonly property bool playing: player !== null && player.playbackStatus === Mpris.PlaybackStatus.Playing
    property var levels: []
    property real lastStart: 0

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    toolTipMainText: track
    toolTipSubText: player ? (player.artist || player.identity || "") : ""

    Mpris.Mpris2Model { id: mpris }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source) => disconnectSource(source)
    }

    function startHelper() {
        if (Date.now() - lastStart < 3000)
            return;
        lastStart = Date.now();
        exec.connectSource("setsid -f python3 -I \"$HOME/.local/share/kde-bar/cava-levels.py\" --bars " + bars + " >/dev/null 2>&1");
    }

    function poll() {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status === 200)
                root.levels = xhr.responseText.split(";").map(Number);
            else
                root.startHelper();
        };
        xhr.open("GET", "http://127.0.0.1:47836/");
        xhr.send();
    }

    Timer {
        interval: 50
        repeat: true
        running: root.playing
        onTriggered: root.poll()
        onRunningChanged: if (!running) root.levels = []
    }

    function glyph(cp) { return String.fromCodePoint(cp) }

    fullRepresentation: RowLayout {
        visible: root.track !== ""
        spacing: 6
        Layout.preferredWidth: root.track !== "" ? implicitWidth : 0
        Layout.fillHeight: true

        // Gap after the app name (the panel ignores margins on the widget's outer item).
        Item { Layout.preferredWidth: 8 }

        PlasmaComponents.Label {
            text: "♫ " + root.track
            elide: Text.ElideRight
            Layout.maximumWidth: 170
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: "#A0A3A7"
            Layout.fillHeight: true
            verticalAlignment: Text.AlignVCenter
            MouseArea {
                anchors.fill: parent
                onClicked: if (root.player && root.player.canRaise) root.player.Raise()
            }
        }

        Repeater {
            model: [
                { cp: 0xF04AE, on: () => root.player.Previous(), enabled: root.player && root.player.canGoPrevious },
                { cp: root.playing ? 0xF03E4 : 0xF040A, on: () => root.player.PlayPause(), enabled: root.player && root.player.canControl },
                { cp: 0xF04AD, on: () => root.player.Next(), enabled: root.player && root.player.canGoNext }
            ]
            PlasmaComponents.Label {
                required property var modelData
                text: root.glyph(modelData.cp)
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                color: !modelData.enabled ? "#555555" : button.containsMouse ? "#FFFFFF" : "#E6E6E6"
                Layout.fillHeight: true
                verticalAlignment: Text.AlignVCenter
                MouseArea {
                    id: button
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: if (parent.modelData.enabled) parent.modelData.on()
                }
            }
        }

        // Visualizer: 12 bars on a baseline, flat while paused.
        Item {
            Layout.preferredWidth: root.bars * 4 - 2
            Layout.preferredHeight: 14
            Layout.alignment: Qt.AlignVCenter
            Row {
                anchors.fill: parent
                spacing: 2
                Repeater {
                    model: root.bars
                    Rectangle {
                        required property int index
                        width: 2
                        height: Math.max(1, Math.round(14 * (root.levels[index] || 0) / 100))
                        y: 14 - height
                        color: "#A0A3A7"
                        Behavior on height { NumberAnimation { duration: 45 } }
                    }
                }
            }
        }
    }
}
