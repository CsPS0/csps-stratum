import QtQuick
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager
import org.kde.plasma.workspace.dbus as DBus

WallpaperItem {
    id: root

    // Like Wallpaper Engine's playback settings: stop animating while a window is maximized on this
    // screen, or fullscreen on any screen. A paused wallpaper keeps its last frame and costs nothing.
    // Show Desktop hides windows without minimising them, so while it is on nothing counts.
    property bool maximizedHere: false
    property bool fullscreenAnywhere: false
    property bool showingDesktop: false
    readonly property bool paused: !showingDesktop
                                   && ((root.configuration.PauseMaximized && maximizedHere)
                                       || (root.configuration.PauseFullscreen && fullscreenAnywhere))
    readonly property var screenGeometry: root.parent?.screenGeometry ?? null

    ShaderEffect {
        id: fx
        anchors.fill: parent

        property real time: 0
        property real style: root.configuration.Style
        property real speed: root.configuration.Speed
        property real size: root.configuration.Size
        property real brightness: root.configuration.Brightness
        property real topdim: root.configuration.TopDim ? 1 : 0
        property real topband: root.configuration.TopBand * Screen.devicePixelRatio
        property vector2d res: Qt.vector2d(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)

        fragmentShader: Qt.resolvedUrl("../shaders/oledspan.frag.qsb")
    }

    // Time only advances while running, so the pattern carries on from where it paused.
    Timer {
        id: clock
        property real last: 0
        interval: Math.round(1000 / Math.max(1, root.configuration.Fps))
        repeat: true
        running: !root.paused && root.configuration.Speed > 0
        onRunningChanged: last = Date.now()
        onTriggered: {
            const now = Date.now();
            fx.time = (fx.time + Math.min(now - last, 1000) / 1000) % 86400;
            last = now;
        }
    }

    // KWin's Show Desktop state: read once, then follow its change signal (the handler name is
    // "dbus" + the signal name).
    DBus.SignalWatcher {
        service: "org.kde.KWin"
        path: "/KWin"
        iface: "org.kde.KWin"
        function dbusshowingDesktopChanged(showing) { root.showingDesktop = showing; }
    }

    function readShowingDesktop() {
        DBus.SessionBus.asyncCall({
            service: "org.kde.KWin",
            path: "/KWin",
            iface: "org.freedesktop.DBus.Properties",
            member: "Get",
            arguments: [new DBus.string("org.kde.KWin"), new DBus.string("showingDesktop")],
        }, function (reply) { root.showingDesktop = reply.value === true; }, function () {});
    }

    TaskManager.VirtualDesktopInfo { id: desktopInfo }
    TaskManager.ActivityInfo { id: activityInfo }

    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        virtualDesktop: desktopInfo.currentDesktop
        activity: activityInfo.currentActivity
        filterByVirtualDesktop: true
        filterByActivity: true
        filterByScreen: false
        filterMinimized: true
        onDataChanged: Qt.callLater(root.checkWindows)
        onCountChanged: Qt.callLater(root.checkWindows)
    }

    function sameRect(a, b) {
        return a && b && a.x === b.x && a.y === b.y && a.width === b.width && a.height === b.height;
    }

    function checkWindows() {
        const roles = TaskManager.AbstractTasksModel;
        let maxed = false, full = false;
        for (let i = 0; i < tasks.count; i++) {
            const idx = tasks.index(i, 0);
            if (!tasks.data(idx, roles.IsWindow) || tasks.data(idx, roles.IsMinimized)) {
                continue;
            }
            if (tasks.data(idx, roles.IsFullScreen)) {
                full = true;
            }
            if (tasks.data(idx, roles.IsMaximized)
                    && (!root.screenGeometry || sameRect(tasks.data(idx, roles.ScreenGeometry), root.screenGeometry))) {
                maxed = true;
            }
        }
        maximizedHere = maxed;
        fullscreenAnywhere = full;
    }

    onScreenGeometryChanged: Qt.callLater(checkWindows)
    Component.onCompleted: {
        fx.time = (Date.now() / 1000) % 86400;
        checkWindows();
        readShowingDesktop();
    }
}
