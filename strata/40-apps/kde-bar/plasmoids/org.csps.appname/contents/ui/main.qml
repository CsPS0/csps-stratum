// The focused app's name in bold, as on the Windows menu bar; "Desktop" when no window has focus.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    TaskManager.TasksModel {
        id: tasks
        filterByActivity: true
        filterByVirtualDesktop: true
        filterByScreen: false
        groupMode: TaskManager.TasksModel.GroupDisabled
    }

    // Re-read when the focus moves or the active row's data changes (an app renaming itself).
    property int revision: 0
    Connections {
        target: tasks
        function onActiveTaskChanged() { root.revision++ }
        function onDataChanged() { root.revision++ }
    }
    readonly property string appName: {
        revision;
        const i = tasks.activeTask;
        if (!i || !i.valid)
            return "";
        return tasks.data(i, TaskManager.AbstractTasksModel.AppName) || tasks.data(i, Qt.DisplayRole) || "";
    }

    fullRepresentation: PlasmaComponents.Label {
        id: label

        // Size from the text itself, not from the label (whose implicit width follows the elided
        // text, so it stayed as wide as "Desktop").
        TextMetrics {
            id: metrics
            font: label.font
            text: label.text
        }

        text: root.appName || "Desktop"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        font.bold: true
        color: "#E6E6E6"
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
        Layout.minimumWidth: Math.min(Math.ceil(metrics.advanceWidth), 180)
        Layout.preferredWidth: Layout.minimumWidth
        Layout.maximumWidth: 180
        Layout.fillHeight: true
    }
}
