#include "notificationmetadata.h"

#include <QDir>
#include <QFile>
#include <QSaveFile>
#include <QStandardPaths>

bool ensureNotificationMetadata(const QString &fileName,
                                const QString &resourcePath)
{
    const auto dataDirectory =
        QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    if (dataDirectory.isEmpty()) {
        return false;
    }

    const auto notificationDirectory =
        dataDirectory + QStringLiteral("/knotifications6");
    const auto destination =
        notificationDirectory + QLatin1Char('/') + fileName;
    if (QFile::exists(destination)) {
        return true;
    }
    if (!QDir().mkpath(notificationDirectory)) {
        return false;
    }

    QFile source(resourcePath);
    if (!source.open(QIODevice::ReadOnly)) {
        return false;
    }
    QSaveFile output(destination);
    if (!output.open(QIODevice::WriteOnly)
        || output.write(source.readAll()) < 0) {
        return false;
    }
    return output.commit();
}
