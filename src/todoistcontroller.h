#pragma once

#include "credentialstore.h"

#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QObject>
#include <QTimer>
#include <QVariantList>

#include <functional>

class TodoistController final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList projects READ projects NOTIFY dataChanged)
    Q_PROPERTY(QVariantList sections READ sections NOTIFY dataChanged)
    Q_PROPERTY(QVariantList tasks READ tasks NOTIFY dataChanged)
    Q_PROPERTY(QVariantList taskGroups READ taskGroups NOTIFY dataChanged)
    Q_PROPERTY(QVariantMap account READ account NOTIFY accountChanged)
    Q_PROPERTY(int todayCount READ todayCount NOTIFY dataChanged)
    Q_PROPERTY(QString selectedTitle READ selectedTitle NOTIFY dataChanged)
    Q_PROPERTY(QString selectedProjectId READ selectedProjectId NOTIFY dataChanged)
    Q_PROPERTY(bool projectView READ projectView NOTIFY dataChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(int taskCount READ taskCount NOTIFY dataChanged)
    Q_PROPERTY(int refreshIntervalMinutes READ refreshIntervalMinutes
                   WRITE setRefreshIntervalMinutes NOTIFY settingsChanged)
    Q_PROPERTY(bool notificationsEnabled READ notificationsEnabled
                   WRITE setNotificationsEnabled NOTIFY settingsChanged)

public:
    explicit TodoistController(QObject *parent = nullptr);
    QVariantList projects() const;
    QVariantList sections() const;
    QVariantList tasks() const;
    QVariantList taskGroups() const;
    QVariantMap account() const;
    int todayCount() const;
    QString selectedTitle() const;
    QString selectedProjectId() const;
    bool projectView() const;
    bool connected() const;
    bool busy() const;
    QString error() const;
    int taskCount() const;
    int refreshIntervalMinutes() const;
    bool notificationsEnabled() const;
    void setRefreshIntervalMinutes(int minutes);
    void setNotificationsEnabled(bool enabled);

    Q_INVOKABLE void connectToken(const QString &token);
    Q_INVOKABLE void disconnect();
    Q_INVOKABLE void selectToday();
    Q_INVOKABLE void selectInbox();
    Q_INVOKABLE void selectProject(const QString &id, const QString &name);
    Q_INVOKABLE void selectSection(const QString &id, const QString &name);
    Q_INVOKABLE QVariantList sectionsForProject(const QString &projectId) const;
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void saveTask(const QString &id, const QString &content,
                              const QString &description, const QString &dueString,
                              const QString &projectId, const QString &sectionId,
                              int priority, const QString &originalProjectId = {},
                              const QString &originalSectionId = {});
    Q_INVOKABLE void completeTask(const QString &id);
    Q_INVOKABLE void deleteTask(const QString &id);
    Q_INVOKABLE void createProject(const QString &name);
    Q_INVOKABLE void createSection(const QString &name, const QString &projectId);
    Q_INVOKABLE void deleteSection(const QString &id);
    Q_INVOKABLE void clearError();

Q_SIGNALS:
    void dataChanged();
    void connectedChanged();
    void busyChanged();
    void errorChanged();
    void accountChanged();
    void settingsChanged();

private:
    enum class View { Today, Inbox, Project, Section };
    void requestCollection(const QString &path, const QString &kind,
                           const QString &cursor = {});
    void requestUser();
    void mutate(const QString &method, const QString &path,
                const QJsonObject &body = {}, bool refreshAfter = true,
                std::function<void()> success = {});
    QNetworkRequest requestFor(const QString &path) const;
    void setBusy(bool busy);
    void setError(const QString &error);
    void rebuildVisibleTasks();
    void writeWidgetTaskCache() const;
    void checkReminders();
    QString projectName(const QString &id) const;
    QString sectionName(const QString &id) const;

    QVariantList m_projects;
    QVariantList m_sections;
    QVariantList m_allTasks;
    QVariantList m_tasks;
    QVariantList m_taskGroups;
    QVariantMap m_account;
    QString m_selectedTitle = QStringLiteral("Today");
    QString m_selectedId;
    QString m_token;
    QString m_error;
    View m_view = View::Today;
    QNetworkAccessManager m_network;
    CredentialStore m_credentials;
    QTimer m_refreshTimer;
    QTimer m_reminderTimer;
    int m_pending = 0;
    int m_todayCount = 0;
    bool m_busy = false;
    int m_refreshIntervalMinutes = 5;
    bool m_notificationsEnabled = true;
};
