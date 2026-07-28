#include "todoistcontroller.h"

#include <KAboutData>
#include <KLocalizedQmlContext>
#include <KLocalizedString>
#include <KWindowEffects>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QWindow>

#include <cstdio>

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    KLocalizedString::setApplicationDomain("todoistclient");
    KAboutData about(QStringLiteral("todoistclient"),
                     i18nc("@title", "Todoist"),
                     QStringLiteral("0.1.0"),
                     i18nc("@info", "A fast native Todoist client"),
                     KAboutLicense::GPL_V3);
    about.setDesktopFileName(QStringLiteral("org.suryask.todoist"));
    KAboutData::setApplicationData(about);
    QGuiApplication::setDesktopFileName(about.desktopFileName());
    QQuickStyle::setStyle(QStringLiteral("org.kde.desktop"));

    TodoistController controller;
    QObject::connect(&controller, &TodoistController::dataChanged, &app, [&app, &controller] {
        app.setBadgeNumber(controller.todayCount());
    });
    QObject::connect(&app, &QCoreApplication::aboutToQuit, &app, [&app] {
        app.setBadgeNumber(0);
    });

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlEngine::warnings, [](const QList<QQmlError> &warnings) {
        for (const auto &warning : warnings) {
            std::fprintf(stderr, "%s\n", qPrintable(warning.toString()));
        }
    });
    KLocalization::setupLocalizedContext(&engine);
    engine.setInitialProperties(
        {{QStringLiteral("controller"), QVariant::fromValue(&controller)}});
    engine.loadFromModule(QStringLiteral("TodoistClient"), QStringLiteral("Main"));
    if (engine.rootObjects().isEmpty()) {
        std::fputs("Todoist: the QML interface could not be loaded.\n", stderr);
        return EXIT_FAILURE;
    }
    if (auto *window = qobject_cast<QWindow *>(engine.rootObjects().constFirst())) {
        KWindowEffects::enableBlurBehind(window, true);
    }
    return app.exec();
}
