// The next calendar event beside the clock, with the same rules as the Windows widget
// (strata/40-apps/yasb/calendar/next-event.py): "14:00  Standup", "tomorrow 09:00  ...",
// "Mon 09:00  ...", "12-04 07:30  ..." from a week on, "now  ..." while it runs, today's all-day event if nothing timed is coming.
// Events come from the same calendar plugins as the clock's calendar (pimevents = Akonadi, which
// syncs Google Calendar), so no private calendar link is needed. Hidden when there is none.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.workspace.calendar as PlasmaCalendar

PlasmoidItem {
    id: root

    readonly property int titleMax: 28
    readonly property int lookaheadDays: 30
    property var head: null
    property string tooltip: ""

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    toolTipMainText: "Coming up"
    toolTipSubText: tooltip

    PlasmaCalendar.EventPluginsManager {
        id: plugins
        enabledPlugins: ["pimevents"]
    }

    // Two months, so the lookahead also covers the start of next month.
    PlasmaCalendar.Calendar {
        id: thisMonth
        days: 7
        weeks: 6
        today: new Date()
        Component.onCompleted: daysModel.setPluginsManager(plugins)
    }
    PlasmaCalendar.Calendar {
        id: nextMonth
        days: 7
        weeks: 6
        today: new Date()
        Component.onCompleted: {
            const d = new Date();
            goToYearAndMonth(d.getMonth() === 11 ? d.getFullYear() + 1 : d.getFullYear(), d.getMonth() === 11 ? 1 : d.getMonth() + 2);
            daysModel.setPluginsManager(plugins);
        }
    }

    Connections { target: thisMonth.daysModel; function onAgendaUpdated() { refresh.restart() } }
    Connections { target: nextMonth.daysModel; function onAgendaUpdated() { refresh.restart() } }
    Timer { id: refresh; interval: 500; onTriggered: root.update() }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: { root.followMonth(); root.update() } }

    // plasmashell can run for weeks: move both calendars along when the month changes.
    property int loadedMonth: new Date().getMonth()
    function followMonth() {
        const d = new Date();
        if (d.getMonth() === loadedMonth)
            return;
        loadedMonth = d.getMonth();
        thisMonth.today = d;
        thisMonth.goToYearAndMonth(d.getFullYear(), d.getMonth() + 1);
        nextMonth.today = d;
        nextMonth.goToYearAndMonth(d.getMonth() === 11 ? d.getFullYear() + 1 : d.getFullYear(), d.getMonth() === 11 ? 1 : d.getMonth() + 2);
    }

    function sameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate() }
    function pad(n) { return (n < 10 ? "0" : "") + n }
    function hhmm(d) { return pad(d.getHours()) + ":" + pad(d.getMinutes()) }
    function short(t) { return t.length <= titleMax ? t : t.slice(0, titleMax - 1).trim() + "…" }

    function upcoming() {
        const now = new Date();
        const seen = {};
        const out = [];
        for (let i = 0; i < lookaheadDays; i++) {
            const day = new Date(now.getFullYear(), now.getMonth(), now.getDate() + i);
            for (const model of [thisMonth.daysModel, nextMonth.daysModel]) {
                for (const e of model.eventsForDate(day) || []) {
                    if (e.isMinor)
                        continue;
                    const start = new Date(e.startDateTime);
                    const end = new Date(e.endDateTime);
                    const key = e.title + "|" + start.getTime();
                    // A multi-day event is listed on each of its days; keep it once, on the first.
                    if (seen[key] || (!e.isAllDay && end <= now))
                        continue;
                    seen[key] = true;
                    out.push({ title: e.title, start: e.isAllDay ? day : start, end: end, allDay: e.isAllDay });
                }
            }
        }
        out.sort((a, b) => a.start - b.start || (a.allDay - b.allDay));
        return out;
    }

    function when(e) {
        const now = new Date();
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const days = Math.round((new Date(e.start.getFullYear(), e.start.getMonth(), e.start.getDate()) - today) / 86400000);
        const day = days <= 0 ? "today" : days === 1 ? "tomorrow"
            : days < 7 ? Qt.formatDate(e.start, "ddd") : Qt.formatDate(e.start, "MM-dd");
        if (e.allDay)
            return day;
        if (e.start <= now)
            return "now";
        return days === 0 ? hhmm(e.start) : day + " " + hhmm(e.start);
    }

    function update() {
        const evs = upcoming();
        const now = new Date();
        const timed = evs.filter(e => !e.allDay);
        const todayAllDay = evs.filter(e => e.allDay && sameDay(e.start, now));
        head = timed.length ? timed[0] : (todayAllDay.length ? todayAllDay[0] : (evs.length ? evs[0] : null));
        tooltip = evs.slice(0, 8).map(e => Qt.formatDate(e.start, "yyyy-MM-dd ddd") + (e.allDay ? "  all day" : "  " + hhmm(e.start)) + "   " + e.title).join("\n");
    }

    fullRepresentation: PlasmaComponents.Label {
        visible: root.head !== null
        text: root.head ? root.when(root.head) + "  " + root.short(root.head.title) : ""
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        color: "#A0A3A7"
        verticalAlignment: Text.AlignVCenter
        Layout.preferredWidth: root.head ? implicitWidth : 0
        Layout.fillHeight: true
    }
}
