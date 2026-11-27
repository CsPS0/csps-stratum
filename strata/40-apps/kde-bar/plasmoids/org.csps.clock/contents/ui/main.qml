// "2026-11-28  00:41" in the top bar, the same fixed format as the Windows bar (%Y-%m-%d  %H:%M).
// KDE's own clock follows the locale, and the Hungarian one writes the time as "0:41". Click: KDE's
// month calendar with the same event plugins as KDE's clock (holidays, and Akonadi for Google
// Calendar), and the selected day's events below it.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.workspace.calendar as PlasmaCalendar
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property date now: new Date()

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: Qt.formatDate(now, "yyyy-MM-dd, dddd")
    toolTipSubText: ""

    // Checks every 2 s but only changes the text when the minute changes, so it is right again
    // within 2 s after a suspend.
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            const d = new Date();
            if (d.getMinutes() !== root.now.getMinutes() || d.getHours() !== root.now.getHours() || d.getDate() !== root.now.getDate())
                root.now = d;
        }
    }

    PlasmaCalendar.EventPluginsManager {
        id: plugins
        enabledPlugins: ["holidaysevents", "pimevents"]
    }

    compactRepresentation: MouseArea {
        Layout.minimumWidth: label.implicitWidth + 8
        Layout.preferredWidth: label.implicitWidth + 8
        Layout.fillHeight: true
        onClicked: root.expanded = !root.expanded

        PlasmaComponents.Label {
            id: label
            anchors.centerIn: parent
            text: Qt.formatDateTime(root.now, "yyyy-MM-dd  HH:mm")
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: "#E6E6E6"
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        Layout.preferredHeight: Kirigami.Units.gridUnit * 26
        collapseMarginsHint: true

        // Events of the day picked in the month view.
        PlasmaCalendar.Calendar {
            id: agendaBackend
            days: 7
            weeks: 6
            today: root.now
            Component.onCompleted: daysModel.setPluginsManager(plugins)
        }
        Connections {
            target: agendaBackend.daysModel
            function onAgendaUpdated() { agenda.refresh() }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            PlasmaCalendar.MonthView {
                id: monthView
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 17
                borderOpacity: 0.25
                eventPluginsManager: plugins
                today: root.now
                firstDayOfWeek: 1
                showWeekNumbers: false
                onCurrentDateChanged: {
                    const d = currentDate;
                    agendaBackend.goToYearAndMonth(d.getFullYear(), d.getMonth() + 1);
                    agenda.refresh();
                }
            }

            PlasmaComponents.Label {
                text: Qt.formatDate(monthView.currentDate, "yyyy-MM-dd, dddd")
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: "#E6E6E6"
            }

            ListView {
                id: agenda
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: []

                function refresh() {
                    const d = monthView.currentDate;
                    const day = new Date(d.getFullYear(), d.getMonth(), d.getDate());
                    const evs = (agendaBackend.daysModel.eventsForDate(day) || []).map(e => ({
                        when: e.isAllDay ? "all day" : Qt.formatTime(new Date(e.startDateTime), "HH:mm"),
                        title: e.title,
                        start: new Date(e.startDateTime).getTime(),
                        allDay: e.isAllDay
                    }));
                    evs.sort((a, b) => (b.allDay - a.allDay) || (a.start - b.start));
                    model = evs;
                }

                delegate: PlasmaComponents.Label {
                    required property var modelData
                    width: ListView.view.width
                    elide: Text.ElideRight
                    text: modelData.when + "   " + modelData.title
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: "#B4B6B8"
                }

                PlasmaComponents.Label {
                    visible: agenda.count === 0
                    text: "No events"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: "#8E9194"
                }
            }
        }

        Component.onCompleted: agenda.refresh()
    }
}
