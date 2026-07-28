#pragma once

#include <QString>
#include <memory>

namespace KWallet { class Wallet; }

class CredentialStore final
{
public:
    CredentialStore();
    ~CredentialStore();
    QString readToken();
    bool writeToken(const QString &token);
    bool removeToken();
    QString lastError() const;

private:
    bool open();
    std::unique_ptr<KWallet::Wallet> m_wallet;
    QString m_error;
};
