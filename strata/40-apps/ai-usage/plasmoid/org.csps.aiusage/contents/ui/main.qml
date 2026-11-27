// Panel text for Claude and Antigravity quota used, e.g. "Claude 37% used   Antigravity 12% used".
// Runs ~/.local/share/ai-usage/ai_usage.py every minute; each label is shown only while its app
// runs, and the widget takes no room when both are hidden. Click for a popup with every limit,
// its bar and reset time.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property string script: "python3 -I \"$HOME/.local/share/ai-usage/ai_usage.py\""
    readonly property var apps: ["claude", "antigravity"]
    property var usage: ({})
    readonly property var shown: apps.filter(a => usage[a])

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: ""
    toolTipSubText: ""

    function refresh() {
        for (const a of apps)
            exec.connectSource(script + " " + a)
    }

    onExpandedChanged: if (expanded) refresh()

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            const app = source.slice(source.lastIndexOf(" ") + 1)
            let value = null
            try {
                const out = (data["stdout"] || "").trim()
                if (out)
                    value = JSON.parse(out)
            } catch (e) {
                value = null
            }
            const next = Object.assign({}, root.usage)
            next[app] = value
            root.usage = next
            if (!root.shown.length)
                root.expanded = false
            disconnectSource(source)
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    compactRepresentation: MouseArea {
        readonly property real w: root.shown.length ? row.implicitWidth : 0
        Layout.minimumWidth: w
        Layout.preferredWidth: w
        Layout.maximumWidth: w
        Layout.fillHeight: true
        visible: root.shown.length > 0
        onClicked: root.expanded = !root.expanded

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Kirigami.Units.largeSpacing

            Repeater {
                model: root.shown
                PlasmaComponents.Label {
                    required property string modelData
                    text: root.usage[modelData] ? root.usage[modelData].text : ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Kirigami.Theme.textColor
                    opacity: 0.8
                }
            }
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.preferredHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 2
        collapseMarginsHint: true

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            Repeater {
                model: root.shown
                ColumnLayout {
                    id: app
                    required property string modelData
                    readonly property var info: root.usage[modelData]
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Heading {
                        level: 4
                        text: app.info ? app.info.title : ""
                    }

                    Repeater {
                        model: app.info ? app.info.sections : []
                        ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.topMargin: Kirigami.Units.smallSpacing
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                PlasmaComponents.Label {
                                    text: modelData.title
                                    font.weight: Font.DemiBold
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                PlasmaComponents.Label {
                                    text: modelData.used + "% used"
                                    font.weight: modelData.used >= 80 ? Font.Bold : Font.Normal
                                    opacity: modelData.used >= 80 ? 1 : modelData.used >= 50 ? 0.85 : 0.65
                                }
                            }
                            PlasmaComponents.ProgressBar {
                                Layout.fillWidth: true
                                from: 0
                                to: 100
                                value: modelData.used
                            }
                            PlasmaComponents.Label {
                                text: "Resets " + modelData.resets
                                font: Kirigami.Theme.smallFont
                                opacity: 0.6
                            }
                        }
                    }

                    PlasmaComponents.Label {
                        visible: !!(app.info && app.info.footer)
                        text: app.info ? app.info.footer : ""
                        font: Kirigami.Theme.smallFont
                        opacity: 0.5
                    }
                }
            }
        }
    }
}
