#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QDebug>
#include <iostream>
#include "services/cryptoengine.h"
#include "services/vaultdatabase.h"

static void unlockChattr(const QString &path)
{
    QStringList args;
    args << "-i" << path;
    QProcess::execute("chattr", args);
}

static void shredAndRemove(const QString &path)
{
    QFileInfo info(path);
    if (!info.exists()) {
        return;
    }

    unlockChattr(path);

    if (info.isDir()) {
        QDir dir(path);
        const auto entries = dir.entryInfoList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot | QDir::Hidden);
        for (const auto &entry : entries) {
            shredAndRemove(entry.absoluteFilePath());
        }
        dir.rmdir(path);
    } else {
        std::cout << "Shredding locked file: " << path.toStdString() << std::endl;
        CryptoEngine::shredFile(path);
    }
}

static void processVaultDb(const QString &dbPath)
{
    if (!QFile::exists(dbPath)) {
        return;
    }

    std::cout << "Processing vault at: " << dbPath.toStdString() << std::endl;
    VaultDatabase db;
    if (!db.open(dbPath)) {
        std::cerr << "Failed to open database: " << dbPath.toStdString() << std::endl;
        return;
    }

    const QStringList paths = db.allLockedPaths();
    for (const QString &path : paths) {
        shredAndRemove(path);
    }

    db.close();

    // Remove the database files
    QFile::remove(dbPath);
    QFile::remove(dbPath + "-wal");
    QFile::remove(dbPath + "-shm");
    std::cout << "Vault database destroyed: " << dbPath.toStdString() << std::endl;
}

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    const QStringList args = app.arguments();

    bool allUsers = args.contains("--all-users");

    if (allUsers) {
        std::cout << "Destroying Bubble vaults for all users..." << std::endl;
        QDir homeDir("/home");
        const QStringList userDirs = homeDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QString &user : userDirs) {
            QString vaultDb = QString("/home/%1/.config/bubble/vault.db").arg(user);
            processVaultDb(vaultDb);
        }
        // Also check root's home
        processVaultDb("/root/.config/bubble/vault.db");
    } else {
        // Current user
        QString configPath = QDir::homePath() + "/.config/bubble/vault.db";
        processVaultDb(configPath);
    }

    std::cout << "Bubble vault cleanup complete." << std::endl;
    return 0;
}
