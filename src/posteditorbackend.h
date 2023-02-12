// SPDX-FileCopyrightText: 2022 Carl Schwan <carl@carlschwan.eu>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "post.h"
#include <QObject>
#include <memory>

class AttachmentEditorModel;

class PostEditorBackend : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString status READ status WRITE setStatus NOTIFY statusChanged)
    Q_PROPERTY(QString inReplyTo READ inReplyTo WRITE setInReplyTo NOTIFY inReplyToChanged)
    Q_PROPERTY(QString spoilerText READ spoilerText WRITE setSpoilerText NOTIFY spoilerTextChanged)
    Q_PROPERTY(Post::Visibility visibility READ visibility WRITE setVisibility NOTIFY visibilityChanged)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(QDateTime scheduledAt READ scheduledAt WRITE setScheduledAt NOTIFY scheduledAtChanged)
    Q_PROPERTY(QStringList mentions READ mentions WRITE setMentions NOTIFY mentionsChanged)
    Q_PROPERTY(AttachmentEditorModel *attachmentEditorModel READ attachmentEditorModel CONSTANT)
    Q_PROPERTY(bool sensitive READ sensitive WRITE setSensitive NOTIFY sensitiveChanged)

    Q_PROPERTY(AbstractAccount *account READ account WRITE setAccount NOTIFY accountChanged)

public:
    explicit PostEditorBackend(QObject *parent = nullptr);
    ~PostEditorBackend();

    QString status() const;
    void setStatus(const QString &status);

    QString spoilerText() const;
    void setSpoilerText(const QString &spoilerText);

    QString inReplyTo() const;
    void setInReplyTo(const QString &inReplyTo);

    Post::Visibility visibility() const;
    void setVisibility(Post::Visibility visibility);

    QString language() const;
    void setLanguage(const QString &language);

    QDateTime scheduledAt() const;
    void setScheduledAt(const QDateTime &scheduledAt);

    QStringList mentions() const;
    void setMentions(const QStringList &mentions);

    AttachmentEditorModel *attachmentEditorModel() const;

    bool sensitive() const;
    void setSensitive(bool sensitive);

    AbstractAccount *account() const;
    void setAccount(AbstractAccount *account);

public Q_SLOTS:
    void save();

Q_SIGNALS:

    void statusChanged();

    void spoilerTextChanged();

    void inReplyToChanged();

    void visibilityChanged();

    void languageChanged();

    void scheduledAtChanged();

    void mentionsChanged();

    void accountChanged();

    void sensitiveChanged();

    void posted(QString error);

private:
    QJsonDocument toJsonDocument() const;

    QString m_status;
    QString m_idenpotencyKey;
    QString m_spoilerText;
    QString m_inReplyTo;
    QString m_language;
    QDateTime m_scheduledAt;
    QStringList m_mentions;
    bool m_sensitive = false;
    Post::Visibility m_visibility;
    AbstractAccount *m_account = nullptr;
    AttachmentEditorModel *m_attachmentEditorModel = nullptr;
};