// SPDX-FileCopyrightText: 2023 Joshua Goins <josh@redstrate.com>
// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL

import QtQuick
import QtQuick.Controls 2 as QQC2
import QtQuick.Layouts
import QtQml.Models

import org.kde.kirigami 2 as Kirigami
import org.kde.kirigamiaddons.formcard 1 as FormCard
import org.kde.kirigamiaddons.components 1 as Components

import org.kde.tokodon

MastoPage {
    id: root

    title: i18nc("@title:window", "Login")

    property var account

    data: Connections {
        target: Controller
        function onNetworkErrorOccurred(error) {
            message.text = i18nc("@info:status Network status", "Failed to contact server: %1. Please check your proxy settings.", error)
            message.visible = true;
        }
    }

    header: Components.Banner {
        id: message
        type: Kirigami.MessageType.Error
        width: parent.width

        showCloseButton: true

        actions: Kirigami.Action {
            text: i18n("Proxy Settings")
            icon.name: "settings-configure"
            onTriggered: pageStack.pushDialogLayer(Qt.createComponent("org.kde.tokodon", "NetworkProxyPage"))
        }
    }

    function _openWebViewAuthPage(): void {
        account.registered.disconnect(_openWebViewAuthPage);

        if (Window.window.pageStack.currentItem !== root) {
            Window.window.pageStack.pop();
        }

        Window.window.pageStack.push(Qt.createComponent("org.kde.tokodon", "WebViewAuthorization"), {
            account: account,
            loginPage: root
        });
    }

    function openWebViewAuthPage(): void {
        account.registerTokodon(false);
        account.registered.connect(_openWebViewAuthPage);
    }

    function _openBrowserAuthPage(): void {
        account.registered.disconnect(_openBrowserAuthPage);

        if (Window.window.pageStack.currentItem !== root) {
            Window.window.pageStack.pop();
        }

        Window.window.pageStack.push(Qt.createComponent("org.kde.tokodon", "BrowserAuthorization"), {
            account: account,
            loginPage: root
        });
    }

    function openBrowserAuthPage(): void {
        account.registerTokodon(false);
        account.registered.connect(_openBrowserAuthPage);
    }

    function _openCodeAuthPage(): void {
        account.registered.disconnect(_openCodeAuthPage);

        if (Window.window.pageStack.currentItem !== root) {
            Window.window.pageStack.pop();
        }

        Window.window.pageStack.push(Qt.createComponent("org.kde.tokodon", "CodeAuthorization"), {
            account: account,
            loginPage: root
        });
    }

    function openCodeAuthPage(): void {
        account.registerTokodon(true);
        account.registered.connect(_openCodeAuthPage);
    }

    Component.onCompleted: instanceUrl.forceActiveFocus()

    FormCard.FormHeader {
        title: i18nc("@title:group", "Login")
    }

    FormCard.FormCard {
        FormCard.FormTextFieldDelegate {
            id: instanceUrl
            label: i18n("Server URL:")
            placeholderText: i18n("mastodon.social")
            onAccepted: continueButton.clicked()
            inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
        }

        FormCard.FormDelegateSeparator { above: adminScopeDelegate }

        FormCard.FormCheckDelegate {
            id: adminScopeDelegate
            text: i18n("Enable moderation tools")
            description: i18n("Allow Tokodon to access moderation tools. Try disabling this if you have trouble logging in.")
            checked: true
        }

        FormCard.FormDelegateSeparator { above: continueButton }

        FormCard.FormButtonDelegate {
            id: continueButton
            text: i18n("Continue")
            onClicked: {
                instanceUrl.statusMessage = "";

                if (!instanceUrl.text) {
                    instanceUrl.status = Kirigami.MessageType.Error;
                    instanceUrl.statusMessage = i18n("Server URL must not be empty!");
                    return;
                }

                root.account = AccountManager.createNewAccount(instanceUrl.text, sslErrors.checked, adminScopeDelegate.checked);

                // Determine the best authorization type
                if (Kirigami.Settings.isMobile && Navigation.hasWebView()) {
                    // Prefer the in-app authorization if possible on mobile, it's the best.
                    openWebViewAuthPage();
                } else if (Navigation.isDebug()) {
                    // Prefer the auth code when debugging because it doesn't try to open the system Tokodon
                    openCodeAuthPage();
                } else {
                    openBrowserAuthPage();
                }
            }
        }
    }

    FormCard.FormHeader {
        title: i18nc("@title:group", "Network Settings")
    }

    FormCard.FormCard {
        FormCard.FormSwitchDelegate {
            id: sslErrors
            text: i18nc("@option:check Login page", "Ignore SSL errors")
        }

        FormCard.FormDelegateSeparator { above: proxySettingDelegate; below: sslErrors }

        FormCard.FormButtonDelegate {
            id: proxySettingDelegate
            text: i18n("Proxy Settings")
            onClicked: Window.window.pageStack.layers.push(Qt.createComponent("org.kde.tokodon", "NetworkProxyPage"))
        }
    }
}
