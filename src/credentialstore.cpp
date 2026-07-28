#include "credentialstore.h"

#include <KWallet>

namespace {
constexpr auto folderName = "Todoist Client";
constexpr auto tokenKey = "todoist/api-token";
}

CredentialStore::CredentialStore() = default;
CredentialStore::~CredentialStore() = default;

bool CredentialStore::open()
{
    if (m_wallet) {
        return true;
    }
    m_wallet.reset(KWallet::Wallet::openWallet(
        KWallet::Wallet::LocalWallet(), 0, KWallet::Wallet::Synchronous));
    if (!m_wallet) {
        m_error = QStringLiteral("KDE Wallet is unavailable or locked.");
        return false;
    }
    if (!m_wallet->hasFolder(QString::fromLatin1(folderName))
        && !m_wallet->createFolder(QString::fromLatin1(folderName))) {
        m_error = QStringLiteral("Could not create the KDE Wallet folder.");
        m_wallet.reset();
        return false;
    }
    if (!m_wallet->setFolder(QString::fromLatin1(folderName))) {
        m_error = QStringLiteral("Could not open the KDE Wallet folder.");
        m_wallet.reset();
        return false;
    }
    return true;
}

QString CredentialStore::readToken()
{
    if (!open()) {
        return {};
    }
    QString token;
    if (m_wallet->readPassword(QString::fromLatin1(tokenKey), token) != 0) {
        return {};
    }
    return token;
}

bool CredentialStore::writeToken(const QString &token)
{
    return open()
        && m_wallet->writePassword(QString::fromLatin1(tokenKey), token) == 0;
}

bool CredentialStore::removeToken()
{
    return open()
        && m_wallet->removeEntry(QString::fromLatin1(tokenKey)) == 0;
}

QString CredentialStore::lastError() const
{
    return m_error;
}
