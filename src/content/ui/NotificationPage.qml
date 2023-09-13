// SPDX-FileCopyrightText: 2021 Carl Schwan <carl@carlschwan.eu>
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls 2 as QQC2
import QtQuick.Layouts
import Qt.labs.qmlmodels 1.0
import org.kde.kirigami 2 as Kirigami
import org.kde.kmasto
import "./StatusDelegate"
import "./StatusComposer"

Kirigami.ScrollablePage {
    id: timelinePage
    title: i18n("Notifications")

    property var dialog: null

    property alias listViewHeader: listview.header
    readonly property bool typesAreGroupable: !mentionOnlyAction.checked && !followsOnlyAction.checked && !pollResultsOnlyAction.checked
    property bool shouldGroupNotifications: groupNotificationsAction.checked && typesAreGroupable
    readonly property var currentModel: shouldGroupNotifications ? groupedNotificationModel : notificationModel

    onBackRequested: if (dialog) {
        dialog.close();
        dialog = null;
        event.accepted = true;
    }

    actions: Kirigami.Action {
        id: groupNotificationsAction

        icon.name: "view-visible"

        displayComponent: QQC2.Switch {
            text: i18n("Group Notifications")
            enabled: typesAreGroupable
            onToggled: groupNotificationsAction.checked = checked
        }
    }

    property Kirigami.Action showAllAction: Kirigami.Action {
        id: showAllAction
        text: i18nc("Show all notifications", "All")
        icon.name: "notifications"
        checkable: true
        checked: true
        onCheckedChanged: if (checked) {
            notificationModel.excludeTypes = []
        }
    }

    property Kirigami.Action mentionOnlyAction: Kirigami.Action {
        id: onlyMentionAction
        text: i18nc("Show only mentions", "Mentions")
        icon.name: "tokodon-chat-reply"
        checkable: true
        onCheckedChanged: if (checked) {
            notificationModel.excludeTypes = ['status', 'reblog', 'follow', 'follow_request', 'favourite', 'poll', 'update']
        }
    }

    property Kirigami.Action boostsOnlyAction: Kirigami.Action {
        text: i18nc("Show only boosts", "Boosts")
        icon.name: "post-boost"
        checkable: true
        onCheckedChanged: if (checked) {
            notificationModel.excludeTypes = ['mention', 'status', 'follow', 'follow_request', 'favourite', 'poll', 'update']
        }
    }

    property Kirigami.Action favoritesOnlyAction: Kirigami.Action {
        text: i18nc("Show only favorites", "Favorites")
        icon.name: "post-favorite"
        checkable: true
        onCheckedChanged: if (checked) {
            notificationModel.excludeTypes = ['mention', 'status', 'reblog', 'follow', 'follow_request', 'poll', 'update']
        }
    }

    property Kirigami.Action pollResultsOnlyAction: Kirigami.Action {
        text: i18nc("Show only poll results", "Poll Results")
        icon.name: "office-chart-bar"
        checkable: true
        onCheckedChanged: if (checked) {
            notificationModel.excludeTypes = ['mention', 'status', 'reblog', 'follow', 'follow_request', 'favourite', 'update']
        }
    }

    property
    Kirigami.Action
    postsOnlyAction: Kirigami.Action
    {
        text: i18nc("Show only followed statuses", "Posts")
        icon.name: "user-home-symbolic"
        checkable: true
        onCheckedChanged: if (checked) {
            notificationModel.excludeTypes = ['mention', 'reblog', 'follow', 'follow_request', 'favourite', 'poll', 'update']
        }
    }

    property Kirigami.Action followsOnlyAction: Kirigami.Action {
        text: i18nc("Show only follows", "Follows")
        icon.name: "list-add-user"
        checkable: true
        onCheckedChanged: if (checked) {
            notificationModel.excludeTypes = ['mention', 'status', 'reblog', 'follow_request', 'favourite', 'poll', 'update']
        }
    }

    header: Kirigami.NavigationTabBar {
        anchors.left: parent.left
        anchors.right: parent.right
        actions: [showAllAction, mentionOnlyAction, favoritesOnlyAction, boostsOnlyAction, pollResultsOnlyAction, postsOnlyAction, followsOnlyAction]
    }

    NotificationModel {
        id: notificationModel
    }

    NotificationGroupingModel {
        id: groupedNotificationModel
        sourceModel: notificationModel
    }

    ListView {
        id: listview
        model: timelinePage.currentModel

        Connections {
            target: Navigation
            function onOpenFullScreenImage(attachments, identity, currentIndex) {
                if (timelinePage.isCurrentPage) {
                    timelinePage.dialog = fullScreenImage.createObject(parent, {
                        attachments: attachments,
                        identity: identity,
                        initialIndex: currentIndex,
                    });
                    timelinePage.dialog.open();
                }
            }
        }

        Connections {
            target: timelinePage.currentModel
            function onPostSourceReady(backend) {
                pageStack.layers.push("./StatusComposer/StatusComposer.qml", {
                    purpose: StatusComposer.Edit,
                    backend: backend
                });
            }
        }

        Component {
            id: fullScreenImage
            FullScreenImage {}
        }
        delegate: DelegateChooser {
            role: "type"
            DelegateChoice {
                roleValue: Notification.Favorite
                StatusDelegate {
                    secondary: true
                    timelineModel: notificationModel
                    loading: listview.model.loading
                    showSeparator: index !== ListView.view.count - 1
                }
            }

            DelegateChoice {
                roleValue: Notification.Repeat
                StatusDelegate {
                    secondary: true
                    timelineModel: notificationModel
                    loading: listview.model.loading
                    showSeparator: index !== ListView.view.count - 1
                }
            }

            DelegateChoice {
                roleValue: Notification.Mention
                StatusDelegate {
                    timelineModel: notificationModel
                    loading: listview.model.loading
                    showSeparator: index !== ListView.view.count - 1
                }
            }

            DelegateChoice {
                roleValue: Notification.Follow
                FollowDelegate {}
            }
            DelegateChoice {
                roleValue: Notification.Update
                StatusDelegate {
                    secondary: true
                    timelineModel: notificationModel
                    loading: listview.model.loading
                    showSeparator: index !== ListView.view.count - 1
                }
            }

            DelegateChoice {
                roleValue: Notification.Poll
                StatusDelegate {
                    secondary: true
                    timelineModel: notificationModel
                    loading: listview.model.loading
                    showSeparator: index !== ListView.view.count - 1
                }
            }
        }

        QQC2.ProgressBar {
            visible: listview.model.loading && listview.count === 0
            anchors.centerIn: parent
            indeterminate: true
        }

        Kirigami.PlaceholderMessage {
            anchors.centerIn: parent
            text: i18n("No Notifications")
            visible: listview.count === 0 && !timelinePage.currentModel.loading
        }
    }
}
