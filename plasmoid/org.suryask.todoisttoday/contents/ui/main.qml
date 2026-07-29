pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    property var todayTasks: []
    property bool cacheAvailable: false
    property bool todoistConnected: false
    property bool syncing: false
    readonly property string cacheCommand:
        "/usr/bin/cat /home/surya/.local/share/org.suryask.todoist/widget-tasks.json"
    readonly property string syncCommand:
        "/home/surya/.local/bin/todoistclient --sync-widget"

    function readCache() {
        cacheReader.disconnectSource(cacheCommand)
        cacheReader.connectSource(cacheCommand)
    }

    function syncTasks() {
        if (syncing)
            return
        syncing = true
        taskSync.disconnectSource(syncCommand)
        taskSync.connectSource(syncCommand)
    }

    function applyCache(text) {
        try {
            const payload = JSON.parse(text)
            todayTasks = payload.tasks || []
            todoistConnected = payload.connected || false
            cacheAvailable = true
        } catch (error) {
            cacheAvailable = false
        }
    }

    function priorityColor(priority) {
        switch (priority) {
        case 4: return Kirigami.Theme.negativeTextColor
        case 3: return "#e99545"
        case 2: return "#4f9cf9"
        default: return Kirigami.Theme.disabledTextColor
        }
    }

    Plasma5Support.DataSource {
        id: cacheReader
        engine: "executable"
        onNewData: (sourceName, data) => {
            cacheReader.disconnectSource(sourceName)
            if (data.stdout !== undefined && data.stdout.length > 0)
                root.applyCache(data.stdout)
            else
                root.cacheAvailable = false
        }
    }

    Plasma5Support.DataSource {
        id: taskSync
        engine: "executable"
        onNewData: (sourceName, data) => {
            taskSync.disconnectSource(sourceName)
            root.syncing = false
            root.readCache()
        }
    }

    Timer {
        interval: 5 * 60 * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.syncTasks()
    }

    preferredRepresentation: fullRepresentation

    compactRepresentation: PlasmaComponents.ToolButton {
        icon.name: "view-task"
        text: root.cacheAvailable ? root.todayTasks.length.toString() : "–"
        display: PlasmaComponents.AbstractButton.TextBesideIcon
        onClicked: root.expanded = !root.expanded
        Accessible.name: i18n("Open today's Todoist tasks")
    }

    fullRepresentation: PlasmaExtras.Representation {
        collapseMarginsHint: true
        Layout.minimumWidth: Kirigami.Units.gridUnit * 9
        Layout.minimumHeight: Kirigami.Units.gridUnit * 7
        Layout.preferredWidth: Kirigami.Units.gridUnit * 19
        Layout.preferredHeight: Kirigami.Units.gridUnit * 24

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            PlasmaExtras.PlasmoidHeading {
                Layout.fillWidth: true
                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing
                    Kirigami.Icon {
                        source: "view-task"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Layout.preferredWidth
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Kirigami.Heading {
                            Layout.fillWidth: true
                            level: 2
                            text: i18n("Today")
                            elide: Text.ElideRight
                        }
                        PlasmaComponents.Label {
                            text: root.todayTasks.length === 1
                                ? i18n("1 task")
                                : i18n("%1 tasks", root.todayTasks.length)
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        }
                    }
                    PlasmaComponents.ToolButton {
                        icon.name: "view-refresh"
                        Accessible.name: i18n("Reload tasks")
                        enabled: !root.syncing
                        onClicked: root.syncTasks()
                    }
                    PlasmaComponents.BusyIndicator {
                        visible: root.syncing
                        running: visible
                    }
                }
            }

            ListView {
                id: taskList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Kirigami.Units.smallSpacing
                model: root.todayTasks

                delegate: PlasmaComponents.ItemDelegate {
                    id: taskDelegate
                    required property var modelData
                    width: ListView.view.width
                    implicitHeight: Math.max(
                        Kirigami.Units.gridUnit * 3,
                        contentRow.implicitHeight + Kirigami.Units.largeSpacing * 2)

                    contentItem: RowLayout {
                        id: contentRow
                        spacing: Kirigami.Units.largeSpacing
                        Rectangle {
                            Layout.preferredWidth: Kirigami.Units.gridUnit
                            Layout.preferredHeight: Layout.preferredWidth
                            radius: width / 2
                            color: "transparent"
                            border.width: 2
                            border.color: root.priorityColor(
                                taskDelegate.modelData.priority)
                            Rectangle {
                                anchors.centerIn: parent
                                width: 4
                                height: 4
                                radius: 2
                                visible: taskDelegate.modelData.priority > 1
                                color: parent.border.color
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: taskDelegate.modelData.content
                                font.bold: taskDelegate.modelData.priority === 4
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: {
                                    const parts = []
                                    if (taskDelegate.modelData.overdue)
                                        parts.push(i18n("Overdue"))
                                    if (taskDelegate.modelData.due)
                                        parts.push(taskDelegate.modelData.due)
                                    if (taskDelegate.modelData.project)
                                        parts.push(taskDelegate.modelData.project)
                                    return parts.join(" · ")
                                }
                                color: taskDelegate.modelData.overdue
                                    ? Kirigami.Theme.negativeTextColor
                                    : Kirigami.Theme.disabledTextColor
                                font.pixelSize:
                                    Kirigami.Theme.smallFont.pixelSize
                                elide: Text.ElideRight
                            }
                        }
                    }
                    PlasmaComponents.ToolTip {
                        text: taskDelegate.modelData.description.length
                            ? taskDelegate.modelData.description
                            : taskDelegate.modelData.content
                    }
                }

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    visible: root.cacheAvailable
                             && root.todoistConnected
                             && root.todayTasks.length === 0
                    text: i18n("All done for today")
                    color: Kirigami.Theme.disabledTextColor
                }
                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    visible: !root.cacheAvailable || !root.todoistConnected
                    width: Math.min(parent.width - Kirigami.Units.gridUnit * 3,
                                    implicitWidth)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: i18n("Open Todoist once to connect and sync your tasks.")
                    color: Kirigami.Theme.disabledTextColor
                }
            }
        }
    }
}
