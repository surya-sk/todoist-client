#include "todoistcontroller.h"

#include <KNotification>
#include <QDate>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonValue>
#include <QNetworkReply>
#include <QSettings>
#include <QTimeZone>
#include <QUuid>

namespace {
const QUrl apiBase(QStringLiteral("https://api.todoist.com/api/v1/"));

QString dueLabel(const QJsonObject &due)
{
    const auto label = due.value(QStringLiteral("string")).toString();
    if (!label.isEmpty()) {
        return label;
    }
    return due.value(QStringLiteral("date")).toString();
}

QVariantMap taskMap(const QJsonObject &object)
{
    const auto due = object.value(QStringLiteral("due")).toObject();
    return {
        {QStringLiteral("id"), object.value(QStringLiteral("id")).toVariant().toString()},
        {QStringLiteral("content"), object.value(QStringLiteral("content")).toString()},
        {QStringLiteral("description"), object.value(QStringLiteral("description")).toString()},
        {QStringLiteral("projectId"), object.value(QStringLiteral("project_id")).toVariant().toString()},
        {QStringLiteral("sectionId"), object.value(QStringLiteral("section_id")).toVariant().toString()},
        {QStringLiteral("priority"), object.value(QStringLiteral("priority")).toInt(1)},
        {QStringLiteral("due"), dueLabel(due)},
        {QStringLiteral("dueDate"), due.value(QStringLiteral("date")).toString()},
        {QStringLiteral("dueDateTime"), due.value(QStringLiteral("datetime")).toString()},
    };
}
}

TodoistController::TodoistController(QObject *parent)
    : QObject(parent)
{
    m_refreshTimer.setInterval(5 * 60 * 1000);
    connect(&m_refreshTimer, &QTimer::timeout, this, &TodoistController::refresh);
    m_reminderTimer.setInterval(60 * 1000);
    connect(&m_reminderTimer, &QTimer::timeout, this, &TodoistController::checkReminders);
    m_reminderTimer.start();

    QTimer::singleShot(0, this, [this] {
        m_token = m_credentials.readToken();
        Q_EMIT connectedChanged();
        if (!m_token.isEmpty()) {
            refresh();
            m_refreshTimer.start();
        }
    });
}

QVariantList TodoistController::projects() const { return m_projects; }
QVariantList TodoistController::sections() const { return m_sections; }
QVariantList TodoistController::tasks() const { return m_tasks; }
QString TodoistController::selectedTitle() const { return m_selectedTitle; }
bool TodoistController::connected() const { return !m_token.isEmpty(); }
bool TodoistController::busy() const { return m_busy; }
QString TodoistController::error() const { return m_error; }
int TodoistController::taskCount() const { return m_tasks.size(); }

void TodoistController::connectToken(const QString &token)
{
    const auto value = token.trimmed();
    if (value.isEmpty()) {
        setError(QStringLiteral("Enter your Todoist API token."));
        return;
    }
    if (!m_credentials.writeToken(value)) {
        setError(m_credentials.lastError().isEmpty()
                     ? QStringLiteral("Could not store the token in KDE Wallet.")
                     : m_credentials.lastError());
        return;
    }
    m_token = value;
    setError({});
    Q_EMIT connectedChanged();
    m_refreshTimer.start();
    refresh();
}

void TodoistController::disconnect()
{
    m_credentials.removeToken();
    m_token.clear();
    m_projects.clear();
    m_sections.clear();
    m_allTasks.clear();
    m_tasks.clear();
    m_refreshTimer.stop();
    Q_EMIT connectedChanged();
    Q_EMIT dataChanged();
}

void TodoistController::selectToday()
{
    m_view = View::Today;
    m_selectedId.clear();
    m_selectedTitle = QStringLiteral("Today");
    rebuildVisibleTasks();
}

void TodoistController::selectInbox()
{
    m_view = View::Inbox;
    m_selectedId.clear();
    m_selectedTitle = QStringLiteral("Inbox");
    rebuildVisibleTasks();
}

void TodoistController::selectProject(const QString &id, const QString &name)
{
    m_view = View::Project;
    m_selectedId = id;
    m_selectedTitle = name;
    rebuildVisibleTasks();
}

void TodoistController::selectSection(const QString &id, const QString &name)
{
    m_view = View::Section;
    m_selectedId = id;
    m_selectedTitle = name;
    rebuildVisibleTasks();
}

void TodoistController::refresh()
{
    if (m_token.isEmpty() || m_busy) {
        return;
    }
    setError({});
    m_projects.clear();
    m_sections.clear();
    m_allTasks.clear();
    requestCollection(QStringLiteral("projects?limit=200"), QStringLiteral("projects"));
    requestCollection(QStringLiteral("sections?limit=200"), QStringLiteral("sections"));
    requestCollection(QStringLiteral("tasks?limit=200"), QStringLiteral("tasks"));
}

QNetworkRequest TodoistController::requestFor(const QString &path) const
{
    QNetworkRequest request(apiBase.resolved(QUrl(path)));
    request.setRawHeader("Authorization", "Bearer " + m_token.toUtf8());
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setRawHeader("X-Request-Id", QUuid::createUuid().toString(QUuid::WithoutBraces).toUtf8());
    return request;
}

void TodoistController::requestCollection(const QString &path, const QString &kind,
                                          const QString &cursor)
{
    QString actualPath = path;
    if (!cursor.isEmpty()) {
        actualPath += QStringLiteral("&cursor=")
            + QString::fromLatin1(QUrl::toPercentEncoding(cursor));
    }
    ++m_pending;
    setBusy(true);
    auto *reply = m_network.get(requestFor(actualPath));
    connect(reply, &QNetworkReply::finished, this, [this, reply, path, kind] {
        const auto status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const auto document = QJsonDocument::fromJson(reply->readAll());
        if (reply->error() != QNetworkReply::NoError) {
            setError(status == 401
                ? QStringLiteral("Todoist rejected this token. Reconnect with a valid token.")
                : reply->errorString());
        } else {
            const auto root = document.object();
            for (const auto &value : root.value(QStringLiteral("results")).toArray()) {
                const auto object = value.toObject();
                if (kind == QLatin1String("tasks")) {
                    m_allTasks.append(taskMap(object));
                } else if (kind == QLatin1String("projects")) {
                    m_projects.append(QVariantMap{
                        {QStringLiteral("id"), object.value(QStringLiteral("id")).toVariant().toString()},
                        {QStringLiteral("name"), object.value(QStringLiteral("name")).toString()},
                        {QStringLiteral("color"), object.value(QStringLiteral("color")).toString()},
                        {QStringLiteral("inbox"), object.value(QStringLiteral("inbox_project")).toBool()},
                    });
                } else {
                    m_sections.append(QVariantMap{
                        {QStringLiteral("id"), object.value(QStringLiteral("id")).toVariant().toString()},
                        {QStringLiteral("name"), object.value(QStringLiteral("name")).toString()},
                        {QStringLiteral("projectId"), object.value(QStringLiteral("project_id")).toVariant().toString()},
                    });
                }
            }
            const auto next = root.value(QStringLiteral("next_cursor")).toString();
            if (!next.isEmpty()) {
                requestCollection(path, kind, next);
            }
        }
        reply->deleteLater();
        if (--m_pending == 0) {
            setBusy(false);
            rebuildVisibleTasks();
            checkReminders();
        }
    });
}

void TodoistController::saveTask(const QString &id, const QString &content,
                                 const QString &description, const QString &dueString,
                                 const QString &projectId, const QString &sectionId,
                                 int priority)
{
    if (content.trimmed().isEmpty()) {
        setError(QStringLiteral("A task needs a title."));
        return;
    }
    QJsonObject body{{QStringLiteral("content"), content.trimmed()},
                     {QStringLiteral("description"), description.trimmed()},
                     {QStringLiteral("priority"), qBound(1, priority, 4)}};
    if (!dueString.trimmed().isEmpty()) {
        body.insert(QStringLiteral("due_string"), dueString.trimmed());
    }
    if (id.isEmpty()) {
        if (!sectionId.isEmpty()) {
            body.insert(QStringLiteral("section_id"), sectionId);
        } else if (!projectId.isEmpty()) {
            body.insert(QStringLiteral("project_id"), projectId);
        }
        mutate(QStringLiteral("POST"), QStringLiteral("tasks"), body);
    } else {
        mutate(QStringLiteral("POST"), QStringLiteral("tasks/") + id, body);
    }
}

void TodoistController::completeTask(const QString &id)
{
    mutate(QStringLiteral("POST"), QStringLiteral("tasks/") + id + QStringLiteral("/close"));
}

void TodoistController::deleteTask(const QString &id)
{
    mutate(QStringLiteral("DELETE"), QStringLiteral("tasks/") + id);
}

void TodoistController::createProject(const QString &name)
{
    if (!name.trimmed().isEmpty()) {
        mutate(QStringLiteral("POST"), QStringLiteral("projects"),
               {{QStringLiteral("name"), name.trimmed()}});
    }
}

void TodoistController::createSection(const QString &name, const QString &projectId)
{
    if (!name.trimmed().isEmpty() && !projectId.isEmpty()) {
        mutate(QStringLiteral("POST"), QStringLiteral("sections"),
               {{QStringLiteral("name"), name.trimmed()},
                {QStringLiteral("project_id"), projectId}});
    }
}

void TodoistController::mutate(const QString &method, const QString &path,
                               const QJsonObject &body, bool refreshAfter)
{
    setBusy(true);
    const auto payload = QJsonDocument(body).toJson(QJsonDocument::Compact);
    auto *reply = m_network.sendCustomRequest(requestFor(path), method.toUtf8(), payload);
    connect(reply, &QNetworkReply::finished, this, [this, reply, refreshAfter] {
        const auto status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (reply->error() != QNetworkReply::NoError && status != 204) {
            const auto object = QJsonDocument::fromJson(reply->readAll()).object();
            setError(object.value(QStringLiteral("error")).toString(reply->errorString()));
            setBusy(false);
        } else if (refreshAfter) {
            setBusy(false);
            refresh();
        } else {
            setBusy(false);
        }
        reply->deleteLater();
    });
}

void TodoistController::rebuildVisibleTasks()
{
    m_tasks.clear();
    const auto today = QDate::currentDate();
    for (const auto &value : std::as_const(m_allTasks)) {
        auto task = value.toMap();
        const auto projectId = task.value(QStringLiteral("projectId")).toString();
        const auto sectionId = task.value(QStringLiteral("sectionId")).toString();
        const auto due = QDate::fromString(task.value(QStringLiteral("dueDate")).toString().left(10), Qt::ISODate);
        bool include = false;
        switch (m_view) {
        case View::Today: include = due.isValid() && due <= today; break;
        case View::Inbox:
            for (const auto &project : std::as_const(m_projects)) {
                const auto p = project.toMap();
                if (p.value(QStringLiteral("inbox")).toBool()
                    && p.value(QStringLiteral("id")).toString() == projectId) {
                    include = true;
                    break;
                }
            }
            break;
        case View::Project: include = projectId == m_selectedId; break;
        case View::Section: include = sectionId == m_selectedId; break;
        }
        if (include) {
            task.insert(QStringLiteral("project"), projectName(projectId));
            task.insert(QStringLiteral("section"), sectionName(sectionId));
            m_tasks.append(task);
        }
    }
    Q_EMIT dataChanged();
}

QString TodoistController::projectName(const QString &id) const
{
    for (const auto &value : m_projects) {
        const auto item = value.toMap();
        if (item.value(QStringLiteral("id")).toString() == id) {
            return item.value(QStringLiteral("name")).toString();
        }
    }
    return {};
}

QString TodoistController::sectionName(const QString &id) const
{
    for (const auto &value : m_sections) {
        const auto item = value.toMap();
        if (item.value(QStringLiteral("id")).toString() == id) {
            return item.value(QStringLiteral("name")).toString();
        }
    }
    return {};
}

void TodoistController::checkReminders()
{
    const auto now = QDateTime::currentDateTime();
    QSettings settings;
    for (const auto &value : std::as_const(m_allTasks)) {
        const auto task = value.toMap();
        auto due = QDateTime::fromString(task.value(QStringLiteral("dueDateTime")).toString(), Qt::ISODate);
        if (!due.isValid()) {
            continue;
        }
        if (due.timeZone().isValid()) {
            due = due.toLocalTime();
        }
        const auto seconds = now.secsTo(due);
        const auto key = QStringLiteral("reminders/") + task.value(QStringLiteral("id")).toString()
            + QLatin1Char('/') + due.toString(Qt::ISODate);
        if (seconds >= 0 && seconds <= 15 * 60 && !settings.value(key).toBool()) {
            auto *notification = new KNotification(QStringLiteral("task-reminder"),
                                                   KNotification::CloseOnTimeout, this);
            notification->setTitle(QStringLiteral("Task due soon"));
            notification->setText(task.value(QStringLiteral("content")).toString()
                                  + QStringLiteral("\nDue ") + due.toString(QStringLiteral("h:mm AP")));
            notification->setIconName(QStringLiteral("checkbox"));
            notification->sendEvent();
            settings.setValue(key, true);
        }
    }
}

void TodoistController::setBusy(bool busy)
{
    if (m_busy != busy) {
        m_busy = busy;
        Q_EMIT busyChanged();
    }
}

void TodoistController::setError(const QString &error)
{
    if (m_error != error) {
        m_error = error;
        Q_EMIT errorChanged();
    }
}

void TodoistController::clearError()
{
    setError({});
}
