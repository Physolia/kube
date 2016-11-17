/*
    Copyright (c) 2016 Michael Bohlender <michael.bohlender@kdemail.net>

    This library is free software; you can redistribute it and/or modify it
    under the terms of the GNU Library General Public License as published by
    the Free Software Foundation; either version 2 of the License, or (at your
    option) any later version.

    This library is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
    FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Library General Public
    License for more details.

    You should have received a copy of the GNU Library General Public License
    along with this library; see the file COPYING.LIB.  If not, write to the
    Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
    02110-1301, USA.
*/


#include "composercontroller.h"
#include <actions/context.h>
#include <actions/action.h>
#include <settings/settings.h>
#include <KMime/Message>
#include <KCodecs/KEmailAddress>
#include <QVariant>
#include <QSortFilterProxyModel>
#include <QList>
#include <QDebug>
#include <QQmlEngine>
#include <sink/store.h>
#include <sink/log.h>

#include "accountsmodel.h"
#include "identitiesmodel.h"
#include "recepientautocompletionmodel.h"
#include "mailtemplates.h"

SINK_DEBUG_AREA("composercontroller");

ComposerController::ComposerController(QObject *parent) : QObject(parent)
{
}

QString ComposerController::to() const
{
    return m_to;
}

void ComposerController::setTo(const QString &to)
{
    if(m_to != to) {
        m_to = to;
        emit toChanged();
    }
}

QString ComposerController::cc() const
{
    return m_cc;
}

void ComposerController::setCc(const QString &cc)
{
    if(m_cc != cc) {
        m_cc = cc;
        emit ccChanged();
    }
}

QString ComposerController::bcc() const
{
    return m_bcc;
}

void ComposerController::setBcc(const QString &bcc)
{
    if(m_bcc != bcc) {
        m_bcc = bcc;
        emit bccChanged();
    }
}

QString ComposerController::subject() const
{
    return m_subject;
}

void ComposerController::setSubject(const QString &subject)
{
    if(m_subject != subject) {
        m_subject = subject;
        emit subjectChanged();
    }
}

QString ComposerController::body() const
{
    return m_body;
}

void ComposerController::setBody(const QString &body)
{
    if(m_body != body) {
        m_body = body;
        emit bodyChanged();
    }
}

QString ComposerController::recepientSearchString() const
{
    return QString();
}

void ComposerController::setRecepientSearchString(const QString &s)
{
    if (auto model = static_cast<RecipientAutocompletionModel*>(recepientAutocompletionModel())) {
        model->setFilter(s);
    }
}

QAbstractItemModel *ComposerController::identityModel() const
{
    static auto model = new IdentitiesModel();
    QQmlEngine::setObjectOwnership(model, QQmlEngine::CppOwnership);
    return model;
}

QAbstractItemModel *ComposerController::recepientAutocompletionModel() const
{
    static auto model = new RecipientAutocompletionModel();
    QQmlEngine::setObjectOwnership(model, QQmlEngine::CppOwnership);
    return model;
}

QStringList ComposerController::attachemts() const
{
    return m_attachments;
}

void ComposerController::addAttachment(const QUrl &fileUrl)
{
    m_attachments.append(fileUrl.toString());
    emit attachmentsChanged();
}

void ComposerController::setMessage(const KMime::Message::Ptr &msg)
{
    setTo(msg->to(true)->asUnicodeString());
    setCc(msg->cc(true)->asUnicodeString());
    setSubject(msg->subject(true)->asUnicodeString());
    setBody(msg->body());
    m_msg = QVariant::fromValue(msg);
}

void ComposerController::loadMessage(const QVariant &message, bool loadAsDraft)
{
    Sink::Query query(*message.value<Sink::ApplicationDomain::Mail::Ptr>());
    query.request<Sink::ApplicationDomain::Mail::MimeMessage>();
    Sink::Store::fetchOne<Sink::ApplicationDomain::Mail>(query).syncThen<void, Sink::ApplicationDomain::Mail>([this, loadAsDraft](const Sink::ApplicationDomain::Mail &mail) {
        m_existingMail = mail;
        const auto mailData = KMime::CRLFtoLF(mail.getMimeMessage());
        if (!mailData.isEmpty()) {
            KMime::Message::Ptr mail(new KMime::Message);
            mail->setContent(mailData);
            mail->parse();
            if (loadAsDraft) {
                auto reply = MailTemplates::reply(mail);
                //We assume reply
                setMessage(reply);
            } else {
                setMessage(mail);
            }
        } else {
            qWarning() << "Retrieved empty message";
        }
    }).exec();
}

void ComposerController::recordForAutocompletion(const QByteArray &addrSpec, const QByteArray &displayName)
{
    if (auto model = static_cast<RecipientAutocompletionModel*>(recepientAutocompletionModel())) {
        model->addEntry(addrSpec, displayName);
    }
}

void applyAddresses(const QString &list, std::function<void(const QByteArray &, const QByteArray &)> callback)
{
    for (const auto &to : KEmailAddress::splitAddressList(list)) {
        QByteArray displayName;
        QByteArray addrSpec;
        QByteArray comment;
        KEmailAddress::splitAddress(to.toUtf8(), displayName, addrSpec, comment);
        callback(addrSpec, displayName);
    }
}

bool ComposerController::identityIsSet() const
{
    return (identityModel()->rowCount() > 0) && (m_currentAccountIndex >= 0);
}

KMime::Message::Ptr ComposerController::assembleMessage()
{
    auto mail = m_msg.value<KMime::Message::Ptr>();
    if (!mail) {
        mail = KMime::Message::Ptr::create();
    }
    applyAddresses(m_to, [&](const QByteArray &addrSpec, const QByteArray &displayName) {
        mail->to(true)->addAddress(addrSpec, displayName);
        recordForAutocompletion(addrSpec, displayName);
    });
    applyAddresses(m_cc, [&](const QByteArray &addrSpec, const QByteArray &displayName) {
        mail->cc(true)->addAddress(addrSpec, displayName);
        recordForAutocompletion(addrSpec, displayName);
    });
    applyAddresses(m_bcc, [&](const QByteArray &addrSpec, const QByteArray &displayName) {
        mail->bcc(true)->addAddress(addrSpec, displayName);
        recordForAutocompletion(addrSpec, displayName);
    });
    if (!identityIsSet()) {
        SinkWarning() << "We don't have an identity to send the mail with.";
    } else {
        auto currentIndex = identityModel()->index(m_currentAccountIndex, 0);
        KMime::Types::Mailbox mb;
        mb.setName(currentIndex.data(IdentitiesModel::Username).toString());
        mb.setAddress(currentIndex.data(IdentitiesModel::Address).toString().toUtf8());
        mail->from(true)->addAddress(mb);
        mail->subject(true)->fromUnicodeString(m_subject, "utf-8");
        mail->setBody(m_body.toUtf8());
        mail->assemble();
        return mail;
    }
    return KMime::Message::Ptr();
}

void ComposerController::send()
{
    auto mail = assembleMessage();

    //TODO deactivate action if we don't have the identiy set
    if (!identityIsSet()) {
        SinkWarning() << "We don't have an identity to send the mail with.";
    } else {
        auto currentAccountId = identityModel()->index(m_currentAccountIndex, 0).data(IdentitiesModel::AccountId).toByteArray();

        Kube::Context context;
        context.setProperty("message", QVariant::fromValue(mail));
        context.setProperty("accountId", QVariant::fromValue(currentAccountId));

        qDebug() << "Current account " << currentAccountId;

        Kube::Action("org.kde.kube.actions.sendmail", context).execute();
        clear();
    }
}

void ComposerController::saveAsDraft()
{
    auto mail = assembleMessage();
    auto currentAccountId = identityModel()->index(m_currentAccountIndex, 0).data(IdentitiesModel::AccountId).toByteArray();

    Kube::Context context;
    context.setProperty("message", QVariant::fromValue(mail));
    context.setProperty("accountId", QVariant::fromValue(currentAccountId));
    context.setProperty("existingMail", QVariant::fromValue(m_existingMail));
    Kube::Action("org.kde.kube.actions.save-as-draft", context).execute();
    clear();
}

void ComposerController::clear()
{
    setSubject("");
    setBody("");
    setTo("");
    setCc("");
    setBcc("");
}
