#include "models/starredmodel.h"
#include <QDir>
#include <QFileInfo>
#include <QMimeDatabase>
#include <QMimeType>
#include <QUrl>

namespace {

bool isRemoteUri(const QString &path)
{
    const QUrl url(path);
    return url.isValid() && !url.scheme().isEmpty()
        && url.scheme() != QStringLiteral("file")
        && url.scheme() != QStringLiteral("trash");
}

QString entryDisplayName(const QString &path)
{
    if (!isRemoteUri(path)) {
        QFileInfo fi(path);
        QString name = fi.fileName();
        if (name.isEmpty())
            name = fi.dir().dirName();
        return name.isEmpty() ? path : name;
    }

    const QUrl url(path);
    const QString fileName = QUrl::fromPercentEncoding(url.fileName().toUtf8());
    if (!fileName.isEmpty())
        return fileName;
    if (!url.host().isEmpty())
        return url.host();
    return url.scheme().toUpper();
}

} // namespace

StarredModel::StarredModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int StarredModel::rowCount(const QModelIndex &) const
{
    return m_entries.size();
}

QVariant StarredModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_entries.size())
        return {};

    const auto &item = m_entries.at(index.row());
    switch (role) {
    case FileNameRole: return item.name;
    case FilePathRole: return item.path;
    case IsDirRole: return item.isDir;
    case FileSizeTextRole: return item.sizeText;
    case FileTypeRole: return item.fileType;
    case FileIconNameRole: return item.iconName;
    case HasImagePreviewRole: return item.hasImagePreview;
    case ExistsRole: return item.exists;
    case ModifiedTextRole: return item.modifiedText;
    }
    return {};
}

QHash<int, QByteArray> StarredModel::roleNames() const
{
    return {
        {FileNameRole, "fileName"},
        {FilePathRole, "filePath"},
        {IsDirRole, "isDir"},
        {FileSizeTextRole, "fileSizeText"},
        {FileTypeRole, "fileType"},
        {FileIconNameRole, "fileIconName"},
        {HasImagePreviewRole, "hasImagePreview"},
        {ExistsRole, "exists"},
        {ModifiedTextRole, "modifiedText"},
    };
}

void StarredModel::setStarredItems(const QStringList &paths)
{
    QList<StarredEntry> newEntries;
    newEntries.reserve(paths.size());

    for (const QString &raw : paths) {
        if (raw.trimmed().isEmpty())
            continue;
        newEntries.append(makeEntry(raw));
    }

    beginResetModel();
    m_entries = newEntries;
    endResetModel();
    emit countChanged();
    emit hasMissingChanged();
}

QStringList StarredModel::starredItems() const
{
    QStringList result;
    result.reserve(m_entries.size());
    for (const auto &item : m_entries)
        result.append(portablePath(item.path));
    return result;
}

void StarredModel::starPath(const QString &path)
{
    const QString expanded = expandPath(path);
    if (expanded.isEmpty() || isStarred(expanded))
        return;

    beginInsertRows(QModelIndex(), m_entries.size(), m_entries.size());
    m_entries.append(makeEntry(expanded));
    endInsertRows();

    emit countChanged();
    emit hasMissingChanged();
    emit starredChanged();
}

void StarredModel::unstarPath(const QString &path)
{
    const QString expanded = expandPath(path);
    for (int i = 0; i < m_entries.size(); ++i) {
        if (m_entries.at(i).path == expanded) {
            beginRemoveRows(QModelIndex(), i, i);
            m_entries.removeAt(i);
            endRemoveRows();

            emit countChanged();
            emit hasMissingChanged();
            emit starredChanged();
            return;
        }
    }
}

void StarredModel::toggleStar(const QString &path)
{
    if (isStarred(path))
        unstarPath(path);
    else
        starPath(path);
}

bool StarredModel::isStarred(const QString &path) const
{
    const QString expanded = expandPath(path);
    for (const auto &item : m_entries) {
        if (item.path == expanded)
            return true;
    }
    return false;
}

void StarredModel::removeAt(int index)
{
    if (index < 0 || index >= m_entries.size())
        return;

    beginRemoveRows(QModelIndex(), index, index);
    m_entries.removeAt(index);
    endRemoveRows();

    emit countChanged();
    emit hasMissingChanged();
    emit starredChanged();
}

void StarredModel::clearMissing()
{
    bool changed = false;
    for (int i = m_entries.size() - 1; i >= 0; --i) {
        if (!m_entries.at(i).exists) {
            beginRemoveRows(QModelIndex(), i, i);
            m_entries.removeAt(i);
            endRemoveRows();
            changed = true;
        }
    }

    if (changed) {
        emit countChanged();
        emit hasMissingChanged();
        emit starredChanged();
    }
}

void StarredModel::moveStarred(int from, int to)
{
    if (from < 0 || from >= m_entries.size() || to < 0 || to >= m_entries.size() || from == to)
        return;

    int dest = to > from ? to + 1 : to;
    if (!beginMoveRows(QModelIndex(), from, from, QModelIndex(), dest))
        return;

    m_entries.move(from, to);
    endMoveRows();
    emit starredChanged();
}

void StarredModel::refresh()
{
    if (m_entries.isEmpty())
        return;

    for (int i = 0; i < m_entries.size(); ++i) {
        m_entries[i] = makeEntry(m_entries.at(i).path);
    }
    emit dataChanged(index(0, 0), index(m_entries.size() - 1, 0));
    emit hasMissingChanged();
}

bool StarredModel::hasMissing() const
{
    for (const auto &item : m_entries) {
        if (!item.exists)
            return true;
    }
    return false;
}

StarredModel::StarredEntry StarredModel::makeEntry(const QString &rawPath) const
{
    StarredEntry entry;
    entry.path = expandPath(rawPath);
    entry.name = entryDisplayName(entry.path);

    if (isRemoteUri(entry.path)) {
        entry.isDir = true;
        entry.sizeText = QStringLiteral("Remote");
        entry.fileType = QStringLiteral("Remote Folder");
        entry.iconName = QStringLiteral("folder-remote");
        entry.exists = true;
        return entry;
    }

    QFileInfo fi(entry.path);
    entry.exists = fi.exists();

    if (!entry.exists) {
        entry.isDir = false;
        entry.sizeText = QStringLiteral("Missing");
        entry.fileType = QStringLiteral("Unavailable");
        entry.iconName = QStringLiteral("dialog-question");
        entry.hasImagePreview = false;
        return entry;
    }

    entry.isDir = fi.isDir();
    entry.modifiedText = fi.lastModified().toString(QStringLiteral("MMM d, yyyy h:mm AP"));

    if (entry.isDir) {
        QDir dir(entry.path);
        uint count = dir.count();
        if (count >= 2) count -= 2; // omit . and ..
        entry.sizeText = QStringLiteral("%1 item%2").arg(count).arg(count == 1 ? QString() : QStringLiteral("s"));
        entry.fileType = QStringLiteral("Folder");
        entry.iconName = QStringLiteral("folder");
        entry.hasImagePreview = false;
    } else {
        entry.sizeText = formatSize(fi.size());
        QMimeDatabase mimeDb;
        QMimeType mime = mimeDb.mimeTypeForFile(fi);
        entry.fileType = mime.comment().isEmpty() ? mime.name() : mime.comment();
        entry.iconName = mime.iconName();
        if (entry.iconName.isEmpty())
            entry.iconName = QStringLiteral("text-x-generic");

        const QString mimeName = mime.name();
        entry.hasImagePreview = mimeName.startsWith(QStringLiteral("image/"))
                             || mimeName == QStringLiteral("application/pdf")
                             || mimeName.startsWith(QStringLiteral("video/"));
    }

    return entry;
}

QString StarredModel::expandPath(const QString &path)
{
    const QUrl url(path);
    if (url.isValid() && !url.scheme().isEmpty() && url.scheme() != QStringLiteral("file"))
        return url.toString(QUrl::FullyEncoded);
    if (path.startsWith(QLatin1String("~/")))
        return QDir::homePath() + path.mid(1);
    return QDir::cleanPath(path);
}

QString StarredModel::portablePath(const QString &path)
{
    const QString home = QDir::homePath();
    if (path == home)
        return QStringLiteral("~");
    if (path.startsWith(home + QLatin1Char('/')))
        return QStringLiteral("~") + path.mid(home.length());
    return path;
}

QString StarredModel::formatSize(qint64 bytes)
{
    if (bytes < 1024)
        return QString::number(bytes) + QStringLiteral(" B");
    if (bytes < 1024 * 1024)
        return QString::number(bytes / 1024.0, 'f', 1) + QStringLiteral(" KB");
    if (bytes < 1024 * 1024 * 1024)
        return QString::number(bytes / (1024.0 * 1024.0), 'f', 1) + QStringLiteral(" MB");
    return QString::number(bytes / (1024.0 * 1024.0 * 1024.0), 'f', 1) + QStringLiteral(" GB");
}
