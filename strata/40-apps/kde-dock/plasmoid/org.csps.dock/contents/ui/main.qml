// Dock for the laptop's bottom panel: KDE's icon-only task manager can't animate, so this is a small
// one built on KDE's public task model (org.kde.taskmanager), matching the Windows dock
// (Windhawk taskbar-dock-animation): icons grow up to maxScale% under the mouse with a smooth
// falloff to their neighbours, launching apps bounce, apps asking for attention (new message) keep
// bouncing until you switch to them, running apps get a dot (wider when active),
// and a thin line divides pinned apps from unpinned ones.
// Left click: launch / activate / minimise. Middle click: new window. Right click: menu.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    // Use the whole panel thickness like KDE's task manager (otherwise the panel adds margins)
    Plasmoid.constraintHints: Plasmoid.CanFillArea

    readonly property real maxScale: Math.max(100, Plasmoid.configuration.maxScale) / 100
    readonly property int dotSpace: 9
    property real hoverX: -1
    property int rev: 0 // bumped on model changes, so the divider is re-checked

    function roleAt(row, role) {
        return tasks.data(tasks.makeModelIndex(row), role);
    }

    // Pinned apps live in the config; follow it, and write it back only when pinning from the menu.
    Connections {
        target: Plasmoid.configuration
        function onLaunchersChanged() {
            if (String(tasks.launcherList) !== String(Plasmoid.configuration.launchers))
                tasks.launcherList = Plasmoid.configuration.launchers;
        }
    }

    function savePins() {
        Plasmoid.configuration.launchers = tasks.launcherList;
    }

    TaskManager.VirtualDesktopInfo { id: desktops }
    TaskManager.ActivityInfo { id: activities }

    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupApplications
        sortMode: TaskManager.TasksModel.SortManual
        separateLaunchers: true
        launchInPlace: true
        hideActivatedLaunchers: true
        filterByVirtualDesktop: true
        filterByActivity: true
        filterByScreen: false
        virtualDesktop: desktops.currentDesktop
        activity: activities.currentActivity

        Component.onCompleted: launcherList = Plasmoid.configuration.launchers
        onDataChanged: root.rev++
        onRowsInserted: root.rev++
        onRowsRemoved: root.rev++
        onRowsMoved: root.rev++
        onModelReset: root.rev++
    }

    fullRepresentation: Item {
        id: dock
        // Leave room above the icon so the hovered one stays inside the panel.
        readonly property int iconSize: Math.max(16, Math.floor((height - root.dotSpace - 2) / root.maxScale))
        readonly property int slot: Math.round(iconSize * 1.3)
        readonly property int dividerGap: Math.round(iconSize * 0.5)
        readonly property real radius: slot * 2.6

        Layout.preferredWidth: row.width
        Layout.minimumWidth: row.width
        Layout.fillHeight: true

        Row {
            id: row
            height: parent.height

            HoverHandler {
                id: hover
                onPointChanged: root.hoverX = hovered ? point.position.x : -1
                onHoveredChanged: if (!hovered) root.hoverX = -1
            }

            Repeater {
                model: tasks

                delegate: Item {
                    id: task
                    required property int index
                    required property var model

                    readonly property bool pinned: model.HasLauncher === true
                    readonly property bool running: model.IsLauncher !== true && model.IsStartup !== true
                    readonly property bool divider: {
                        root.rev;
                        return index > 0 && !pinned
                            && root.roleAt(index - 1, TaskManager.AbstractTasksModel.HasLauncher) === true;
                    }
                    readonly property real centerX: x + width - dock.slot / 2
                    readonly property real dist: root.hoverX < 0 ? 1e9 : Math.abs(root.hoverX - centerX)
                    readonly property real zoom: dist >= dock.radius ? 1
                        : 1 + (root.maxScale - 1) * (Math.cos(Math.PI * dist / dock.radius) + 1) / 2

                    width: dock.slot + (divider ? dock.dividerGap : 0)
                    height: row.height
                    z: zoom

                    function modelIndex() {
                        return tasks.makeModelIndex(index);
                    }

                    // Divider between the last pinned app and the first unpinned one
                    Rectangle {
                        visible: task.divider
                        width: 1
                        height: Math.round(dock.iconSize * 0.7)
                        x: Math.round((dock.dividerGap - 1) / 2)
                        y: Math.round(task.height - root.dotSpace - dock.iconSize + (dock.iconSize - height) / 2)
                        color: Kirigami.Theme.textColor
                        opacity: 0.3
                    }

                    Kirigami.Icon {
                        id: icon
                        source: task.model.decoration
                        width: dock.iconSize
                        height: dock.iconSize
                        x: task.width - dock.slot + (dock.slot - width) / 2
                        y: task.height - root.dotSpace - height
                        transformOrigin: Item.Bottom
                        scale: task.zoom
                        opacity: task.model.IsStartup === true ? 0.6 : 1
                        transform: Translate { id: lift }

                        Behavior on scale {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }
                    }

                    SequentialAnimation {
                        id: bounce
                        loops: 2
                        NumberAnimation { target: lift; property: "y"; to: -dock.iconSize * 0.3; duration: 190; easing.type: Easing.OutQuad }
                        NumberAnimation { target: lift; property: "y"; to: 0; duration: 190; easing.type: Easing.InQuad }
                    }

                    // macOS-style attention bounce: an app asking for attention (a new message, a prompt)
                    // keeps hopping, with a pause between hops, until you switch to it.
                    readonly property bool wantsAttention: model.IsDemandingAttention === true && model.IsActive !== true
                    onWantsAttentionChanged: if (!wantsAttention) lift.y = 0

                    SequentialAnimation {
                        id: attention
                        running: task.wantsAttention && !bounce.running
                        loops: Animation.Infinite
                        NumberAnimation { target: lift; property: "y"; to: -dock.iconSize * 0.45; duration: 230; easing.type: Easing.OutQuad }
                        NumberAnimation { target: lift; property: "y"; to: 0; duration: 230; easing.type: Easing.InQuad }
                        NumberAnimation { target: lift; property: "y"; to: -dock.iconSize * 0.2; duration: 160; easing.type: Easing.OutQuad }
                        NumberAnimation { target: lift; property: "y"; to: 0; duration: 160; easing.type: Easing.InQuad }
                        PauseAnimation { duration: 900 }
                    }

                    // Running indicator: a dot, wider for the active window
                    Rectangle {
                        visible: task.running
                        height: 4
                        width: task.model.IsActive === true ? 12 : 4
                        radius: 2
                        x: icon.x + (icon.width - width) / 2
                        y: task.height - root.dotSpace + 3
                        color: Kirigami.Theme.textColor
                        opacity: task.model.IsActive === true ? 1 : 0.6
                        Behavior on width { NumberAnimation { duration: 150 } }
                    }

                    PlasmaCore.ToolTipArea {
                        anchors.fill: parent
                        mainText: task.model.display || ""
                        location: Plasmoid.location

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.MiddleButton) {
                                    tasks.requestNewInstance(task.modelIndex());
                                    bounce.restart();
                                } else if (mouse.button === Qt.RightButton) {
                                    menu.openRelative();
                                } else if (task.model.IsLauncher === true) {
                                    tasks.requestActivate(task.modelIndex());
                                    bounce.restart();
                                } else if (task.model.IsActive === true) {
                                    tasks.requestToggleMinimized(task.modelIndex());
                                } else {
                                    tasks.requestActivate(task.modelIndex());
                                }
                            }
                        }
                    }

                    PlasmaExtras.Menu {
                        id: menu
                        visualParent: task
                        placement: PlasmaExtras.Menu.TopPosedLeftAlignedPopup

                        PlasmaExtras.MenuItem {
                            text: "New Window"
                            icon: "window-new"
                            onClicked: tasks.requestNewInstance(task.modelIndex())
                        }
                        PlasmaExtras.MenuItem {
                            text: task.pinned ? "Unpin from Dock" : "Pin to Dock"
                            icon: task.pinned ? "window-unpin" : "window-pin"
                            onClicked: {
                                const url = task.model.LauncherUrlWithoutIcon;
                                if (task.pinned)
                                    tasks.requestRemoveLauncher(url);
                                else
                                    tasks.requestAddLauncher(url);
                                root.savePins();
                            }
                        }
                        PlasmaExtras.MenuItem {
                            visible: task.running
                            text: "Close"
                            icon: "window-close"
                            onClicked: tasks.requestClose(task.modelIndex())
                        }
                    }
                }
            }
        }
    }
}
