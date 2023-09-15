// SPDX-FileCopyrightText: 2023 Carl Schwan <carl@carlschwan.eu>
// SPDX-License-Identifier: LGPL-2.0-or-later

import QtQuick
import org.kde.tokodon

TimelinePage {
    id: root

    required property string postId

    expandedPost: true
    showPostAction: false

    model: ThreadModel {
        postId: root.postId
    }
}
