// SPDX-FileCopyrightText: 2021 kaniini <https://git.pleroma.social/kaniini>
// SPDX-FileCopyrightText: 2021 Carl Schwan <carlschwan@kde.org>
// SPDX-License-Identifier: GPL-3.0-only

#include "timelinemodel.h"
#include "abstractaccount.h"
#include "abstracttimelinemodel.h"
#include "accountmodel.h"
#include "identity.h"
#include "threadmodel.h"
#include <KLocalizedString>
#include <QtMath>
#include <QUrlQuery>

TimelineModel::TimelineModel(QObject *parent)
    : AbstractTimelineModel(parent)
    , m_last_fetch(time(nullptr))
{
}

void TimelineModel::setName(const QString &timelineName)
{
    if (timelineName == m_timelineName) {
        return;
    }

    m_timelineName = timelineName;
    Q_EMIT nameChanged();
}

QString TimelineModel::displayName() const
{
    if (m_timelineName == "home") {
        if (m_manager && m_manager->rowCount() > 1) {
            return i18nc("@title", "Home (%1)", m_manager->selectedAccount()->username());
        } else {
            return i18nc("@title", "Home");
        }
    } else if (m_timelineName == "public") {
        return i18nc("@title", "Local Timeline");
    } else if (m_timelineName == "federated") {
        return i18nc("@title", "Global Timeline");
    }
    return QString();
}

void TimelineModel::setAccountManager(AccountManager *accountManager)
{
    if (accountManager == m_manager) {
        return;
    }

    if (m_manager) {
        disconnect(m_manager, nullptr, this, nullptr);
    }

    m_manager = accountManager;
    m_account = m_manager->selectedAccount();

    Q_EMIT accountManagerChanged();

    QObject::connect(m_manager, &AccountManager::fetchedTimeline, this, &TimelineModel::fetchedTimeline);
    QObject::connect(m_manager, &AccountManager::invalidated, this, [=](AbstractAccount *account) {
        if (m_account == account) {
            qDebug() << "Invalidating account" << account;

            beginResetModel();
            m_timeline.clear();
            endResetModel();

            fillTimeline();
        }
    });

    fillTimeline();
}

AccountManager *TimelineModel::accountManager() const
{
    return m_manager;
}

QString TimelineModel::name() const
{
    return m_timelineName;
}

void TimelineModel::fillTimeline(const QString &from_id)
{
    if (m_timelineName != "home" && m_timelineName != "public" && m_timelineName != "federated") {
        return;
    }

    if (m_fetching) {
        return;
    }
    m_fetching = true;
    Q_EMIT fetchingChanged();

    if (m_account) {
        QString timelineName = m_timelineName;
        bool local = timelineName == "public";

        // federated timeline is really "public" without local set
        if (timelineName == "federated") {
            timelineName = "public";
        }

        QUrlQuery q;
        if (local) {
            q.addQueryItem("local", "true");
        }
        if (!from_id.isEmpty()) {
            q.addQueryItem("max_id", from_id);
        }

        auto uri = m_account->apiUrl(QString("/api/v1/timelines/%1").arg(m_timelineName));
        uri.setQuery(q);

        m_account->get(uri, true, [this, uri](QNetworkReply *reply) {
            QList<std::shared_ptr<Post>> posts;

            const auto data = reply->readAll();
            const auto doc = QJsonDocument::fromJson(data);

            if (!doc.isArray()) {
                return;
            }

            const auto array = doc.array();
            for (const auto &value : array) {
                const QJsonObject obj = value.toObject();

                const auto p = std::make_shared<Post>(m_account, obj, this);
                posts.push_back(p);
            }

            fetchedTimeline(m_account, m_timelineName, posts);
        });
    }
}

void TimelineModel::fetchMore(const QModelIndex &parent)
{
    Q_UNUSED(parent);

    if (m_timeline.size() < 1)
        return;

    auto p = m_timeline.last();

    fillTimeline(p->m_original_post_id);
}

bool TimelineModel::canFetchMore(const QModelIndex &parent) const
{
    Q_UNUSED(parent);

    if (m_fetching)
        return false;

    if (time(nullptr) <= m_last_fetch)
        return false;

    return true;
}

void TimelineModel::fetchedTimeline(AbstractAccount *account, const QString &original_name, const QList<std::shared_ptr<Post>> &posts)
{
    m_fetching = false;
    Q_EMIT fetchingChanged();

    m_loading = false;
    Q_EMIT loadingChanged();

    // make sure the timeline update is for us
    if (account != m_account || original_name != m_timelineName) {
        return;
    }

    if (posts.isEmpty()) {
        return;
    }

    if (!m_timeline.isEmpty()) {
        const auto post_old = m_timeline.first();
        const auto post_new = posts.first();

        qDebug() << "fetchedTimeline"
                 << "post_old->m_post_id" << post_old->m_post_id << "post_new->m_post_id" << post_new->m_post_id;
        if (post_old->m_post_id > post_new->m_post_id) {
            const int row = m_timeline.size();
            const int last = row + posts.size() - 1;
            beginInsertRows(QModelIndex(), row, last);
            m_timeline += posts;
            endInsertRows();
        } else {
            beginInsertRows(QModelIndex(), 0, posts.size() - 1);
            m_timeline = posts + m_timeline;
            endInsertRows();
        }
    } else {
        beginInsertRows(QModelIndex(), 0, posts.size() - 1);
        m_timeline = posts;
        endInsertRows();
    }

    m_last_fetch = time(nullptr);
}

int TimelineModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent)

    return m_timeline.size();
}

// this is even more extremely cursed
std::shared_ptr<Post> TimelineModel::internalData(const QModelIndex &index) const
{
    int row = index.row();
    return m_timeline[row];
}

QVariant TimelineModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid()) {
        return {};
    }
    int row = index.row();
    auto p = m_timeline[row];

    switch (role) {
    case TypeRole:
        return false;
    case IdRole:
        return p->m_post_id;
    case Qt::DisplayRole:
        return p->m_content;
    case AvatarRole:
        return p->authorIdentity()->avatarUrl();
    case AuthorDisplayNameRole:
        return p->authorIdentity()->displayNameHtml();
    case AuthorIdRole:
        return p->authorIdentity()->account();
    case PublishedAtRole:
        return p->m_published_at;
    case WasRebloggedRole:
        return p->m_repeat;
    case MentionsRole:
        return p->mentions();
    case RebloggedDisplayNameRole:
        if (p->repeatIdentity()) {
            return p->repeatIdentity()->displayNameHtml();
        }
        return {};
    case RebloggedIdRole:
        if (p->repeatIdentity()) {
            return p->repeatIdentity()->account();
        }
        return {};
    case RebloggedRole:
        return p->m_isRepeated;
    case ReblogsCountRole:
        return p->m_repeatedCount;
    case FavoritedRole:
        return p->m_isFavorite;
    case FavoritesCountRole:
        return p->m_favoriteCount;
    case PinnedRole:
        return p->m_pinned;
    case SensitiveRole:
        return p->m_isSensitive;
    case RepliesCountRole:
        return p->m_repliesCount;
    case SpoilerTextRole:
        return p->m_subject;
    case AttachmentsRole:
        return QVariant::fromValue<QList<Attachment *>>(p->m_attachments);
    case CardRole:
        if (p->card().has_value()) {
            return QVariant::fromValue<Card>(*p->card());
        }
        return false;
    case ThreadModelRole:
        return QVariant::fromValue<QAbstractListModel *>(new ThreadModel(m_manager, p->m_post_id));
    case AccountModelRole:
        return QVariant::fromValue<QAbstractListModel *>(new AccountModel(m_manager, p->authorIdentity()->id(), p->authorIdentity()->account()));
    case RelativeTimeRole: {
        const auto current = QDateTime::currentDateTime();
        auto secsTo = p->m_published_at.secsTo(current);
        if (secsTo < 60 * 60) {
            const auto hours = p->m_published_at.time().hour();
            const auto minutes = p->m_published_at.time().minute();
            return i18nc("hour:minute",
                         "%1:%2",
                         hours < 10 ? QChar('0') + QString::number(hours) : QString::number(hours),
                         minutes < 10 ? QChar('0') + QString::number(minutes) : QString::number(minutes));
        } else if (secsTo < 60 * 60 * 24) {
            return i18n("%1h", qCeil(secsTo / (60 * 60)));
        } else if (secsTo < 60 * 60 * 24 * 7) {
            return i18n("%1d", qCeil(secsTo / (60 * 60 * 24)));
        }
        return QLocale::system().toString(p->m_published_at.date(), QLocale::ShortFormat);
    }
    }

    return {};
}

void TimelineModel::actionReply(const QModelIndex &index)
{
    int row = index.row();
    auto p = m_timeline[row];

    Q_EMIT wantReply(m_account, p, index);
}

void TimelineModel::actionMenu(const QModelIndex &index)
{
    int row = index.row();
    auto p = m_timeline[row];

    Q_EMIT wantMenu(m_account, p, index);
}

void TimelineModel::actionFavorite(const QModelIndex &index)
{
    int row = index.row();
    auto p = m_timeline[row];

    if (!p->m_isFavorite) {
        m_account->favorite(p);
        p->m_isFavorite = true;
    } else {
        m_account->unfavorite(p);
        p->m_isFavorite = false;
    }

    Q_EMIT dataChanged(index, index);
}

void TimelineModel::actionRepeat(const QModelIndex &index)
{
    int row = index.row();
    auto p = m_timeline[row];

    if (!p->m_isRepeated) {
        m_account->repeat(p);
        p->m_isRepeated = true;
    } else {
        m_account->unrepeat(p);
        p->m_isRepeated = false;
    }

    Q_EMIT dataChanged(index, index);
}

void TimelineModel::actionVis(const QModelIndex &index)
{
    int row = index.row();
    auto p = m_timeline[row];

    p->m_attachments_visible ^= true;

    Q_EMIT dataChanged(index, index);
}

void TimelineModel::refresh()
{
    fillTimeline();
}

bool TimelineModel::fetching() const
{
    return m_fetching;
}
