#include "vaultservice.h"
#include "cryptoengine.h"
#include "vaultdatabase.h"
#include <QFileInfo>
#include <QDir>
#include <QDirIterator>
#include <QProcess>
#include <QFile>
#include <QDebug>
#include <QDateTime>
#include <QUuid>
#include <sys/xattr.h>

VaultService::VaultService(const QString &configDir, QObject *parent)
    : QObject(parent)
    , m_crypto(new CryptoEngine(this))
    , m_db(new VaultDatabase(this))
    , m_configDir(configDir)
{
    if (!m_db->open(m_configDir + "/vault.db")) {
        qWarning() << "Failed to open vault database at" << m_configDir + "/vault.db";
    }
    m_db->clearAllSessions();
}

VaultService::~VaultService()
{
    relockAllSessions();
}

bool VaultService::lockItem(const QString &path, const QString &password)
{
    if (isLocked(path)) {
        emit lockError(path, "Item is already locked");
        return false;
    }

    QFileInfo info(path);
    if (!info.exists()) {
        emit lockError(path, "Path does not exist");
        return false;
    }

    bool success = false;
    if (info.isDir()) {
        success = lockDirectory(path, password);
    } else {
        success = lockSingleFile(path, password, 0, true);
    }

    if (success) {
        emit itemLocked(path);
    }

    return success;
}

bool VaultService::lockItems(const QStringList &paths, const QString &password)
{
    bool allSuccess = true;
    for (const QString &path : paths) {
        if (!lockItem(path, password)) {
            allSuccess = false;
        }
    }
    return allSuccess;
}

bool VaultService::unlockItem(const QString &path, const QString &password)
{
    VaultEntry entry = m_db->findByPath(path);
    if (entry.id == 0) {
        emit lockError(path, "Item is not locked");
        return false;
    }

    if (!m_crypto->verifyPassword(password, entry.pwHash, entry.pwSalt)) {
        emit accessDenied(path);
        return false;
    }

    bool success = false;
    if (entry.type == "directory") {
        success = unlockDirectory(path, password);
    } else {
        success = unlockSingleFile(path, password);
    }

    if (success) {
        emit itemUnlocked(path);
    } else {
        emit lockError(path, "Failed to unlock item");
    }

    return success;
}

bool VaultService::isLocked(const QString &path) const
{
    return m_db->hasEntry(path);
}

bool VaultService::isSessionUnlocked(const QString &path) const
{
    return m_activeSessions.contains(path);
}

bool VaultService::changePassword(const QString &path, const QString &oldPassword, const QString &newPassword)
{
    VaultEntry entry = m_db->findByPath(path);
    if (entry.id == 0) {
        emit lockError(path, "Item is not locked");
        return false;
    }

    if (!m_crypto->verifyPassword(oldPassword, entry.pwHash, entry.pwSalt)) {
        emit accessDenied(path);
        return false;
    }

    QByteArray oldPwKey = m_crypto->deriveKey(oldPassword, entry.encSalt);
    QByteArray dataKey = m_crypto->decryptKey(entry.encKey, oldPwKey);
    if (dataKey.isEmpty() && entry.type == "file") {
        emit lockError(path, "Failed to decrypt data key");
        return false;
    }

    QByteArray newPwSalt = m_crypto->generateSalt();
    QByteArray newPwKey = m_crypto->deriveKey(newPassword, newPwSalt);

    QByteArray newEncKey;
    if (entry.type == "file") {
        newEncKey = m_crypto->encryptKey(dataKey, newPwKey);
    }

    QByteArray newHashSalt;
    QByteArray newPwHash = m_crypto->hashPassword(newPassword, newHashSalt);

    entry.encSalt = newPwSalt;
    entry.encKey = newEncKey;
    entry.pwSalt = newHashSalt;
    entry.pwHash = newPwHash;

    if (!m_db->updateEntry(entry)) {
        emit lockError(path, "Failed to update entry in database");
        return false;
    }

    return true;
}

bool VaultService::sessionUnlockFolder(const QString &path, const QString &password)
{
    VaultEntry entry = m_db->findByPath(path);
    if (entry.id == 0) {
        emit lockError(path, "Folder is not locked");
        return false;
    }

    if (entry.type != "directory") {
        emit lockError(path, "Item is not a folder");
        return false;
    }

    if (!m_crypto->verifyPassword(password, entry.pwHash, entry.pwSalt)) {
        emit accessDenied(path);
        return false;
    }

    // Remove immutable flag and restore readable permissions for browsing
    setImmutable(path, false);
    restoreFilePermissions(path, entry.originalPerms.isEmpty() ? "0755" : entry.originalPerms);

    m_activeSessions.insert(path);
    m_db->addSession(entry.id, QUuid::createUuid().toString());
    emit sessionStarted(path);

    return true;
}

void VaultService::sessionRelockFolder(const QString &path)
{
    if (!m_activeSessions.contains(path)) {
        return;
    }

    // Set permissions to 0000 and restore immutable flag
    setPermissionMode(path, QFileDevice::Permissions{});
    setImmutable(path, true);

    m_activeSessions.remove(path);

    VaultEntry entry = m_db->findByPath(path);
    if (entry.id != 0) {
        m_db->removeSession(entry.id);
    }

    emit sessionEnded(path);
}

void VaultService::relockAllSessions()
{
    QSet<QString> sessions = m_activeSessions;
    for (const QString &path : sessions) {
        sessionRelockFolder(path);
    }
}

bool VaultService::isPathBlocked(const QString &path) const
{
    QString currentPath = path;
    while (!currentPath.isEmpty() && currentPath != "/") {
        if (isLocked(currentPath) && !isSessionUnlocked(currentPath)) {
            return true;
        }
        currentPath = QFileInfo(currentPath).dir().absolutePath();
    }
    return false;
}

bool VaultService::hasOwnPassword(const QString &path) const
{
    VaultEntry entry = m_db->findByPath(path);
    if (entry.id != 0) {
        return entry.isOwnPassword;
    }
    return false;
}

QSet<QString> VaultService::allLockedPaths() const
{
    QStringList paths = m_db->allLockedPaths();
    return QSet<QString>(paths.begin(), paths.end());
}

bool VaultService::lockSingleFile(const QString &path, const QString &password, qint64 parentId, bool isOwnPassword)
{
    QString perms = getFilePermissions(path);

    QByteArray dataKey = m_crypto->generateRandomKey();
    QByteArray fileIv;

    if (!m_crypto->encryptFile(path, dataKey, fileIv)) {
        emit lockError(path, "Failed to encrypt file");
        return false;
    }

    QByteArray encSalt = m_crypto->generateSalt();
    QByteArray pwKey = m_crypto->deriveKey(password, encSalt);
    QByteArray encDataKey = m_crypto->encryptKey(dataKey, pwKey);

    QByteArray pwSalt;
    QByteArray pwHash = m_crypto->hashPassword(password, pwSalt);

    VaultEntry entry;
    entry.path = path;
    entry.type = "file";
    entry.parentId = parentId;
    entry.isOwnPassword = isOwnPassword;
    entry.encIv = fileIv;
    entry.encSalt = encSalt;
    entry.encKey = encDataKey;
    entry.pwSalt = pwSalt;
    entry.pwHash = pwHash;
    entry.originalPerms = perms;
    entry.lockedAt = QDateTime::currentSecsSinceEpoch();

    if (!m_db->addEntry(entry)) {
        m_crypto->decryptFile(path, dataKey, fileIv); // Rollback
        emit lockError(path, "Failed to add entry to database");
        return false;
    }

    // Set extended attribute, then try chattr, then set permission to 0000
    setExtendedAttribute(path, true);
    setImmutable(path, true);
    setPermissionMode(path, QFileDevice::Permissions{});

    return true;
}

bool VaultService::lockDirectory(const QString &path, const QString &password)
{
    QString perms = getFilePermissions(path);

    QByteArray pwSalt;
    QByteArray pwHash = m_crypto->hashPassword(password, pwSalt);

    VaultEntry dirEntry;
    dirEntry.path = path;
    dirEntry.type = "directory";
    dirEntry.parentId = 0;
    dirEntry.isOwnPassword = true;
    dirEntry.pwSalt = pwSalt;
    dirEntry.pwHash = pwHash;
    dirEntry.originalPerms = perms;
    dirEntry.lockedAt = QDateTime::currentSecsSinceEpoch();

    if (!m_db->addEntry(dirEntry)) {
        emit lockError(path, "Failed to add directory entry to database");
        return false;
    }

    dirEntry = m_db->findByPath(path);
    qint64 dirEntryId = dirEntry.id;

    QDirIterator it(path, QDir::Files | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
    bool allSuccess = true;
    while (it.hasNext()) {
        QString filePath = it.next();
        if (!lockSingleFile(filePath, password, dirEntryId, false)) {
            allSuccess = false;
        }
    }

    // Set extended attribute, then try chattr, then set permission to 0000
    setExtendedAttribute(path, true);
    setImmutable(path, true);
    setPermissionMode(path, QFileDevice::Permissions{});

    return allSuccess;
}

bool VaultService::unlockSingleFile(const QString &path, const QString &password)
{
    VaultEntry entry = m_db->findByPath(path);
    if (entry.id == 0) {
        return false;
    }

    QByteArray pwKey = m_crypto->deriveKey(password, entry.encSalt);
    QByteArray dataKey = m_crypto->decryptKey(entry.encKey, pwKey);

    if (dataKey.isEmpty()) {
        emit lockError(path, "Failed to decrypt data key");
        return false;
    }

    setImmutable(path, false);
    restoreFilePermissions(path, entry.originalPerms);

    if (!m_crypto->decryptFile(path, dataKey, entry.encIv)) {
        setPermissionMode(path, QFileDevice::Permissions{});
        setImmutable(path, true);
        emit lockError(path, "Failed to decrypt file contents");
        return false;
    }

    setExtendedAttribute(path, false);
    m_db->removeEntry(path);

    return true;
}

bool VaultService::unlockDirectory(const QString &path, const QString &password)
{
    VaultEntry dirEntry = m_db->findByPath(path);
    if (dirEntry.id == 0) {
        return false;
    }

    setImmutable(path, false);
    restoreFilePermissions(path, dirEntry.originalPerms.isEmpty() ? "0755" : dirEntry.originalPerms);
    setExtendedAttribute(path, false);

    QList<VaultEntry> children = m_db->findByParentId(dirEntry.id);
    bool allSuccess = true;
    for (const VaultEntry &child : children) {
        if (!unlockSingleFile(child.path, password)) {
            allSuccess = false;
        }
    }

    m_db->removeEntry(path);
    m_activeSessions.remove(path);

    return allSuccess;
}

bool VaultService::setImmutable(const QString &path, bool immutable)
{
    // Try direct chattr (succeeds if running as root or process has CAP_LINUX_IMMUTABLE)
    QStringList chattrArgs;
    chattrArgs << (immutable ? "+i" : "-i") << path;
    if (QProcess::execute("chattr", chattrArgs) == 0) {
        return true;
    }

    // In desktop environments and user sessions, non-root users do not possess
    // CAP_LINUX_IMMUTABLE. Invoking pkexec during UI operations blocks the GUI thread
    // and fails when no polkit agent is active. Direct chattr is best-effort.
    // The item is fully secured via AES-256-GCM encryption, 0000 permissions, and xattrs.
    return true;
}

bool VaultService::setExtendedAttribute(const QString &path, bool locked)
{
    QByteArray pathBa = path.toLocal8Bit();
    if (locked) {
        const char *val = "1";
        if (setxattr(pathBa.constData(), "user.bubble.locked", val, 1, 0) != 0) {
            // Note: some filesystems don't support user xattrs, non-fatal
        }
    } else {
        removexattr(pathBa.constData(), "user.bubble.locked");
    }
    return true;
}

QString VaultService::getFilePermissions(const QString &path) const
{
    QFile file(path);
    return QString::number(file.permissions(), 16);
}

bool VaultService::restoreFilePermissions(const QString &path, const QString &perms)
{
    QFile file(path);
    bool ok;
    QFile::Permissions p(perms.toUInt(&ok, 16));
    if (ok && p != 0) {
        return file.setPermissions(p);
    }
    return file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner |
                               QFileDevice::ReadGroup | QFileDevice::ReadOther);
}

bool VaultService::setPermissionMode(const QString &path, QFileDevice::Permissions p)
{
    QFile file(path);
    return file.setPermissions(p);
}

