// Copyright (c) 2026, The Salvium developers
// SPDX-License-Identifier: BSD-3-Clause

import QtQuick 2.9
import QtQuick.Controls 2.0
import QtQuick.Layouts 1.1

import "../components" as MoneroComponents
import moneroComponents.Clipboard 1.0

Rectangle {
    id: root
    color: "transparent"

    property int chatHeight: Math.max(680, height)
    property var serviceStatus: ({})
    property string selectedContactId: ""
    property string selectedContactLabel: ""
    property bool selectedContactBlocked: false
    property string noticeText: ""
    property bool noticeError: false
    property string pendingDeleteMessageId: ""
    property string pendingRemoveContactId: ""
    property bool addingQuarantinedContact: false
    property bool walletReady: typeof currentWallet !== "undefined" && currentWallet !== null
    property bool statusBusy: false
    property bool receiveBusy: false
    property bool sendBusy: false
    property bool receiveAfterStatus: false
    property bool silentReceive: true

    Clipboard { id: clipboard }
    ListModel { id: contactsModel }
    ListModel { id: messagesModel }
    ListModel { id: quarantineModel }

    function showNotice(text, error) {
        noticeText = text
        noticeError = error === true
        noticeTimer.restart()
    }

    function displayError(result, fallback) {
        var detail = result && result.error ? result.error : fallback
        showNotice(detail || qsTr("The messaging operation failed."), true)
    }

    function onPageCompleted() {
        refreshAll(true)
    }

    function onPageClosed() {
        receiveAfterStatus = false
    }

    function refreshAll(receiveFirst) {
        if (!walletReady)
            return

        var identity = currentWallet.salchatGetIdentity()
        if (!identity.success) {
            displayError(identity, qsTr("Could not read the messaging identity."))
            return
        }
        serviceStatus = {
            "identityInitialized": identity.initialized === true,
            "daemonAvailable": serviceStatus.daemonAvailable === true,
            "daemonEnabled": serviceStatus.daemonEnabled === true,
            "contacts": serviceStatus.contacts || 0,
            "messages": serviceStatus.messages || 0,
            "cachedMessages": serviceStatus.cachedMessages || 0,
            "error": serviceStatus.error || ""
        }
        if (!identity.initialized) {
            contactsModel.clear()
            messagesModel.clear()
            quarantineModel.clear()
            selectedContactId = ""
            return
        }

        refreshContacts()
        refreshMessages()
        refreshQuarantine()
        requestStatus(receiveFirst)
    }

    function requestStatus(receiveWhenReady) {
        if (!walletReady || statusBusy || !serviceStatus.identityInitialized)
            return

        receiveAfterStatus = receiveWhenReady === true
        statusBusy = currentWallet.salchatStatusAsync()
        if (!statusBusy) {
            receiveAfterStatus = false
            showNotice(qsTr("Could not start the daemon status check."), true)
        }
    }

    function refreshContacts() {
        if (!walletReady)
            return

        var previousId = selectedContactId
        var contacts = currentWallet.salchatContacts()
        contactsModel.clear()
        for (var i = 0; i < contacts.length; ++i)
            contactsModel.append(contacts[i])

        var selectedIndex = -1
        for (var j = 0; j < contactsModel.count; ++j) {
            if (contactsModel.get(j).contactId === previousId) {
                selectedIndex = j
                break
            }
        }
        if (selectedIndex < 0 && contactsModel.count > 0)
            selectedIndex = 0

        if (selectedIndex >= 0)
            selectContact(selectedIndex)
        else {
            selectedContactId = ""
            selectedContactLabel = ""
            selectedContactBlocked = false
            messagesModel.clear()
        }
    }

    function selectContact(index) {
        if (index < 0 || index >= contactsModel.count)
            return
        var contact = contactsModel.get(index)
        selectedContactId = contact.contactId
        selectedContactLabel = contact.label
        selectedContactBlocked = contact.blocked
        contactsList.currentIndex = index
        refreshMessages()
    }

    function refreshMessages() {
        messagesModel.clear()
        if (!walletReady || selectedContactId === "")
            return

        var messages = currentWallet.salchatMessages(selectedContactId, 500)
        for (var i = messages.length - 1; i >= 0; --i) {
            if (messages[i].typeName === "text")
                messagesModel.append(messages[i])
        }
        if (messagesModel.count > 0)
            messagesList.positionViewAtEnd()
    }

    function refreshQuarantine() {
        quarantineModel.clear()
        if (!walletReady)
            return

        var messages = currentWallet.salchatMessages("", 500)
        for (var i = messages.length - 1; i >= 0; --i) {
            if (messages[i].typeName === "text" && messages[i].stateName === "quarantined")
                quarantineModel.append(messages[i])
        }
    }

    function contactLabel(contactId) {
        for (var i = 0; i < contactsModel.count; ++i) {
            var contact = contactsModel.get(i)
            if (contact.contactId === contactId)
                return contact.label
        }
        return qsTr("Unknown")
    }

    function waitingNotice(newMessages) {
        var counts = ({})
        var labels = ({})
        var order = []
        for (var i = 0; i < newMessages.length; ++i) {
            var message = newMessages[i]
            if (counts[message.contactId] === undefined) {
                counts[message.contactId] = 0
                labels[message.contactId] = message.stateName === "quarantined"
                        ? qsTr("Unknown") : contactLabel(message.contactId)
                order.push(message.contactId)
            }
            counts[message.contactId] += 1
        }
        var notices = []
        for (var j = 0; j < order.length; ++j) {
            var id = order[j]
            if (counts[id] === 1)
                notices.push(qsTr("Message waiting from %1.").arg(labels[id]))
            else
                notices.push(qsTr("%1 messages waiting from %2.").arg(counts[id]).arg(labels[id]))
        }
        return notices.join(" ")
    }

    function addQuarantinedSender(contactId) {
        addingQuarantinedContact = true
        contactLabelInput.text = ""
        contactAddressInput.text = contactId
        addContactPopup.open()
        contactLabelInput.forceActiveFocus()
    }

    function receiveMessages(silent) {
        if (!walletReady || !serviceStatus.identityInitialized || receiveBusy)
            return

        silentReceive = silent === true
        receiveBusy = currentWallet.salchatReceiveMessagesAsync(100)
        if (!receiveBusy) {
            if (!silentReceive)
                showNotice(qsTr("Could not start the message check."), true)
        }
    }

    function showAddress() {
        if (!walletReady)
            return
        var identity = currentWallet.salchatGetIdentity()
        if (!identity.success || !identity.initialized || identity.encryptionPublicKey === "") {
            displayError(identity, qsTr("Could not read your Salchat identity."))
            return
        }
        addressOutput.text = identity.salviumAddress + ":" + identity.encryptionPublicKey
        ownAddressPopup.open()
    }

    function addContact() {
        var label = contactLabelInput.text.trim()
        var addressOrContactId = contactAddressInput.text.trim()
        if (label === "" || addressOrContactId === "") {
            showNotice(qsTr("Enter a display name and a contact ID or main Carrot SC address."), true)
            return
        }
        var result = currentWallet.salchatAddContact(label, addressOrContactId)
        if (!result.success) {
            displayError(result, qsTr("Could not add that contact."))
            return
        }
        selectedContactId = result.contactId
        contactLabelInput.text = ""
        contactAddressInput.text = ""
        addingQuarantinedContact = false
        addContactPopup.close()
        refreshContacts()
        refreshQuarantine()
        var promoted = result.promotedMessages || 0
        if (promoted === 1)
            showNotice(qsTr("Contact added. One quarantined message is now available."), false)
        else if (promoted > 1)
            showNotice(qsTr("Contact added. %1 quarantined messages are now available.").arg(promoted), false)
        else
            showNotice(qsTr("Contact added."), false)
        if (promoted > 0)
            receiveMessages(true)
    }

    function toggleBlockContact() {
        if (!walletReady || selectedContactId === "")
            return
        var result = currentWallet.salchatBlockContact(selectedContactId, !selectedContactBlocked)
        if (!result.success) {
            displayError(result, qsTr("Could not update this contact."))
            return
        }
        refreshContacts()
        showNotice(selectedContactBlocked ? qsTr("Contact blocked.") : qsTr("Contact unblocked."), false)
    }

    function sendMessage() {
        var message = messageInput.text.trim()
        if (!walletReady || selectedContactId === "" || message === "" || sendBusy)
            return

        sendBusy = currentWallet.salchatSendMessageAsync(selectedContactId, message, 604800)
        if (!sendBusy) {
            showNotice(qsTr("Could not start message submission."), true)
        }
    }

    Connections {
        target: root.walletReady ? currentWallet : null

        onSalchatStatusFinished: {
            root.statusBusy = false
            root.serviceStatus = result
            var shouldReceive = root.receiveAfterStatus
            root.receiveAfterStatus = false
            if (shouldReceive && result.daemonAvailable && result.daemonEnabled)
                root.receiveMessages(true)
        }

        onSalchatReceiveMessagesFinished: {
            root.receiveBusy = false
            root.refreshMessages()
            root.refreshQuarantine()
            if (!result.success) {
                if (!root.silentReceive)
                    root.displayError(result, qsTr("Could not check for messages."))
                return
            }
            if (result.newMessages && result.newMessages.length > 0) {
                root.showNotice(root.waitingNotice(result.newMessages), false)
            } else if (!root.silentReceive) {
                var summary = qsTr("Received %1 new message(s).").arg(result.received)
                if (result.quarantined > 0)
                    summary += " " + qsTr("%1 item(s) were quarantined.").arg(result.quarantined)
                root.showNotice(summary, false)
            }
        }

        onSalchatSendMessageFinished: {
            root.sendBusy = false
            if (!result.submitted) {
                root.displayError(result, qsTr("Message submission failed."))
                root.refreshMessages()
                return
            }
            messageInput.text = ""
            root.refreshMessages()
            root.showNotice(qsTr("Encrypted message submitted."), false)
        }
    }

    Timer {
        id: noticeTimer
        interval: 5000
        onTriggered: noticeText = ""
    }

    Timer {
        interval: 10000
        repeat: true
        running: root.visible && root.walletReady && root.serviceStatus.identityInitialized === true
        onTriggered: {
            if (root.statusBusy || root.receiveBusy || root.sendBusy)
                return
            // Expire local history even while the daemon is unavailable.
            refreshMessages()
            refreshQuarantine()
            requestStatus(true)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.topMargin: 24
        anchors.bottomMargin: 20
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: qsTr("Salchat") + translationManager.emptyString
                    color: MoneroComponents.Style.defaultFontColor
                    font.family: MoneroComponents.Style.fontRegular.name
                    font.pixelSize: 32
                }

                Text {
                    text: qsTr("Private, authenticated messages relayed by Salvium nodes") + translationManager.emptyString
                    color: MoneroComponents.Style.dimmedFontColor
                    font.family: MoneroComponents.Style.fontRegular.name
                    font.pixelSize: 14
                }
            }

            Rectangle {
                width: statusRow.width + 22
                height: 30
                radius: 15
                color: MoneroComponents.Style.titleBarButtonHoverColor
                border.color: MoneroComponents.Style.inputBorderColorInActive

                Row {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: 7

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: serviceStatus.daemonAvailable && serviceStatus.daemonEnabled ? "#18b77e" : MoneroComponents.Style.errorColor
                    }

                    Text {
                        text: {
                            if (!serviceStatus.identityInitialized)
                                return qsTr("Not set up")
                            if (!serviceStatus.daemonAvailable)
                                return qsTr("Daemon unavailable")
                            if (!serviceStatus.daemonEnabled)
                                return qsTr("Messaging disabled")
                            return qsTr("Online")
                        }
                        color: MoneroComponents.Style.defaultFontColor
                        font.family: MoneroComponents.Style.fontRegular.name
                        font.pixelSize: 13
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: noticeText === "" ? 0 : noticeLabel.implicitHeight + 18
            visible: noticeText !== ""
            radius: 4
            color: noticeError ? "#22fa6800" : "#2218b77e"
            border.color: noticeError ? MoneroComponents.Style.errorColor : "#18b77e"

            Text {
                id: noticeLabel
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 10
                text: noticeText
                textFormat: Text.PlainText
                color: MoneroComponents.Style.defaultFontColor
                font.family: MoneroComponents.Style.fontRegular.name
                font.pixelSize: 14
                wrapMode: Text.WordWrap
            }
        }

        MoneroComponents.WarningBox {
            visible: serviceStatus.identityInitialized === true && (!serviceStatus.daemonAvailable || !serviceStatus.daemonEnabled)
            text: serviceStatus.error ? serviceStatus.error : qsTr("Connect to a Salchat-enabled daemon to send and receive messages.")
            textFormat: Text.PlainText
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: serviceStatus.identityInitialized !== true

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(560, parent.width - 40)
                spacing: 16

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Carrot identity unavailable") + translationManager.emptyString
                    color: MoneroComponents.Style.defaultFontColor
                    font.family: MoneroComponents.Style.fontRegular.name
                    font.pixelSize: 26
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Salchat uses this wallet's main Carrot address and incoming-view key. This wallet does not currently expose a usable Carrot incoming-view key.") + translationManager.emptyString
                    color: MoneroComponents.Style.dimmedFontColor
                    font.family: MoneroComponents.Style.fontRegular.name
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14
            visible: serviceStatus.identityInitialized === true

            Rectangle {
                Layout.preferredWidth: Math.min(245, Math.max(190, root.width * 0.28))
                Layout.fillHeight: true
                radius: 6
                color: MoneroComponents.Style.titleBarButtonHoverColor
                border.color: MoneroComponents.Style.inputBorderColorInActive

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Contacts") + translationManager.emptyString
                            color: MoneroComponents.Style.defaultFontColor
                            font.family: MoneroComponents.Style.fontRegular.name
                            font.bold: true
                            font.pixelSize: 17
                        }

                        MoneroComponents.StandardButton {
                            small: true
                            text: qsTr("Add") + translationManager.emptyString
                            onClicked: {
                                addingQuarantinedContact = false
                                contactLabelInput.text = ""
                                contactAddressInput.text = ""
                                addContactPopup.open()
                            }
                        }
                    }

                    ListView {
                        id: contactsList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 3
                        model: contactsModel
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            width: contactsList.width
                            height: 52
                            radius: 4
                            color: index === contactsList.currentIndex ? MoneroComponents.Style.buttonBackgroundColor : (contactMouse.containsMouse ? MoneroComponents.Style.titleBarButtonHoverColor : "transparent")

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: label
                                    textFormat: Text.PlainText
                                    color: index === contactsList.currentIndex ? MoneroComponents.Style.buttonTextColor : MoneroComponents.Style.defaultFontColor
                                    font.family: MoneroComponents.Style.fontRegular.name
                                    font.bold: true
                                    font.pixelSize: 15
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: blocked ? qsTr("Blocked") : contactId.substring(0, 12) + "…"
                                    color: index === contactsList.currentIndex ? MoneroComponents.Style.buttonTextColor : MoneroComponents.Style.dimmedFontColor
                                    font.family: MoneroComponents.Style.fontMonoRegular.name
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: contactMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: selectContact(index)
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 20
                            visible: contactsModel.count === 0
                            text: qsTr("No contacts yet. Add a main Carrot SC address, or accept a waiting unknown sender below.") + translationManager.emptyString
                            color: MoneroComponents.Style.dimmedFontColor
                            font.family: MoneroComponents.Style.fontRegular.name
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        visible: quarantineModel.count > 0
                        color: MoneroComponents.Style.inputBorderColorInActive
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: quarantineModel.count > 0
                        text: qsTr("Waiting from unknown (%1)").arg(quarantineModel.count) + translationManager.emptyString
                        color: MoneroComponents.Style.defaultFontColor
                        font.family: MoneroComponents.Style.fontRegular.name
                        font.bold: true
                        font.pixelSize: 14
                    }

                    ListView {
                        id: quarantineList
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(190, quarantineModel.count * 76)
                        visible: quarantineModel.count > 0
                        clip: true
                        spacing: 3
                        model: quarantineModel
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            width: quarantineList.width
                            height: 72
                            radius: 4
                            color: quarantineMouse.containsMouse
                                   ? MoneroComponents.Style.titleBarButtonHoverColor : "transparent"
                            border.color: MoneroComponents.Style.inputBorderColorInActive

                            Column {
                                anchors.left: parent.left
                                anchors.right: addUnknownText.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 8
                                anchors.rightMargin: 6
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: qsTr("Unknown") + " — " + contactId.substring(0, 12) + "…"
                                    color: MoneroComponents.Style.defaultFontColor
                                    font.family: MoneroComponents.Style.fontMonoRegular.name
                                    font.bold: true
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: content
                                    textFormat: Text.PlainText
                                    color: MoneroComponents.Style.dimmedFontColor
                                    font.family: MoneroComponents.Style.fontRegular.name
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                id: addUnknownText
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("Add") + translationManager.emptyString
                                color: MoneroComponents.Style.buttonBackgroundColor
                                font.family: MoneroComponents.Style.fontRegular.name
                                font.bold: true
                                font.pixelSize: 12
                            }

                            MouseArea {
                                id: quarantineMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: addQuarantinedSender(contactId)
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: MoneroComponents.Style.inputBorderColorInActive
                    }

                    MoneroComponents.StandardButton {
                        Layout.fillWidth: true
                        primary: false
                        small: true
                        text: qsTr("My Salchat address") + translationManager.emptyString
                        onClicked: showAddress()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 6
                color: "transparent"
                border.color: MoneroComponents.Style.inputBorderColorInActive

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 58
                        color: MoneroComponents.Style.titleBarButtonHoverColor

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 10
                            spacing: 8

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: selectedContactLabel || qsTr("Select a contact")
                                    textFormat: Text.PlainText
                                    color: MoneroComponents.Style.defaultFontColor
                                    font.family: MoneroComponents.Style.fontRegular.name
                                    font.bold: true
                                    font.pixelSize: 17
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: selectedContactBlocked ? qsTr("Blocked — sending disabled") : qsTr("End-to-end encrypted")
                                    color: selectedContactBlocked ? MoneroComponents.Style.errorColor : MoneroComponents.Style.dimmedFontColor
                                    font.family: MoneroComponents.Style.fontRegular.name
                                    font.pixelSize: 12
                                }
                            }

                            MoneroComponents.StandardButton {
                                visible: selectedContactId !== ""
                                primary: false
                                small: true
                                text: selectedContactBlocked ? qsTr("Unblock") : qsTr("Block")
                                onClicked: toggleBlockContact()
                            }

                            MoneroComponents.StandardButton {
                                visible: selectedContactId !== ""
                                primary: false
                                small: true
                                text: qsTr("Remove") + translationManager.emptyString
                                onClicked: {
                                    pendingRemoveContactId = selectedContactId
                                    confirmRemovePopup.open()
                                }
                            }

                            MoneroComponents.StandardButton {
                                primary: false
                                small: true
                                text: qsTr("Check now") + translationManager.emptyString
                                enabled: !receiveBusy && serviceStatus.daemonAvailable === true && serviceStatus.daemonEnabled === true
                                onClicked: receiveMessages(false)
                            }
                        }
                    }

                    ListView {
                        id: messagesList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.margins: 10
                        clip: true
                        spacing: 8
                        model: messagesModel
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Item {
                            width: messagesList.width
                            height: messageBubble.height + 3
                            property bool outgoing: directionName === "outgoing"

                            Rectangle {
                                id: messageBubble
                                anchors.right: outgoing ? parent.right : undefined
                                anchors.left: outgoing ? undefined : parent.left
                                width: Math.min(parent.width * 0.78, Math.max(150, messageColumn.implicitWidth + 24))
                                height: messageColumn.height + 18
                                radius: 8
                                color: outgoing ? MoneroComponents.Style.buttonBackgroundColor : MoneroComponents.Style.titleBarButtonHoverColor
                                border.color: outgoing ? MoneroComponents.Style.buttonBackgroundColor : MoneroComponents.Style.inputBorderColorInActive

                                Column {
                                    id: messageColumn
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 9
                                    spacing: 4

                                    Text {
                                        width: parent.width
                                        text: content
                                        textFormat: Text.PlainText
                                        color: outgoing ? MoneroComponents.Style.buttonTextColor : MoneroComponents.Style.defaultFontColor
                                        font.family: MoneroComponents.Style.fontRegular.name
                                        font.pixelSize: 15
                                        wrapMode: Text.Wrap
                                    }

                                    Row {
                                        anchors.right: parent.right
                                        spacing: 7

                                        Text {
                                            text: Qt.formatDateTime(new Date((receivedAt || createdAt) * 1000), "MMM d, hh:mm")
                                            color: outgoing ? MoneroComponents.Style.buttonTextColor : MoneroComponents.Style.dimmedFontColor
                                            opacity: 0.75
                                            font.family: MoneroComponents.Style.fontRegular.name
                                            font.pixelSize: 10
                                        }

                                        Text {
                                            visible: outgoing
                                            text: stateName
                                            color: MoneroComponents.Style.buttonTextColor
                                            opacity: 0.85
                                            font.family: MoneroComponents.Style.fontRegular.name
                                            font.pixelSize: 10
                                        }

                                        Text {
                                            visible: blocksLeft > 0
                                            text: qsTr("%1 blocks left").arg(blocksLeft)
                                            color: outgoing ? MoneroComponents.Style.buttonTextColor : MoneroComponents.Style.dimmedFontColor
                                            opacity: 0.75
                                            font.family: MoneroComponents.Style.fontRegular.name
                                            font.pixelSize: 10
                                        }

                                        Text {
                                            text: qsTr("Delete")
                                            color: outgoing ? MoneroComponents.Style.buttonTextColor : MoneroComponents.Style.dimmedFontColor
                                            opacity: deleteMouse.containsMouse ? 1 : 0.65
                                            font.family: MoneroComponents.Style.fontRegular.name
                                            font.pixelSize: 10

                                            MouseArea {
                                                id: deleteMouse
                                                anchors.fill: parent
                                                anchors.margins: -5
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    pendingDeleteMessageId = messageId
                                                    confirmDeletePopup.open()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 30
                            visible: messagesModel.count === 0
                            text: selectedContactId === "" ? qsTr("Choose a contact to open a conversation.") : qsTr("No messages in this conversation yet.")
                            color: MoneroComponents.Style.dimmedFontColor
                            font.family: MoneroComponents.Style.fontRegular.name
                            font.pixelSize: 15
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 70
                        color: MoneroComponents.Style.titleBarButtonHoverColor
                        border.color: MoneroComponents.Style.inputBorderColorInActive

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 9

                            TextArea {
                                id: messageInput
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                enabled: !sendBusy && selectedContactId !== "" && !selectedContactBlocked && serviceStatus.daemonAvailable === true && serviceStatus.daemonEnabled === true
                                placeholderText: selectedContactId === "" ? qsTr("Select a contact") : qsTr("Write an encrypted message…")
                                color: MoneroComponents.Style.defaultFontColor
                                selectionColor: MoneroComponents.Style.textSelectionColor
                                selectedTextColor: MoneroComponents.Style.textSelectedColor
                                font.family: MoneroComponents.Style.fontRegular.name
                                font.pixelSize: 14
                                wrapMode: TextEdit.Wrap
                                textFormat: TextEdit.PlainText
                                selectByMouse: true
                                background: Rectangle {
                                    radius: 4
                                    color: "transparent"
                                    border.color: messageInput.activeFocus ? MoneroComponents.Style.inputBorderColorActive : MoneroComponents.Style.inputBorderColorInActive
                                }

                                Keys.onPressed: {
                                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                                        sendMessage()
                                        event.accepted = true
                                    }
                                }
                            }

                            MoneroComponents.StandardButton {
                                text: (sendBusy ? qsTr("Sending…") : qsTr("Send")) + translationManager.emptyString
                                enabled: messageInput.enabled && messageInput.text.trim() !== ""
                                onClicked: sendMessage()
                            }
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: addContactPopup
        parent: root
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        width: Math.min(560, root.width - 40)
        height: 410
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 20
        background: Rectangle {
            radius: 7
            color: MoneroComponents.Style.middlePanelBackgroundColor
            border.color: MoneroComponents.Style.inputBorderColorInActive
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: (addingQuarantinedContact ? qsTr("Add unknown sender") : qsTr("Add Salchat contact")) + translationManager.emptyString
                color: MoneroComponents.Style.defaultFontColor
                font.family: MoneroComponents.Style.fontRegular.name
                font.pixelSize: 23
            }

            MoneroComponents.LineEdit {
                id: contactLabelInput
                Layout.fillWidth: true
                labelText: qsTr("Display name") + translationManager.emptyString
                placeholderText: qsTr("Alice") + translationManager.emptyString
            }

            Text {
                Layout.fillWidth: true
                text: (addingQuarantinedContact ? qsTr("Authenticated contact ID") :
                      qsTr("Main Carrot address or quarantined contact ID")) + translationManager.emptyString
                color: MoneroComponents.Style.defaultFontColor
                font.family: MoneroComponents.Style.fontRegular.name
                font.pixelSize: 15
            }

            TextArea {
                id: contactAddressInput
                Layout.fillWidth: true
                Layout.fillHeight: true
                placeholderText: qsTr("Paste an SC… address or a quarantined contact ID") + translationManager.emptyString
                textFormat: TextEdit.PlainText
                color: MoneroComponents.Style.defaultFontColor
                selectionColor: MoneroComponents.Style.textSelectionColor
                selectedTextColor: MoneroComponents.Style.textSelectedColor
                font.family: MoneroComponents.Style.fontMonoRegular.name
                font.pixelSize: 12
                wrapMode: TextEdit.WrapAnywhere
                selectByMouse: true
                background: Rectangle {
                    radius: 4
                    color: "transparent"
                    border.color: contactAddressInput.activeFocus ? MoneroComponents.Style.inputBorderColorActive : MoneroComponents.Style.inputBorderColorInActive
                }
            }

            RowLayout {
                Layout.fillWidth: true

                MoneroComponents.StandardButton {
                    primary: false
                    text: qsTr("Paste") + translationManager.emptyString
                    onClicked: contactAddressInput.text = clipboard.text().trim()
                }

                Item { Layout.fillWidth: true }

                MoneroComponents.StandardButton {
                    primary: false
                    text: qsTr("Cancel") + translationManager.emptyString
                    onClicked: {
                        addingQuarantinedContact = false
                        addContactPopup.close()
                    }
                }

                MoneroComponents.StandardButton {
                    text: qsTr("Add contact") + translationManager.emptyString
                    onClicked: addContact()
                }
            }
        }
    }

    Popup {
        id: ownAddressPopup
        parent: root
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        width: Math.min(620, root.width - 40)
        height: 390
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 20
        background: Rectangle {
            radius: 7
            color: MoneroComponents.Style.middlePanelBackgroundColor
            border.color: MoneroComponents.Style.inputBorderColorInActive
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: qsTr("My Salchat address") + translationManager.emptyString
                color: MoneroComponents.Style.defaultFontColor
                font.family: MoneroComponents.Style.fontRegular.name
                font.pixelSize: 23
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Share this Salchat contact code so someone can add you. It combines your main Carrot address with a dedicated messaging encryption key; your wallet view key cannot decrypt chats.") + translationManager.emptyString
                color: MoneroComponents.Style.dimmedFontColor
                font.family: MoneroComponents.Style.fontRegular.name
                font.pixelSize: 14
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: Math.min(210, parent.height)
                    Layout.preferredHeight: width
                    radius: 4
                    color: "white"
                    border.color: MoneroComponents.Style.inputBorderColorInActive

                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        smooth: false
                        fillMode: Image.PreserveAspectFit
                        source: addressOutput.text === "" ? "" : "image://qrcode/" + addressOutput.text
                    }
                }

                TextArea {
                    id: addressOutput
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    readOnly: true
                    textFormat: TextEdit.PlainText
                    color: MoneroComponents.Style.defaultFontColor
                    selectionColor: MoneroComponents.Style.textSelectionColor
                    selectedTextColor: MoneroComponents.Style.textSelectedColor
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    font.pixelSize: 12
                    wrapMode: TextEdit.WrapAnywhere
                    selectByMouse: true
                    background: Rectangle {
                        radius: 4
                        color: "transparent"
                        border.color: MoneroComponents.Style.inputBorderColorInActive
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight

                MoneroComponents.StandardButton {
                    primary: false
                    text: qsTr("Close") + translationManager.emptyString
                    onClicked: ownAddressPopup.close()
                }

                MoneroComponents.StandardButton {
                    primary: false
                    text: qsTr("Copy QR") + translationManager.emptyString
                    onClicked: {
                        walletManager.saveQrCodeToClipboard(addressOutput.text)
                        showNotice(qsTr("Address QR code copied."), false)
                    }
                }

                MoneroComponents.StandardButton {
                    primary: false
                    text: qsTr("Generate new key") + translationManager.emptyString
                    onClicked: {
                        ownAddressPopup.close()
                        confirmRotateIdentityPopup.open()
                    }
                }

                MoneroComponents.StandardButton {
                    text: qsTr("Copy contact code") + translationManager.emptyString
                    onClicked: {
                        clipboard.setText(addressOutput.text)
                        showNotice(qsTr("Salchat contact code copied."), false)
                    }
                }
            }
        }
    }

    Popup {
        id: confirmRotateIdentityPopup
        parent: root
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        width: Math.min(520, root.width - 40)
        height: 280
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape
        padding: 20
        background: Rectangle {
            radius: 7
            color: MoneroComponents.Style.middlePanelBackgroundColor
            border.color: MoneroComponents.Style.inputBorderColorInActive
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 14

            Text {
                Layout.fillWidth: true
                text: qsTr("Generate a new Salchat encryption key? Your contact code will change, so every contact must receive the new code. Back up this wallet file after rotation: the generated key is not restored by the seed alone. Up to 16 still-valid prior keys are retained for already-waiting messages; more rapid rotations can evict the oldest key.") + translationManager.emptyString
                color: MoneroComponents.Style.defaultFontColor
                font.family: MoneroComponents.Style.fontRegular.name
                font.pixelSize: 16
                wrapMode: Text.WordWrap
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.alignment: Qt.AlignRight

                MoneroComponents.StandardButton {
                    primary: false
                    text: qsTr("Cancel") + translationManager.emptyString
                    onClicked: confirmRotateIdentityPopup.close()
                }

                MoneroComponents.StandardButton {
                    text: qsTr("Generate key") + translationManager.emptyString
                    onClicked: {
                        var result = currentWallet.salchatRotateIdentity()
                        if (!result.success) {
                            confirmRotateIdentityPopup.close()
                            displayError(result, qsTr("Could not generate a new Salchat encryption key."))
                            return
                        }
                        addressOutput.text = result.salviumAddress + ":" + result.encryptionPublicKey
                        confirmRotateIdentityPopup.close()
                        ownAddressPopup.open()
                        showNotice(qsTr("New Salchat key generated. Back up the wallet and share the new contact code."), false)
                    }
                }
            }
        }
    }

    Popup {
        id: confirmDeletePopup
        parent: root
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        width: Math.min(440, root.width - 40)
        height: 175
        modal: true
        focus: true
        padding: 20
        background: Rectangle {
            radius: 7
            color: MoneroComponents.Style.middlePanelBackgroundColor
            border.color: MoneroComponents.Style.inputBorderColorInActive
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 14

            Text {
                Layout.fillWidth: true
                text: qsTr("Delete this message from the wallet? This cannot be undone.") + translationManager.emptyString
                color: MoneroComponents.Style.defaultFontColor
                font.family: MoneroComponents.Style.fontRegular.name
                font.pixelSize: 16
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                MoneroComponents.StandardButton { primary: false; text: qsTr("Cancel"); onClicked: confirmDeletePopup.close() }
                MoneroComponents.StandardButton {
                    text: qsTr("Delete")
                    onClicked: {
                        var result = currentWallet.salchatDeleteMessage(pendingDeleteMessageId)
                        confirmDeletePopup.close()
                        if (!result.success)
                            displayError(result, qsTr("Could not delete the message."))
                        else
                            refreshMessages()
                    }
                }
            }
        }
    }

    Popup {
        id: confirmRemovePopup
        parent: root
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        width: Math.min(460, root.width - 40)
        height: 190
        modal: true
        focus: true
        padding: 20
        background: Rectangle {
            radius: 7
            color: MoneroComponents.Style.middlePanelBackgroundColor
            border.color: MoneroComponents.Style.inputBorderColorInActive
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 14

            Text {
                Layout.fillWidth: true
                text: qsTr("Remove this contact and delete its local message history from this wallet? This cannot be undone.") + translationManager.emptyString
                color: MoneroComponents.Style.defaultFontColor
                font.family: MoneroComponents.Style.fontRegular.name
                font.pixelSize: 16
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                MoneroComponents.StandardButton { primary: false; text: qsTr("Cancel"); onClicked: confirmRemovePopup.close() }
                MoneroComponents.StandardButton {
                    text: qsTr("Remove")
                    onClicked: {
                        var result = currentWallet.salchatRemoveContact(pendingRemoveContactId)
                        confirmRemovePopup.close()
                        if (!result.success)
                            displayError(result, qsTr("Could not remove the contact."))
                        else {
                            selectedContactId = ""
                            refreshAll(false)
                            showNotice(qsTr("Contact and local message history deleted."), false)
                        }
                    }
                }
            }
        }
    }
}
