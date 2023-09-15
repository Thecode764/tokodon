// SPDX-FileCopyrightText: 2021 Carl Schwan <carlschwan@kde.org>
// SPDX-License-Identifier: LGPL-2.1-or-later

import QtQml 2.15
import QtQuick
import QtQuick.Controls 2 as QQC2
import QtQuick.Layouts
import Qt.labs.platform
import org.kde.kirigami 2 as Kirigami
import org.kde.tokodon
import org.kde.tokodon.private
import org.kde.kirigamiaddons.formcard 1 as FormCard

FormCard.FormCard {
    FormCard.FormSwitchDelegate {
        id: showStats
        text: i18n("Show detailed statistics about posts")
        checked: Config.showPostStats
        enabled: !Config.isShowPostStatsImmutable
        onToggled: {
            Config.showPostStats = checked
            Config.save()
        }
    }

    FormCard.FormDelegateSeparator { below: showStats; above: showLinkPreview }

    FormCard.FormSwitchDelegate {
        id: showLinkPreview
        text: i18n("Show link preview")
        checked: Config.showLinkPreview
        enabled: !Config.isShowLinkPreviewImmutable
        onToggled: {
            Config.showLinkPreview = checked
            Config.save()
        }
    }

    FormCard.FormDelegateSeparator { below: showStats; above: cropMedia }

    FormCard.FormSwitchDelegate {
        id: cropMedia
        text: i18n("Crop images in the timeline to 16:9")
        checked: Config.cropMedia
        onToggled: {
            Config.cropMedia = checked
            Config.save()
        }
    }

    FormCard.FormDelegateSeparator { below: cropMedia; above: autoPlayGif }

    FormCard.FormSwitchDelegate {
        id: autoPlayGif
        text: i18n("Auto-play animated GIFs")
        checked: Config.autoPlayGif
        onToggled: {
            Config.autoPlayGif = checked
            Config.save()
        }
    }

    FormCard.FormDelegateSeparator { below: autoPlayGif; above: colorTheme }

    FormCard.FormComboBoxDelegate {
        Layout.fillWidth: true
        id: colorTheme
        text: i18n("Color theme")
        textRole: "display"
        valueRole: "display"
        model: ColorSchemer.model
        Component.onCompleted: currentIndex = ColorSchemer.indexForScheme(Config.colorScheme);
        onCurrentValueChanged: {
            ColorSchemer.apply(currentIndex);
            Config.colorScheme = ColorSchemer.nameForIndex(currentIndex);
            Config.save();
        }
    }

    FormCard.FormDelegateSeparator { below: colorTheme; above: fontSelector }

    FormCard.FormButtonDelegate {
        id: fontSelector
        text: i18n("Content font")
        description: Config.defaultFont.family + " " + Config.defaultFont.pointSize + "pt"
        onClicked: fontDialog.open()

        FontDialog {
            id: fontDialog
            title: i18n("Please choose a font")
            font: Config.defaultFont
            onAccepted: {
                Config.defaultFont = font;
                Config.save();
            }
        }
    }
}
