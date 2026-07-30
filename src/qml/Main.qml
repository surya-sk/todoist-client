import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtCore as QtCore
import Qt.labs.platform as Platform
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.dateandtime as DateTime

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
    readonly property real sidebarOpacity:
        Math.max(0.38, 1.0 - appearanceSettings.blurStrength * 0.006)

    QtCore.Settings {
        id: appearanceSettings
        category: "Appearance"
        property int blurStrength: 65
    }

    Platform.MenuBar {
        window: root
        Platform.Menu {
            title: i18nc("@title:menu", "&File")
            Platform.MenuItem {
                text: i18nc("@action:inmenu", "New &Task")
                shortcut: "Ctrl+N"
                enabled: controller.connected
                onTriggered: root.openTask(null)
            }
            Platform.MenuItem {
                text: i18nc("@action:inmenu", "New &Project")
                enabled: controller.connected
                onTriggered: { nameDialog.sectionMode = false; nameDialog.open() }
            }
            Platform.MenuItem {
                text: i18nc("@action:inmenu", "New &Section")
                enabled: controller.connected && controller.projectView
                onTriggered: { nameDialog.sectionMode = true; nameDialog.open() }
            }
            Platform.MenuSeparator {}
            Platform.MenuItem {
                text: i18nc("@action:inmenu", "&Quit")
                shortcut: "Ctrl+Q"
                onTriggered: Qt.quit()
            }
        }
        Platform.Menu {
            title: i18nc("@title:menu", "&View")
            Platform.MenuItem {
                text: i18nc("@action:inmenu", "&Today")
                shortcut: "Ctrl+1"
                onTriggered: controller.selectToday()
            }
            Platform.MenuItem {
                text: i18nc("@action:inmenu", "&Inbox")
                shortcut: "Ctrl+2"
                onTriggered: controller.selectInbox()
            }
            Platform.MenuSeparator {}
            Platform.MenuItem {
                text: i18nc("@action:inmenu", "&Refresh")
                shortcut: "Ctrl+R"
                enabled: controller.connected && !controller.busy
                onTriggered: controller.refresh()
            }
        }
        Platform.Menu {
            title: i18nc("@title:menu", "&Account")
            Platform.MenuItem {
                text: i18nc("@action:inmenu", "Account &Details")
                enabled: controller.connected
                onTriggered: accountDialog.open()
            }
            Platform.MenuItem {
                text: i18nc("@action:inmenu", "&Log Out")
                enabled: controller.connected
                onTriggered: controller.disconnect()
            }
        }
        Platform.Menu {
            title: i18nc("@title:menu", "&Todoist")
            Platform.MenuItem {
                text: i18nc("@action:inmenu", "&Settings…")
                shortcut: "Ctrl+,"
                onTriggered: settingsDialog.open()
            }
        }
    }

    function openTask(task) {
        taskDialog.taskId = task ? task.id : ""
        taskDialog.originalProjectId = task ? task.projectId : ""
        taskDialog.originalSectionId = task ? task.sectionId : ""
        taskTitle.text = task ? task.content : ""
        taskDescription.text = task ? task.description : ""
        taskDialog.hadOriginalDue = Boolean(task && (task.dueDateTime || task.dueDate))
        taskDialog.dueEnabled = taskDialog.hadOriginalDue
        taskDialog.dueTimeEnabled = Boolean(task && task.dueDateTime)
        if (taskDialog.hadOriginalDue) {
            if (task.dueDateTime) {
                taskDialog.selectedDueDate = new Date(task.dueDateTime)
            } else {
                let parts = task.dueDate.slice(0, 10).split("-")
                taskDialog.selectedDueDate = new Date(Number(parts[0]), Number(parts[1]) - 1,
                                                      Number(parts[2]), 9, 0)
            }
        } else {
            let tomorrow = new Date()
            tomorrow.setDate(tomorrow.getDate() + 1)
            tomorrow.setHours(9, 0, 0, 0)
            taskDialog.selectedDueDate = tomorrow
        }
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
        property bool hadOriginalDue: false
        property bool dueEnabled: false
        property bool dueTimeEnabled: false
        property date selectedDueDate: new Date()
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
                Controls.Button {
                    Layout.fillWidth: true
                    text: taskDialog.dueEnabled
                        ? Qt.formatDate(taskDialog.selectedDueDate, Qt.DefaultLocaleShortDate)
                        : i18nc("@action:button", "Add due date")
                    icon.name: "view-calendar-day"
                    onClicked: {
                        dueDatePopup.value = taskDialog.selectedDueDate
                        dueDatePopup.open()
                    }
                }
                Controls.CheckBox {
                    visible: taskDialog.dueEnabled
                    text: i18nc("@option:check", "Time")
                    checked: taskDialog.dueTimeEnabled
                    onToggled: taskDialog.dueTimeEnabled = checked
                }
                Controls.Button {
                    visible: taskDialog.dueEnabled && taskDialog.dueTimeEnabled
                    text: Qt.formatTime(taskDialog.selectedDueDate, Qt.DefaultLocaleShortDate)
                    icon.name: "appointment-new"
                    onClicked: {
                        dueTimePopup.value = taskDialog.selectedDueDate
                        dueTimePopup.open()
                    }
                }
                Controls.ToolButton {
                    visible: taskDialog.dueEnabled
                    icon.name: "edit-clear"
                    onClicked: {
                        taskDialog.dueEnabled = false
                        taskDialog.dueTimeEnabled = false
                    }
                    Controls.ToolTip.text: i18nc("@info:tooltip", "Remove due date")
                    Controls.ToolTip.visible: hovered
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
                        let dueDate = taskDialog.dueEnabled && !taskDialog.dueTimeEnabled
                            ? Qt.formatDate(taskDialog.selectedDueDate, "yyyy-MM-dd") : ""
                        let dueDateTime = taskDialog.dueEnabled && taskDialog.dueTimeEnabled
                            ? taskDialog.selectedDueDate.toISOString() : ""
                        controller.saveTask(taskDialog.taskId, taskTitle.text,
                                            taskDescription.text, dueDate, dueDateTime,
                                            !taskDialog.dueEnabled && taskDialog.hadOriginalDue,
                                            projectId, sectionId, taskPriority.currentIndex + 1,
                                            taskDialog.originalProjectId,
                                            taskDialog.originalSectionId)
                        taskDialog.close()
                    }
                }
            }
        }
    }

    DateTime.DatePopup {
        id: dueDatePopup
        anchors.centerIn: parent
        modal: true
        onAccepted: {
            let updated = new Date(value)
            updated.setHours(taskDialog.selectedDueDate.getHours(),
                             taskDialog.selectedDueDate.getMinutes(), 0, 0)
            taskDialog.selectedDueDate = updated
            taskDialog.dueEnabled = true
        }
    }

    DateTime.TimePopup {
        id: dueTimePopup
        anchors.centerIn: parent
        onAccepted: {
            let updated = new Date(taskDialog.selectedDueDate)
            updated.setHours(value.getHours(), value.getMinutes(), 0, 0)
            taskDialog.selectedDueDate = updated
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

    Controls.Dialog {
        id: accountDialog
        anchors.centerIn: parent
        modal: true
        width: Math.min(440, root.width - 40)
        title: i18nc("@title:dialog", "Todoist account")
        standardButtons: Controls.Dialog.Close
        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 88
                height: 88
                radius: width / 2
                clip: true
                color: Kirigami.Theme.highlightColor
                Controls.Label {
                    anchors.centerIn: parent
                    text: controller.account.name
                          ? controller.account.name.split(/\s+/).map(word => word[0]).join("").slice(0, 2).toUpperCase()
                          : "T"
                    color: Kirigami.Theme.highlightedTextColor
                    font.pixelSize: 28
                    font.weight: Font.DemiBold
                }
                Image {
                    anchors.fill: parent
                    source: controller.account.avatar || ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }
            }
            Controls.Label {
                Layout.alignment: Qt.AlignHCenter
                text: controller.account.name || i18nc("@info", "Todoist account")
                font.pixelSize: 20
                font.weight: Font.DemiBold
            }
            Controls.Label {
                Layout.alignment: Qt.AlignHCenter
                text: controller.account.email || ""
                color: Kirigami.Theme.disabledTextColor
            }
            Controls.Label {
                Layout.alignment: Qt.AlignHCenter
                visible: controller.account.premium === true
                text: i18nc("@info", "Todoist Pro")
                color: Kirigami.Theme.positiveTextColor
            }
            Kirigami.Separator { Layout.fillWidth: true }
            Controls.Button {
                Layout.fillWidth: true
                text: i18nc("@action:button", "Log out")
                icon.name: "system-log-out"
                onClicked: {
                    controller.disconnect()
                    accountDialog.close()
                }
            }
        }
    }

    Controls.Dialog {
        id: settingsDialog
        anchors.centerIn: parent
        modal: true
        width: Math.min(520, root.width - 40)
        title: i18nc("@title:dialog", "Settings")
        standardButtons: Controls.Dialog.Close
        onOpened: {
            for (let i = 0; i < refreshInterval.count; ++i) {
                if (refreshInterval.model[i].minutes
                        === controller.refreshIntervalMinutes) {
                    refreshInterval.currentIndex = i
                    break
                }
            }
        }
        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            Controls.Label {
                text: i18nc("@title:group", "General")
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: settingsColumn.implicitHeight
                                + Kirigami.Units.largeSpacing * 2
                radius: 12
                color: Qt.alpha(Kirigami.Theme.alternateBackgroundColor, 0.72)
                border.color: Qt.alpha(Kirigami.Theme.textColor, 0.08)

                ColumnLayout {
                    id: settingsColumn
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.largeSpacing

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Controls.Label {
                                text: i18nc("@label", "Automatic refresh")
                                font.weight: Font.DemiBold
                            }
                            Controls.Label {
                                text: i18nc("@info", "Keep tasks current in the background")
                                color: Kirigami.Theme.disabledTextColor
                            }
                        }
                        Controls.ComboBox {
                            id: refreshInterval
                            textRole: "label"
                            model: [
                                {"label": i18nc("@item", "Off"), "minutes": 0},
                                {"label": i18nc("@item", "Every minute"), "minutes": 1},
                                {"label": i18nc("@item", "Every 5 minutes"), "minutes": 5},
                                {"label": i18nc("@item", "Every 15 minutes"), "minutes": 15},
                                {"label": i18nc("@item", "Every 30 minutes"), "minutes": 30}
                            ]
                            onActivated: controller.refreshIntervalMinutes =
                                             model[currentIndex].minutes
                        }
                    }

                    Kirigami.Separator { Layout.fillWidth: true }

                    Controls.Switch {
                        Layout.fillWidth: true
                        text: i18nc("@label", "Due-task notifications")
                        checked: controller.notificationsEnabled
                        onToggled: controller.notificationsEnabled = checked
                    }

                    Kirigami.Separator { Layout.fillWidth: true }

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Controls.Label {
                                text: i18nc("@label", "Sidebar blur")
                                font.weight: Font.DemiBold
                            }
                            Controls.Label {
                                text: i18nc("@info", "Adjust the translucent sidebar material")
                                color: Kirigami.Theme.disabledTextColor
                            }
                        }
                        Controls.Slider {
                            from: 0
                            to: 100
                            stepSize: 5
                            value: appearanceSettings.blurStrength
                            onMoved: appearanceSettings.blurStrength = value
                            Layout.preferredWidth: 180
                        }
                    }
                }
            }
        }
    }

    globalDrawer: Kirigami.GlobalDrawer {
        title: i18nc("@title", "Todoist")
        titleIcon: "todoist"
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
            Layout.preferredWidth: 252
            color: Qt.alpha(Kirigami.Theme.alternateBackgroundColor,
                            root.sidebarOpacity)
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing
                RowLayout {
                    Layout.bottomMargin: Kirigami.Units.largeSpacing
                    Kirigami.Icon { source: "todoist"; implicitWidth: 32; implicitHeight: 32 }
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
                    Controls.ToolButton {
                        icon.name: "view-refresh"
                        enabled: controller.connected && !controller.busy
                        onClicked: controller.refresh()
                        Controls.ToolTip.text: i18nc("@info:tooltip", "Refresh tasks")
                        Controls.ToolTip.visible: hovered
                    }
                    Controls.ToolButton {
                        icon.name: "settings-configure"
                        onClicked: settingsDialog.open()
                        Controls.ToolTip.text: i18nc("@info:tooltip", "Settings")
                        Controls.ToolTip.visible: hovered
                    }
                }
                Controls.ItemDelegate {
                    id: todayDelegate
                    Layout.fillWidth: true
                    icon.name: "view-calendar-day"
                    highlighted: controller.selectedTitle === "Today"
                    onClicked: controller.selectToday()
                    background: Rectangle {
                        radius: 9
                        color: todayDelegate.highlighted
                            ? Qt.alpha(Kirigami.Theme.highlightColor, 0.16)
                            : todayDelegate.hovered
                                ? Qt.alpha(Kirigami.Theme.textColor, 0.06)
                                : "transparent"
                    }
                    contentItem: RowLayout {
                        Kirigami.Icon {
                            source: "view-calendar-day"
                            implicitWidth: Kirigami.Units.iconSizes.smallMedium
                            implicitHeight: implicitWidth
                        }
                        Controls.Label {
                            Layout.fillWidth: true
                            text: i18nc("@title", "Today")
                        }
                        Rectangle {
                            visible: controller.todayCount > 0
                            implicitWidth: Math.max(24, badgeText.implicitWidth + 12)
                            implicitHeight: 22
                            radius: implicitHeight / 2
                            color: Kirigami.Theme.highlightColor
                            Controls.Label {
                                id: badgeText
                                anchors.centerIn: parent
                                text: controller.todayCount
                                color: Kirigami.Theme.highlightedTextColor
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }
                        }
                    }
                }
                Controls.ItemDelegate {
                    id: inboxDelegate
                    Layout.fillWidth: true
                    text: i18nc("@title", "Inbox")
                    icon.name: "mail-folder-inbox"
                    highlighted: controller.selectedTitle === "Inbox"
                    onClicked: controller.selectInbox()
                    background: Rectangle {
                        radius: 9
                        color: inboxDelegate.highlighted
                            ? Qt.alpha(Kirigami.Theme.highlightColor, 0.16)
                            : inboxDelegate.hovered
                                ? Qt.alpha(Kirigami.Theme.textColor, 0.06)
                                : "transparent"
                    }
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
                        id: projectDelegate
                        required property var modelData
                        width: ListView.view.width
                        text: modelData.name
                        icon.name: modelData.inbox ? "mail-folder-inbox" : "folder"
                        highlighted: controller.selectedTitle === modelData.name
                        onClicked: controller.selectProject(modelData.id, modelData.name)
                        background: Rectangle {
                            radius: 9
                            color: projectDelegate.highlighted
                                ? Qt.alpha(Kirigami.Theme.highlightColor, 0.16)
                                : projectDelegate.hovered
                                    ? Qt.alpha(Kirigami.Theme.textColor, 0.06)
                                    : "transparent"
                        }
                    }
                }
                Controls.ItemDelegate {
                    Layout.fillWidth: true
                    visible: controller.connected
                    onClicked: accountDialog.open()
                    contentItem: RowLayout {
                        Rectangle {
                            width: 36
                            height: 36
                            radius: width / 2
                            clip: true
                            color: Kirigami.Theme.highlightColor
                            Controls.Label {
                                anchors.centerIn: parent
                                text: controller.account.name
                                      ? controller.account.name.split(/\s+/).map(word => word[0]).join("").slice(0, 2).toUpperCase()
                                      : "T"
                                color: Kirigami.Theme.highlightedTextColor
                                font.weight: Font.DemiBold
                            }
                            Image {
                                anchors.fill: parent
                                source: controller.account.avatar || ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: status === Image.Ready
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Controls.Label {
                                Layout.fillWidth: true
                                text: controller.account.name || i18nc("@info", "Todoist account")
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Controls.Label {
                                Layout.fillWidth: true
                                text: controller.account.email || ""
                                color: Kirigami.Theme.disabledTextColor
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }
                        Kirigami.Icon {
                            source: "go-next"
                            implicitWidth: Kirigami.Units.iconSizes.small
                            implicitHeight: implicitWidth
                        }
                    }
                }
                Controls.Button {
                    Layout.fillWidth: true
                    visible: !controller.connected
                    text: i18nc("@action:button", "Connect Todoist")
                    icon.name: "network-connect"
                    enabled: !controller.busy
                    onClicked: tokenDialog.open()
                }
            }
        }

        Kirigami.Separator {
            Layout.fillHeight: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Kirigami.Theme.backgroundColor
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
                    Controls.BusyIndicator {
                        Layout.alignment: Qt.AlignTop
                        running: controller.busy
                        visible: running
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
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Controls.Button {
                        text: i18nc("@action:button", "Add task")
                        icon.name: "list-add"
                        flat: true
                        enabled: controller.connected
                        onClicked: root.openTask(null)
                    }
                    Controls.Button {
                        visible: controller.projectView
                        text: i18nc("@action:button", "Add section")
                        icon.name: "view-list-tree"
                        flat: true
                        enabled: controller.connected
                        onClicked: { nameDialog.sectionMode = true; nameDialog.open() }
                    }
                    Item { Layout.fillWidth: true }
                }
                Kirigami.Separator { Layout.fillWidth: true }
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
                                id: taskDelegate
                                required property var modelData
                                width: parent.width
                                implicitHeight: Math.max(72, taskRow.implicitHeight + 20)
                                onClicked: root.openTask(modelData)
                                background: Rectangle {
                                    radius: 11
                                    color: taskDelegate.hovered
                                        ? Qt.alpha(Kirigami.Theme.highlightColor, 0.10)
                                        : Qt.alpha(Kirigami.Theme.backgroundColor, 0.64)
                                    border.color: Qt.alpha(
                                                      Kirigami.Theme.textColor, 0.07)
                                }
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
