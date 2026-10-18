#include "requests.hpp"

#include <qjsvalue.h>
#include <qjsvalueiterator.h>
#include <qloggingcategory.h>
#include <qnetworkaccessmanager.h>
#include <qnetworkcookiejar.h>
#include <qnetworkreply.h>
#include <qnetworkrequest.h>
#include <qqmlengine.h>
#include <qvariant.h>

namespace {

Q_LOGGING_CATEGORY(lcRequests, "jellyface.requests", QtInfoMsg)

} // namespace

namespace jellyface {

using Qt::StringLiterals::operator""_s;
using Qt::StringLiterals::operator""_ba;

namespace {

// A request that never answers must not hang a caller forever (the weather lookup waited on one), and nothing the shell
// fetches (weather, lyrics, IP lookup) comes anywhere near this size.
constexpr int kTransferTimeoutMs = 15000;
constexpr qint64 kMaxResponseBytes = 8 * 1024 * 1024;

QVariantMap responseMetadata(const QNetworkReply* reply) {
    QVariantMap headers;

    for (const auto& [name, value] : reply->rawHeaderPairs()) {
        headers.insert(QString::fromLatin1(name).toLower(), QString::fromLatin1(value));
    }

    return {
        { u"statusCode"_s, reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() },
        { u"headers"_s, headers },
    };
}

} // namespace

Requests::Requests(QObject* parent)
    : QObject(parent)
    , m_manager(new QNetworkAccessManager(this)) {}

void Requests::get(const QUrl& url, const QJSValue& onSuccess, const QJSValue& onError, const QJSValue& headers) const {
    if (!onSuccess.isCallable()) {
        qCWarning(lcRequests) << "get: onSuccess is not callable";
        return;
    }

    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::AlwaysNetwork);
    request.setAttribute(QNetworkRequest::CookieSaveControlAttribute, QNetworkRequest::Manual);
    request.setRawHeader("Cache-Control"_ba, "no-cache, no-store"_ba);
    request.setRawHeader("Pragma"_ba, "no-cache"_ba);
    request.setRawHeader("Connection"_ba, "close"_ba);
    request.setTransferTimeout(kTransferTimeoutMs);

    if (headers.isObject()) {
        QJSValueIterator it(headers);
        while (it.hasNext()) {
            it.next();
            request.setRawHeader(it.name().toUtf8(), it.value().toString().toUtf8());
        }
    }

    auto* reply = m_manager->get(request);

    // Three layers, because on a fast link the whole body can arrive before any progress signal is handled:
    // refuse by the announced length, stop reading once the buffer limit is reached, and re-check when it finishes.
    reply->setReadBufferSize(kMaxResponseBytes + 1);
    QObject::connect(reply, &QNetworkReply::metaDataChanged, reply, [reply] {
        if (reply->header(QNetworkRequest::ContentLengthHeader).toLongLong() > kMaxResponseBytes) {
            reply->abort();
        }
    });
    QObject::connect(reply, &QNetworkReply::downloadProgress, reply, [reply](qint64 received, qint64) {
        if (received > kMaxResponseBytes) {
            reply->abort(); // finishes with an error, so the caller's onError runs
        }
    });

    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, onSuccess, onError] {
        const QByteArray raw = reply->readAll();
        const bool tooLarge = raw.size() > kMaxResponseBytes;
        const QString body = tooLarge ? QString() : QString::fromUtf8(raw);

        QJSValue metadata;
        if (auto* engine = qmlEngine(this))
            metadata = engine->toScriptValue(responseMetadata(reply));

        if (reply->error() == QNetworkReply::NoError && !tooLarge) {
            onSuccess.call({ body, metadata });
        } else if (onError.isCallable()) {
            onError.call({ tooLarge ? u"response too large"_s : reply->errorString(), metadata });
        } else {
            qCWarning(lcRequests) << "get: request failed with error" << reply->errorString();
        }

        reply->deleteLater();
    });
}

void Requests::resetCookies() const {
    m_manager->setCookieJar(new QNetworkCookieJar(m_manager));
}

} // namespace jellyface
