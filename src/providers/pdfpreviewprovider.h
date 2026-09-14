#pragma once

#include <QQuickAsyncImageProvider>
#include <QQuickImageResponse>
#include <QImage>
#include <QSize>
#include <QRunnable>
#include <QString>
#include <atomic>

class PdfPreviewResponse : public QQuickImageResponse, public QRunnable
{
    Q_OBJECT

public:
    PdfPreviewResponse(const QString &id, const QSize &requestedSize);

    void run() override;
    QQuickTextureFactory *textureFactory() const override;
    bool isFinished() const { return m_finished.load(std::memory_order_acquire); }

private:
    // Returns true and fills m_image when this page is already rendered.
    bool tryCache(const QString &key);

    QString m_id;
    QSize m_requestedSize;
    QImage m_image;
    std::atomic<bool> m_finished{false};
};

class PdfPreviewProvider : public QQuickAsyncImageProvider
{
public:
    QQuickImageResponse *requestImageResponse(const QString &id,
                                              const QSize &requestedSize) override;
};
