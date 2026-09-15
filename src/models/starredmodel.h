#pragma once

#include <QAbstractListModel>
#include <QStringList>
#include <QDateTime>

class StarredModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(bool hasMissing READ hasMissing NOTIFY hasMissingChanged)

public:
    enum Roles {
        FileNameRole = Qt::UserRole + 1,
        FilePathRole,
        IsDirRole,
        FileSizeTextRole,
        FileTypeRole,
        FileIconNameRole,
        HasImagePreviewRole,
        ExistsRole,
        ModifiedTextRole,
    };

    explicit StarredModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setStarredItems(const QStringList &paths);
    QStringList starredItems() const;

    Q_INVOKABLE void starPath(const QString &path);
    Q_INVOKABLE void unstarPath(const QString &path);
    Q_INVOKABLE void toggleStar(const QString &path);
    Q_INVOKABLE bool isStarred(const QString &path) const;
    Q_INVOKABLE void removeAt(int index);
    Q_INVOKABLE void clearMissing();
    Q_INVOKABLE void moveStarred(int from, int to);
    Q_INVOKABLE void refresh();

    bool hasMissing() const;

signals:
    void countChanged();
    void hasMissingChanged();
    void starredChanged();

private:
    struct StarredEntry {
        QString path;
        QString name;
        bool isDir = false;
        QString sizeText;
        QString fileType;
        QString iconName;
        bool hasImagePreview = false;
        bool exists = true;
        QString modifiedText;
    };

    QList<StarredEntry> m_entries;

    StarredEntry makeEntry(const QString &path) const;
    static QString expandPath(const QString &path);
    static QString portablePath(const QString &path);
    static QString formatSize(qint64 bytes);
    void updateMissingState();
};
