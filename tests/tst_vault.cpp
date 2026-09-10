#include <QTest>
#include <QTemporaryDir>
#include <QFile>
#include <QSignalSpy>
#include "services/cryptoengine.h"
#include "services/vaultdatabase.h"
#include "services/vaultservice.h"

class TestVault : public QObject
{
    Q_OBJECT

private slots:
    void testCryptoEngineHashVerify();
    void testCryptoEngineEncryptDecrypt();
    void testCryptoEngineKeyEnvelope();
    void testCryptoEngineFileEncryptDecrypt();
    void testCryptoEngineShred();
    void testVaultDatabaseCrud();
    void testVaultServiceLockUnlockFile();
    void testVaultServiceChangePassword();
};

void TestVault::testCryptoEngineHashVerify()
{
    CryptoEngine crypto;
    QByteArray salt;
    QByteArray hash = crypto.hashPassword("SuperSecret123!", salt);
    QVERIFY(!hash.isEmpty());
    QVERIFY(!salt.isEmpty());
    QCOMPARE(salt.length(), CryptoEngine::SALT_SIZE);

    QVERIFY(crypto.verifyPassword("SuperSecret123!", hash, salt));
    QVERIFY(!crypto.verifyPassword("WrongPassword!", hash, salt));
}

void TestVault::testCryptoEngineEncryptDecrypt()
{
    CryptoEngine crypto;
    QByteArray key = crypto.generateRandomKey();
    QCOMPARE(key.length(), CryptoEngine::KEY_SIZE);

    QByteArray plaintext = "Hello, this is confidential data!";
    QByteArray iv;
    QByteArray ciphertext = crypto.encrypt(plaintext, key, iv);
    QVERIFY(!ciphertext.isEmpty());
    QVERIFY(ciphertext != plaintext);
    QCOMPARE(iv.length(), CryptoEngine::IV_SIZE);

    QByteArray decrypted = crypto.decrypt(ciphertext, key, iv);
    QCOMPARE(decrypted, plaintext);

    // Wrong key decrypt should fail
    QByteArray wrongKey = crypto.generateRandomKey();
    QByteArray failed = crypto.decrypt(ciphertext, wrongKey, iv);
    QVERIFY(failed.isEmpty());
}

void TestVault::testCryptoEngineKeyEnvelope()
{
    CryptoEngine crypto;
    QByteArray dataKey = crypto.generateRandomKey();
    QByteArray salt = crypto.generateSalt();
    QByteArray pwKey = crypto.deriveKey("my-passphrase", salt);

    QByteArray encBlob = crypto.encryptKey(dataKey, pwKey);
    QVERIFY(!encBlob.isEmpty());

    QByteArray recoveredKey = crypto.decryptKey(encBlob, pwKey);
    QCOMPARE(recoveredKey, dataKey);

    QByteArray wrongPwKey = crypto.deriveKey("wrong-passphrase", salt);
    QByteArray badKey = crypto.decryptKey(encBlob, wrongPwKey);
    QVERIFY(badKey.isEmpty());
}

void TestVault::testCryptoEngineFileEncryptDecrypt()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString testFile = tempDir.filePath("test.txt");

    QByteArray originalContent = "Confidential document text that must be kept safe.";
    {
        QFile f(testFile);
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write(originalContent);
        f.close();
    }

    CryptoEngine crypto;
    QByteArray key = crypto.generateRandomKey();
    QByteArray iv;
    QVERIFY(crypto.encryptFile(testFile, key, iv));

    // Verify content on disk changed
    {
        QFile f(testFile);
        QVERIFY(f.open(QIODevice::ReadOnly));
        QByteArray onDisk = f.readAll();
        QVERIFY(onDisk != originalContent);
        f.close();
    }

    // Decrypt
    QVERIFY(crypto.decryptFile(testFile, key, iv));

    // Verify original content restored
    {
        QFile f(testFile);
        QVERIFY(f.open(QIODevice::ReadOnly));
        QByteArray restored = f.readAll();
        QCOMPARE(restored, originalContent);
        f.close();
    }
}

void TestVault::testCryptoEngineShred()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString testFile = tempDir.filePath("shred_me.txt");

    {
        QFile f(testFile);
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write("Data to be securely deleted");
        f.close();
    }

    QVERIFY(QFile::exists(testFile));
    QVERIFY(CryptoEngine::shredFile(testFile));
    QVERIFY(!QFile::exists(testFile));
}

void TestVault::testVaultDatabaseCrud()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString dbPath = tempDir.filePath("vault.db");

    VaultDatabase db;
    QVERIFY(db.open(dbPath));
    QVERIFY(db.isOpen());

    VaultEntry entry;
    entry.path = "/test/path/file.txt";
    entry.type = "file";
    entry.pwHash = "dummyhash";
    entry.pwSalt = "dummysalt";
    entry.encKey = "enckey";
    entry.encIv = "enciv";
    entry.encSalt = "encsalt";
    entry.originalPerms = "0644";
    entry.lockedAt = 123456789;
    entry.isOwnPassword = true;

    QVERIFY(db.addEntry(entry));
    QVERIFY(db.hasEntry("/test/path/file.txt"));

    VaultEntry found = db.findByPath("/test/path/file.txt");
    QCOMPARE(found.path, entry.path);
    QCOMPARE(found.type, entry.type);
    QCOMPARE(found.originalPerms, entry.originalPerms);

    entry.pwHash = "updatedhash";
    QVERIFY(db.updateEntry(entry));
    found = db.findByPath("/test/path/file.txt");
    QCOMPARE(found.pwHash, QByteArray("updatedhash"));

    QCOMPARE(db.allLockedPaths().size(), 1);
    QCOMPARE(db.allLockedPaths().first(), QString("/test/path/file.txt"));

    QVERIFY(db.removeEntry("/test/path/file.txt"));
    QVERIFY(!db.hasEntry("/test/path/file.txt"));

    db.close();
}

void TestVault::testVaultServiceLockUnlockFile()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString configDir = tempDir.filePath("config");
    QString testFile = tempDir.filePath("secret_document.txt");

    QByteArray originalContent = "Top secret blueprint for Bubble file manager!";
    {
        QFile f(testFile);
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write(originalContent);
        f.close();
    }

    VaultService vault(configDir);
    QVERIFY(!vault.isLocked(testFile));

    // Lock item
    QVERIFY(vault.lockItem(testFile, "Pa$$w0rd123"));
    QVERIFY(vault.isLocked(testFile));

    // Content should not be readable plaintext on disk
    {
        QFile f(testFile);
        // Permissions may be 0000; restore read permission to inspect disk content
        f.setPermissions(QFileDevice::ReadOwner);
        QVERIFY(f.open(QIODevice::ReadOnly));
        QByteArray diskData = f.readAll();
        QVERIFY(diskData != originalContent);
        f.close();
    }

    // Try unlocking with wrong password
    QVERIFY(!vault.unlockItem(testFile, "WrongPassword"));
    QVERIFY(vault.isLocked(testFile));

    // Unlock with correct password
    QVERIFY(vault.unlockItem(testFile, "Pa$$w0rd123"));
    QVERIFY(!vault.isLocked(testFile));

    // Content should now be restored to original plaintext
    {
        QFile f(testFile);
        QVERIFY(f.open(QIODevice::ReadOnly));
        QByteArray restored = f.readAll();
        QCOMPARE(restored, originalContent);
        f.close();
    }
}

void TestVault::testVaultServiceChangePassword()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString configDir = tempDir.filePath("config");
    QString testFile = tempDir.filePath("change_pass.txt");

    QByteArray content = "Password rotation test";
    {
        QFile f(testFile);
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write(content);
        f.close();
    }

    VaultService vault(configDir);
    QVERIFY(vault.lockItem(testFile, "InitialPassword"));

    // Changing with wrong current password fails
    QVERIFY(!vault.changePassword(testFile, "WrongPass", "NewPassword"));

    // Changing with correct current password succeeds
    QVERIFY(vault.changePassword(testFile, "InitialPassword", "NewPassword"));

    // Old password no longer works to unlock
    QVERIFY(!vault.unlockItem(testFile, "InitialPassword"));

    // New password unlocks successfully
    QVERIFY(vault.unlockItem(testFile, "NewPassword"));
    QVERIFY(!vault.isLocked(testFile));

    {
        QFile f(testFile);
        QVERIFY(f.open(QIODevice::ReadOnly));
        QCOMPARE(f.readAll(), content);
        f.close();
    }
}

QTEST_MAIN(TestVault)
#include "tst_vault.moc"
