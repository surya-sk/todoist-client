pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    property var todayTasks: []
    property bool cacheAvailable: false
    property bool todoistConnected: false
    property bool syncing: false
    readonly property color accentColor: Kirigami.Theme.highlightColor
    readonly property color cardColor: Qt.rgba(
        Kirigami.Theme.backgroundColor.r,
        Kirigami.Theme.backgroundColor.g,
        Kirigami.Theme.backgroundColor.b, 0.78)
    readonly property color primaryText: Kirigami.Theme.textColor
    readonly property color secondaryText: Kirigami.Theme.disabledTextColor
    readonly property string cacheCommand:
        "/usr/bin/cat \"$HOME/.local/share/org.suryask.todoist/widget-tasks.json\""
    readonly property string syncCommand:
        "\"$HOME/.local/bin/todoistclient\" --sync-widget"

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

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
        case 3: return Kirigami.Theme.neutralTextColor
        case 2: return root.accentColor
        default: return root.secondaryText
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
        icon.name: "todoist"
        text: root.cacheAvailable ? root.todayTasks.length.toString() : "–"
        display: PlasmaComponents.AbstractButton.TextBesideIcon
        onClicked: root.expanded = !root.expanded
    }

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 16
        Layout.minimumHeight: Kirigami.Units.gridUnit * 10
        Layout.preferredWidth: Kirigami.Units.gridUnit * 24
        Layout.preferredHeight: Kirigami.Units.gridUnit * 18

        Rectangle {
            id: card
            anchors.fill: parent
            anchors.margins: 4
            radius: 24
            color: root.cardColor
            border.width: 1
            border.color: Qt.rgba(root.primaryText.r, root.primaryText.g,
                                  root.primaryText.b, 0.14)

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius - 1
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(root.primaryText.r, root.primaryText.g,
                                      root.primaryText.b, 0.04)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 11
                        color: Qt.rgba(root.accentColor.r, root.accentColor.g,
                                       root.accentColor.b, 0.16)

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            source: "todoist"
                            color: root.accentColor
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: i18n("Today")
                            color: root.primaryText
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                        }

                        PlasmaComponents.Label {
                            text: root.todayTasks.length === 1
                                ? i18n("1 task")
                                : i18n("%1 tasks", root.todayTasks.length)
                            color: root.secondaryText
                            font.pixelSize: 12
                        }
                    }

                    PlasmaComponents.BusyIndicator {
                        visible: root.syncing
                        running: visible
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                    }

                    PlasmaComponents.ToolButton {
                        icon.name: "view-refresh-symbolic"
                        visible: !root.syncing
                        enabled: !root.syncing
                        onClicked: root.syncTasks()
                        PlasmaComponents.ToolTip {
                            text: i18n("Refresh tasks")
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Qt.rgba(root.primaryText.r, root.primaryText.g,
                                   root.primaryText.b, 0.08)
                }

                ListView {
                    id: taskList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4
                    model: root.todayTasks

                    delegate: Item {
                        id: taskDelegate
                        required property var modelData
                        width: ListView.view.width
                        height: Math.max(52, taskContent.implicitHeight + 18)

                        Rectangle {
                            anchors.fill: parent
                            radius: 13
                            color: taskMouse.containsMouse
                                ? Qt.rgba(root.primaryText.r,
                                          root.primaryText.g,
                                          root.primaryText.b, 0.07)
                                : "transparent"
                        }

                        RowLayout {
                            id: taskContent
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 19
                                Layout.preferredHeight: 19
                                radius: width / 2
                                color: "transparent"
                                border.width: 2
                                border.color: root.priorityColor(
                                    taskDelegate.modelData.priority)
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    text: taskDelegate.modelData.content
                                    color: root.primaryText
                                    font.pixelSize: 14
                                    font.weight:
                                        taskDelegate.modelData.priority === 4
                                            ? Font.DemiBold : Font.Normal
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                    elide: Text.ElideRight
                                }

                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    visible: text.length > 0
                                    text: {
                                        const parts = []
                                        if (taskDelegate.modelData.overdue)
                                            parts.push(i18n("Overdue"))
                                        else if (taskDelegate.modelData.due)
                                            parts.push(taskDelegate.modelData.due)
                                        if (taskDelegate.modelData.project)
                                            parts.push(taskDelegate.modelData.project)
                                        return parts.join("  ·  ")
                                    }
                                    color: taskDelegate.modelData.overdue
                                        ? Kirigami.Theme.negativeTextColor
                                        : root.secondaryText
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        MouseArea {
                            id: taskMouse
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        PlasmaComponents.ToolTip {
                            text: taskDelegate.modelData.description.length
                                ? taskDelegate.modelData.description
                                : taskDelegate.modelData.content
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        width: parent.width
                        spacing: 8
                        visible: root.cacheAvailable
                            && root.todoistConnected
                            && root.todayTasks.length === 0

                        Kirigami.Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 32
                            height: 32
                            source: "checkmark"
                            color: root.accentColor
                        }
                        PlasmaComponents.Label {
                            width: parent.width
                            text: i18n("All done for today")
                            horizontalAlignment: Text.AlignHCenter
                            color: root.secondaryText
                            font.pixelSize: 15
                        }
                    }

                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        width: parent.width
                        visible: !root.cacheAvailable || !root.todoistConnected
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: i18n("Open Todoist once to connect and sync.")
                        color: root.secondaryText
                    }
                }
            }
        }
    }
}
