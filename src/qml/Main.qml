import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root
    required property var controller
    width: 1180
    height: 780
    minimumWidth: 820
    minimumHeight: 560
    visible: true
    title: i18nc("@title:window", "Todoist")
    color: "transparent"

    function openTask(task) {
        taskDialog.taskId = task ? task.id : ""
        taskDialog.originalProjectId = task ? task.projectId : ""
        taskDialog.originalSectionId = task ? task.sectionId : ""
        taskTitle.text = task ? task.content : ""
        taskDescription.text = task ? task.description : ""
        taskDue.text = task ? task.due : ""
        taskPriority.currentIndex = task ? Math.max(0, task.priority - 1) : 0
        taskProject.currentIndex = -1
        taskSection.currentIndex = 0
        if (task) {
            for (let i = 0; i < controller.projects.length; ++i)
                if (controller.projects[i].id === task.projectId)
                    taskProject.currentIndex = i
            let availableSections = controller.sectionsForProject(task.projectId)
            for (let i = 0; i < availableSections.length; ++i)
                if (availableSections[i].id === task.sectionId)
                    taskSection.currentIndex = i + 1
        } else if (controller.projectView) {
            for (let i = 0; i < controller.projects.length; ++i)
                if (controller.projects[i].id === controller.selectedProjectId)
                    taskProject.currentIndex = i
        } else {
            for (let i = 0; i < controller.projects.length; ++i)
                if (controller.projects[i].inbox)
                    taskProject.currentIndex = i
        }
        taskDialog.open()
        taskTitle.forceActiveFocus()
    }

    Controls.Dialog {
        id: tokenDialog
        anchors.centerIn: parent
        modal: true
        width: Math.min(520, root.width - 40)
        title: i18nc("@title:dialog", "Connect Todoist")
        standardButtons: Controls.Dialog.Cancel
        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing
            Controls.Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: i18nc("@info", "Paste your token from Todoist Settings → Integrations → Developer. It will be kept in KDE Wallet.")
            }
            Controls.TextField {
                id: tokenField
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: i18nc("@info:placeholder", "API token")
                onAccepted: connectButton.clicked()
            }
            Controls.Button {
                id: connectButton
                Layout.alignment: Qt.AlignRight
                text: i18nc("@action:button", "Connect")
                highlighted: true
                onClicked: {
                    controller.connectToken(tokenField.text)
                    if (controller.connected) tokenDialog.close()
                }
            }
        }
    }

    Controls.Dialog {
        id: taskDialog
        property string taskId: ""
        property string originalProjectId: ""
        property string originalSectionId: ""
        anchors.centerIn: parent
        modal: true
        width: Math.min(620, root.width - 40)
        title: taskId ? i18nc("@title:dialog", "Edit task") : i18nc("@title:dialog", "New task")
        standardButtons: Controls.Dialog.Cancel
        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing
            Controls.TextField {
                id: taskTitle
                Layout.fillWidth: true
                placeholderText: i18nc("@info:placeholder", "Task name")
                font.pixelSize: 18
            }
            Controls.TextArea {
                id: taskDescription
                Layout.fillWidth: true
                Layout.preferredHeight: 90
                placeholderText: i18nc("@info:placeholder", "Description")
                wrapMode: TextEdit.Wrap
            }
            RowLayout {
                Layout.fillWidth: true
                Controls.TextField {
                    id: taskDue
                    Layout.fillWidth: true
                    placeholderText: i18nc("@info:placeholder", "Due date (tomorrow at 5pm)")
                }
                Controls.ComboBox {
                    id: taskPriority
                    model: [i18nc("@item", "Normal"), i18nc("@item", "Medium"),
                            i18nc("@item", "High"), i18nc("@item", "Urgent")]
                }
            }
            Controls.ComboBox {
                id: taskProject
                Layout.fillWidth: true
                model: controller.projects
                textRole: "name"
                valueRole: "id"
                onCurrentValueChanged: taskSection.currentIndex = 0
            }
            Controls.ComboBox {
                id: taskSection
                Layout.fillWidth: true
                model: [{ "id": "", "name": i18nc("@item", "No section") }].concat(
                           taskProject.currentValue
                           ? controller.sectionsForProject(taskProject.currentValue) : [])
                textRole: "name"
                valueRole: "id"
            }
            RowLayout {
                Layout.fillWidth: true
                Controls.Button {
                    visible: taskDialog.taskId.length > 0
                    text: i18nc("@action:button", "Delete")
                    icon.name: "edit-delete"
                    onClicked: {
                        controller.deleteTask(taskDialog.taskId)
                        taskDialog.close()
                    }
                }
                Item { Layout.fillWidth: true }
                Controls.Button {
                    text: taskDialog.taskId ? i18nc("@action:button", "Save") : i18nc("@action:button", "Add task")
                    highlighted: true
                    enabled: taskTitle.text.trim().length > 0
                    onClicked: {
                        let projectId = taskProject.currentValue
                        let sectionId = taskSection.currentValue
                        controller.saveTask(taskDialog.taskId, taskTitle.text,
                                            taskDescription.text, taskDue.text,
                                            projectId, sectionId, taskPriority.currentIndex + 1,
                                            taskDialog.originalProjectId,
                                            taskDialog.originalSectionId)
                        taskDialog.close()
                    }
                }
            }
        }
    }

    Controls.Dialog {
        id: nameDialog
        property bool sectionMode: false
        anchors.centerIn: parent
        modal: true
        width: Math.min(440, root.width - 40)
        title: sectionMode ? i18nc("@title:dialog", "New section") : i18nc("@title:dialog", "New project")
        standardButtons: Controls.Dialog.Cancel
        onOpened: { newName.clear(); newName.forceActiveFocus() }
        contentItem: ColumnLayout {
            Controls.TextField {
                id: newName
                Layout.fillWidth: true
                placeholderText: nameDialog.sectionMode ? i18nc("@info:placeholder", "Section name") : i18nc("@info:placeholder", "Project name")
            }
            Controls.Button {
                Layout.alignment: Qt.AlignRight
                text: i18nc("@action:button", "Create")
                highlighted: true
                enabled: newName.text.trim().length > 0
                onClicked: {
                    if (nameDialog.sectionMode)
                        controller.createSection(newName.text, controller.selectedProjectId)
                    else
                        controller.createProject(newName.text)
                    nameDialog.close()
                }
            }
        }
    }

    Controls.Dialog {
        id: deleteSectionDialog
        property string sectionId: ""
        property string sectionName: ""
        anchors.centerIn: parent
        modal: true
        width: Math.min(480, root.width - 40)
        title: i18nc("@title:dialog", "Delete section?")
        standardButtons: Controls.Dialog.Cancel
        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing
            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: true
                type: Kirigami.MessageType.Warning
                text: i18nc("@info", "Deleting “%1” also permanently deletes every task in it.", deleteSectionDialog.sectionName)
            }
            Controls.Button {
                Layout.alignment: Qt.AlignRight
                text: i18nc("@action:button", "Delete section")
                icon.name: "edit-delete"
                onClicked: {
                    controller.deleteSection(deleteSectionDialog.sectionId)
                    deleteSectionDialog.close()
                }
            }
        }
    }

    globalDrawer: Kirigami.GlobalDrawer {
        title: i18nc("@title", "Todoist")
        titleIcon: "checkbox"
        isMenu: true
        actions: [
            Kirigami.Action {
                text: i18nc("@action", "New task")
                icon.name: "list-add"
                enabled: controller.connected
                onTriggered: root.openTask(null)
            },
            Kirigami.Action {
                text: i18nc("@action", "New project")
                icon.name: "folder-new"
                enabled: controller.connected
                onTriggered: { nameDialog.sectionMode = false; nameDialog.open() }
            },
            Kirigami.Action {
                text: i18nc("@action", "New section")
                icon.name: "view-list-tree"
                enabled: controller.connected && controller.projectView
                onTriggered: { nameDialog.sectionMode = true; nameDialog.open() }
            },
            Kirigami.Action {
                text: i18nc("@action", "Refresh")
                icon.name: "view-refresh"
                enabled: controller.connected && !controller.busy
                onTriggered: controller.refresh()
            },
            Kirigami.Action {
                text: controller.connected ? i18nc("@action", "Disconnect") : i18nc("@action", "Connect Todoist")
                icon.name: controller.connected ? "network-disconnect" : "network-connect"
                onTriggered: controller.connected ? controller.disconnect() : tokenDialog.open()
            }
        ]
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 270
            color: Qt.alpha(Kirigami.Theme.alternateBackgroundColor, 0.88)
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing
                RowLayout {
                    Layout.bottomMargin: Kirigami.Units.largeSpacing
                    Kirigami.Icon { source: "checkbox"; implicitWidth: 32; implicitHeight: 32 }
                    Controls.Label {
                        text: i18nc("@title", "Todoist")
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                    }
                    Controls.ToolButton {
                        icon.name: "list-add"
                        enabled: controller.connected
                        onClicked: root.openTask(null)
                        Controls.ToolTip.text: i18nc("@info:tooltip", "Add task")
                        Controls.ToolTip.visible: hovered
                    }
                }
                Controls.ItemDelegate {
                    Layout.fillWidth: true
                    text: i18nc("@title", "Today")
                    icon.name: "view-calendar-day"
                    highlighted: controller.selectedTitle === "Today"
                    onClicked: controller.selectToday()
                }
                Controls.ItemDelegate {
                    Layout.fillWidth: true
                    text: i18nc("@title", "Inbox")
                    icon.name: "mail-folder-inbox"
                    highlighted: controller.selectedTitle === "Inbox"
                    onClicked: controller.selectInbox()
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.largeSpacing
                    Controls.Label {
                        text: i18nc("@title:group", "PROJECTS")
                        color: Kirigami.Theme.disabledTextColor
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                    }
                    Controls.ToolButton {
                        icon.name: "list-add"
                        onClicked: { nameDialog.sectionMode = false; nameDialog.open() }
                    }
                }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: controller.projects
                    delegate: Controls.ItemDelegate {
                        required property var modelData
                        width: ListView.view.width
                        text: modelData.name
                        icon.name: modelData.inbox ? "mail-folder-inbox" : "folder"
                        highlighted: controller.selectedTitle === modelData.name
                        onClicked: controller.selectProject(modelData.id, modelData.name)
                    }
                }
                Controls.Button {
                    Layout.fillWidth: true
                    text: controller.connected ? i18nc("@action:button", "Refresh") : i18nc("@action:button", "Connect Todoist")
                    icon.name: controller.connected ? "view-refresh" : "network-connect"
                    enabled: !controller.busy
                    onClicked: controller.connected ? controller.refresh() : tokenDialog.open()
                }
            }
        }

        Kirigami.Separator { Layout.fillHeight: true }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.94)
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.gridUnit * 2
                spacing: Kirigami.Units.largeSpacing
                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Controls.Label {
                            text: controller.selectedTitle
                            font.pixelSize: 28
                            font.weight: Font.Bold
                        }
                        Controls.Label {
                            text: i18ncp("@info", "%1 open task", "%1 open tasks", controller.taskCount)
                            color: Kirigami.Theme.disabledTextColor
                        }
                    }
                    Controls.BusyIndicator { running: controller.busy; visible: running }
                    Controls.Button {
                        visible: controller.projectView
                        text: i18nc("@action:button", "Add section")
                        icon.name: "view-list-tree"
                        enabled: controller.connected
                        onClicked: { nameDialog.sectionMode = true; nameDialog.open() }
                    }
                    Controls.Button {
                        text: i18nc("@action:button", "Add task")
                        icon.name: "list-add"
                        highlighted: true
                        enabled: controller.connected
                        onClicked: root.openTask(null)
                    }
                }
                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    visible: controller.error.length > 0
                    text: controller.error
                    type: Kirigami.MessageType.Error
                    showCloseButton: true
                    onVisibleChanged: if (!visible) controller.clearError()
                }
                Kirigami.PlaceholderMessage {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: !controller.busy && controller.taskGroups.length === 0
                    icon.name: controller.connected ? "checkmark" : "network-disconnect"
                    text: controller.connected ? i18nc("@info", "All clear") : i18nc("@info", "Connect Todoist to see your tasks")
                    helpfulAction: Kirigami.Action {
                        visible: !controller.connected
                        text: i18nc("@action:button", "Connect")
                        onTriggered: tokenDialog.open()
                    }
                }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: controller.taskGroups.length > 0
                    spacing: Kirigami.Units.largeSpacing
                    clip: true
                    model: controller.taskGroups
                    delegate: Column {
                        required property var modelData
                        width: ListView.view.width
                        spacing: Kirigami.Units.smallSpacing
                        RowLayout {
                            width: parent.width
                            visible: modelData.name.length > 0
                            Controls.Label {
                                Layout.fillWidth: true
                                text: modelData.name
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                            }
                            Controls.ToolButton {
                                icon.name: "list-add"
                                onClicked: {
                                    root.openTask(null)
                                    for (let i = 0; i < taskSection.count; ++i)
                                        if (taskSection.model[i].id === modelData.id)
                                            taskSection.currentIndex = i
                                }
                                Controls.ToolTip.text: i18nc("@info:tooltip", "Add task to section")
                                Controls.ToolTip.visible: hovered
                            }
                            Controls.ToolButton {
                                icon.name: "edit-delete"
                                onClicked: {
                                    deleteSectionDialog.sectionId = modelData.id
                                    deleteSectionDialog.sectionName = modelData.name
                                    deleteSectionDialog.open()
                                }
                                Controls.ToolTip.text: i18nc("@info:tooltip", "Delete section")
                                Controls.ToolTip.visible: hovered
                            }
                        }
                        Repeater {
                            model: modelData.tasks
                            delegate: Controls.ItemDelegate {
                                required property var modelData
                                width: parent.width
                                implicitHeight: Math.max(72, taskRow.implicitHeight + 20)
                                onClicked: root.openTask(modelData)
                                contentItem: RowLayout {
                                    id: taskRow
                                    spacing: Kirigami.Units.largeSpacing
                                    Controls.CheckBox {
                                        onClicked: controller.completeTask(modelData.id)
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 3
                                        Controls.Label {
                                            Layout.fillWidth: true
                                            text: modelData.content
                                            font.weight: Font.DemiBold
                                            wrapMode: Text.Wrap
                                        }
                                        Controls.Label {
                                            Layout.fillWidth: true
                                            visible: modelData.description.length > 0
                                            text: modelData.description
                                            color: Kirigami.Theme.disabledTextColor
                                            elide: Text.ElideRight
                                        }
                                        Controls.Label {
                                            text: [modelData.project, modelData.due].filter(Boolean).join("  ·  ")
                                            color: modelData.dueDate && modelData.dueDate.slice(0, 10) <= Qt.formatDate(new Date(), "yyyy-MM-dd")
                                                   ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor
                                            font.pixelSize: 11
                                        }
                                    }
                                    Kirigami.Icon {
                                        visible: modelData.priority > 1
                                        source: "flag"
                                        color: modelData.priority === 4 ? Kirigami.Theme.negativeTextColor
                                              : modelData.priority === 3 ? Kirigami.Theme.neutralTextColor
                                              : Kirigami.Theme.highlightColor
                                    }
                                }
                            }
                        }
                        Controls.Button {
                            visible: modelData.name.length > 0 && modelData.tasks.length === 0
                            text: i18nc("@action:button", "Add task")
                            icon.name: "list-add"
                            flat: true
                            onClicked: {
                                root.openTask(null)
                                for (let i = 0; i < taskSection.count; ++i)
                                    if (taskSection.model[i].id === modelData.id)
                                        taskSection.currentIndex = i
                            }
                        }
                    }
                }
            }
        }
    }
}
