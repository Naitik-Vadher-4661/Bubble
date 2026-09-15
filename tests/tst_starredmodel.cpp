#include <QTest>
#include <QSignalSpy>
#include <QAbstractItemModelTester>
#include <QTemporaryDir>
#include <QFile>
#include "models/starredmodel.h"

class TestStarredModel : public QObject
{
    Q_OBJECT

private slots:
    void testModelConsistency()
    {
        StarredModel model;
        auto *tester = new QAbstractItemModelTester(&model,
            QAbstractItemModelTester::FailureReportingMode::QtTest);
        Q_UNUSED(tester)

        model.setStarredItems({"~/Documents", "~/Downloads", "~/Pictures"});
        model.starPath("~/Music");
        model.unstarPath("~/Downloads");
        model.clearMissing();
        model.setStarredItems({});
    }

    void testStarAndUnstar()
    {
        QTemporaryDir tempDir;
        QVERIFY(tempDir.isValid());
        QString filePath = tempDir.filePath("testfile.txt");
        QFile file(filePath);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write("hello world");
        file.close();

        StarredModel model;
        QSignalSpy countSpy(&model, &StarredModel::countChanged);
        QSignalSpy changeSpy(&model, &StarredModel::starredChanged);

        model.starPath(filePath);
        QCOMPARE(model.rowCount(), 1);
        QCOMPARE(countSpy.count(), 1);
        QCOMPARE(changeSpy.count(), 1);
        QVERIFY(model.isStarred(filePath));

        // Adding again does not duplicate
        model.starPath(filePath);
        QCOMPARE(model.rowCount(), 1);

        // Unstar
        model.unstarPath(filePath);
        QCOMPARE(model.rowCount(), 0);
        QVERIFY(!model.isStarred(filePath));
        QCOMPARE(countSpy.count(), 2);
        QCOMPARE(changeSpy.count(), 2);
    }

    void testToggleStar()
    {
        QTemporaryDir tempDir;
        QVERIFY(tempDir.isValid());
        QString filePath = tempDir.filePath("sample.txt");
        QFile file(filePath);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write("data");
        file.close();

        StarredModel model;
        model.toggleStar(filePath);
        QVERIFY(model.isStarred(filePath));
        QCOMPARE(model.rowCount(), 1);

        model.toggleStar(filePath);
        QVERIFY(!model.isStarred(filePath));
        QCOMPARE(model.rowCount(), 0);
    }

    void testClearMissing()
    {
        QTemporaryDir tempDir;
        QVERIFY(tempDir.isValid());
        QString existingPath = tempDir.filePath("keep.txt");
        QFile file(existingPath);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write("keep");
        file.close();

        QString missingPath = tempDir.filePath("deleted.txt");

        StarredModel model;
        model.starPath(existingPath);
        model.starPath(missingPath);
        QCOMPARE(model.rowCount(), 2);
        QVERIFY(model.hasMissing());

        model.clearMissing();
        QCOMPARE(model.rowCount(), 1);
        QVERIFY(!model.hasMissing());
        QVERIFY(model.isStarred(existingPath));
        QVERIFY(!model.isStarred(missingPath));
    }

    void testDataRoles()
    {
        QTemporaryDir tempDir;
        QVERIFY(tempDir.isValid());
        QString folderPath = tempDir.filePath("myfolder");
        QDir(tempDir.path()).mkdir("myfolder");

        StarredModel model;
        model.starPath(folderPath);
        QModelIndex idx = model.index(0);

        QCOMPARE(model.data(idx, StarredModel::FileNameRole).toString(), QString("myfolder"));
        QCOMPARE(model.data(idx, StarredModel::FilePathRole).toString(), folderPath);
        QCOMPARE(model.data(idx, StarredModel::IsDirRole).toBool(), true);
        QCOMPARE(model.data(idx, StarredModel::ExistsRole).toBool(), true);
    }
};

QTEST_MAIN(TestStarredModel)
#include "tst_starredmodel.moc"
