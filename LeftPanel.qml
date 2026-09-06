import QtQuick 2.9
import QtQuick.Layouts 1.1
import QtGraphicalEffects 1.0

import moneroComponents.Wallet 1.0
import moneroComponents.NetworkType 1.0
import moneroComponents.Clipboard 1.0
import FontAwesome 1.0

import "components" as MoneroComponents
import "components/effects/" as MoneroEffects

Rectangle {
    id: panel

    // ---- Public API (kept) ----
    property int currentAccountIndex
    property alias currentAccountLabel: accountLabel.text
    property string balanceString: "?.??"
    property string balanceUnlockedString: "?.??"
    property string balanceFiatString: "?.??"
    property string minutesToUnlock: ""
    property bool isSyncing: false
    property bool isHF11: false
    property bool isCarrot: false
    property bool isAuditHF: false
    property alias networkStatus : networkStatus
    property alias progressBar : progressBar
    property alias daemonProgressBar : daemonProgressBar
    property int titleBarHeight: 50
    property string copyValue: ""

    signal historyClicked()
    signal yieldClicked()
    signal stakingClicked()
    signal createTokenClicked()
    signal transferClicked()
    signal auditClicked()
    signal receiveClicked()
    signal advancedClicked()
    signal settingsClicked()
    signal addressBookClicked()
    signal chatClicked()
    signal accountClicked()
    signal assetTypeChanged(string assetType)

    Clipboard { id: clipboard }

    function findIndexByValue(value) {
        for (var i = 0; i < assetTypes.count; ++i) {
            if (assetTypes.get(i).column1 === value) return i
        }
        return -1
    }

    function setAssetTypes(list) {
        if (!list || list.length === 0)
            return;

        assetTypes.clear();
        for (var i = 0; i < list.length; ++i)
            assetTypes.append({ column1: list[i] });

        // clamp persisted selection
        var idx = appWindow.persistentSettings.assetType
        if (idx < 0 || idx >= assetTypes.count) {
            idx = 0
            appWindow.persistentSettings.assetType = "SAL1"
        }
        assetTypeSelector.currentIndex = findIndexByValue(appWindow.persistentSettings.assetType)
    }
    
    function dispatchAction(action) {
        switch (action) {
        case "Account": panel.accountClicked(); break;
        case "Send": panel.transferClicked(); break;
        case "AddressBook": panel.addressBookClicked(); break;
        case "Chat": panel.chatClicked(); break;
        case "Receive": panel.receiveClicked(); break;
        case "Staking": panel.stakingClicked(); break;
        case "Yield": panel.yieldClicked(); break;
        case "Audit": panel.auditClicked(); break;
        case "CreateToken": panel.createTokenClicked(); break;
        case "Transactions": panel.historyClicked(); break;
        case "Advanced": panel.advancedClicked(); break;
        case "Settings": panel.settingsClicked(); break;
        default: break;
        }
    }

    property var currentButton: null

    function uncheckAll() {
        // top-level
        accountButton.checked = false
        sendButton.checked = false
        receiveButton.checked = false
        chatButton.checked = false
        stakingButton.checked = false
        auditButton.checked = false
        createTokenButton.checked = false
        historyButton.checked = false
        advancedButton.checked = false
        settingsButton.checked = false

        // children
        addressBookButton.checked = false
        yieldButton.checked = false
    }

    function collapseGroup(parentBtn) {
        if (parentBtn === sendButton) addressBookButton.checked = false
        if (parentBtn === stakingButton) yieldButton.checked = false
        parentBtn.checked = false
        if (currentButton === parentBtn) currentButton = null
    }

    function selectButton(btn) {
        // If clicking the currently selected *parent*, treat as collapse toggle
        if (btn === currentButton && (btn === sendButton || btn === stakingButton)) {
            collapseGroup(btn)
            return
        }

        // Accordion: clear everything, then select the clicked item
        uncheckAll()

        // If selecting a child, also select its parent so nesting stays open
        if (btn === addressBookButton) sendButton.checked = true
        if (btn === yieldButton) stakingButton.checked = true

        btn.checked = true
        currentButton = btn
    }

    function selectItem(pos) {
        if (pos === "Account") selectButton(accountButton)
        else if (pos === "Send" || pos === "Transfer") selectButton(sendButton)
        else if (pos === "AddressBook") selectButton(addressBookButton)
        else if (pos === "Receive") selectButton(receiveButton)
        else if (pos === "Chat") selectButton(chatButton)
        else if (pos === "Staking") selectButton(stakingButton)
        else if (pos === "Yield") selectButton(yieldButton)
        else if (pos === "CreateToken") selectButton(createTokenButton)
        else if (pos === "Audit") selectButton(auditButton)
        else if (pos === "Transactions" || pos === "History") selectButton(historyButton)
        else if (pos === "Advanced") selectButton(advancedButton)
        else if (pos === "Settings") selectButton(settingsButton)
    }

    width: 300
    color: "transparent"
    anchors.top: parent.top
    anchors.bottom: parent.bottom

    MoneroEffects.GradientBackground {
        anchors.fill: parent
        fallBackColor: MoneroComponents.Style.middlePanelBackgroundColor
        initialStartColor: MoneroComponents.Style.leftPanelBackgroundGradientStart
        initialStopColor: MoneroComponents.Style.leftPanelBackgroundGradientStop
        blackColorStart: MoneroComponents.Style._b_leftPanelBackgroundGradientStart
        blackColorStop: MoneroComponents.Style._b_leftPanelBackgroundGradientStop
        whiteColorStart: MoneroComponents.Style._w_leftPanelBackgroundGradientStart
        whiteColorStop: MoneroComponents.Style._w_leftPanelBackgroundGradientStop
        posStart: 0.6
        start: Qt.point(0, 0)
        end: Qt.point(height, width)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Top offset if using custom decorations
        Item { Layout.preferredHeight: (persistentSettings.customDecorations ? 50 : 0) }

        // -------------------- HEADER CARD --------------------
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 175

            Item {
                id: cardContainer
                width: 260
                height: 135
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.top: parent.top
                anchors.topMargin: 20

                Image {
                    id: card
                    visible: !isOpenGL || MoneroComponents.Style.blackTheme
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit
                    source: MoneroComponents.Style.blackTheme
                        ? "qrc:///images/card-background-black" + (currentAccountIndex % MoneroComponents.Style.accountColors.length) + ".png"
                        : "qrc:///images/card-background-white.png"
                }

                DropShadow {
                    visible: isOpenGL && !MoneroComponents.Style.blackTheme
                    anchors.fill: card
                    horizontalOffset: 3
                    verticalOffset: 3
                    radius: 10.0
                    samples: 15
                    color: "#3B000000"
                    source: card
                    cached: true
                }

                MoneroComponents.TextPlain {
                    id: testnetLabel
                    visible: persistentSettings.nettype != NetworkType.MAINNET
                    text: (persistentSettings.nettype == NetworkType.TESTNET ? qsTr("Testnet") : qsTr("Stagenet")) + translationManager.emptyString
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    font.bold: true
                    font.pixelSize: 12
                    color: "#f33434"
                    themeTransition: false
                }

                MoneroComponents.TextPlain {
                    id: viewOnlyLabel
                    visible: viewOnly
                    text: qsTr("View Only") + translationManager.emptyString
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    anchors.right: testnetLabel.visible ? testnetLabel.left : parent.right
                    anchors.rightMargin: 8
                    font.pixelSize: 12
                    font.bold: true
                    color: "#ff9323"
                    themeTransition: false
                }
            }

            // Account label overlay
            MoneroComponents.Label {
                fontSize: 12
                id: accountIndex
                text: qsTr("Account") + translationManager.emptyString + " #" + currentAccountIndex
                color: MoneroComponents.Style.blackTheme ? "white" : "black"
                anchors.left: parent.left
                anchors.leftMargin: 80
                anchors.top: parent.top
                anchors.topMargin: 43
                themeTransition: false

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: appWindow.showPageRequest("Account")
                }
            }

            MoneroComponents.Label {
                fontSize: 16
                id: accountLabel
                textWidth: 170
                color: MoneroComponents.Style.blackTheme ? "white" : "black"
                anchors.left: parent.left
                anchors.leftMargin: 80
                anchors.top: parent.top
                anchors.topMargin: 56
                themeTransition: false
                elide: Text.ElideRight

                MouseArea {
                    hoverEnabled: true
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: appWindow.showPageRequest("Account")
                }
            }

                MoneroComponents.Label {
                    fontSize: 16
                    visible: isSyncing
                    text: qsTr("Syncing...") + translationManager.emptyString
                    color: MoneroComponents.Style.blackTheme ? "white" : "black"
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.bottom: cardContainer.top
                    anchors.bottomMargin: 30
                    themeTransition: false
                }

                Item {
                    id: balanceRow
                    anchors.left: cardContainer.left
                    anchors.right: cardContainer.right
                    anchors.bottom: cardContainer.bottom
                    anchors.bottomMargin: 20
    
                    MoneroComponents.TextPlain {
                        id: balancePart1
                        themeTransition: false
                        anchors.right: balanceRow.horizontalCenter
                        anchors.rightMargin: 2
                        anchors.bottom: parent.bottom
                        horizontalAlignment: Text.AlignRight
                        color: MoneroComponents.Style.blackTheme ? "white" : "black"
                        Binding on color {
                            when: balancePart1MouseArea.containsMouse || balancePart2MouseArea.containsMouse
                            value: MoneroComponents.Style.orange
                        }
                        text: {
                            if (persistentSettings.fiatPriceEnabled && persistentSettings.fiatPriceToggle) {
                                return balanceFiatString.split('.')[0] + "."
                            } else {
                                return balanceString.split('.')[0] + "."
                            }
                        }
                        font.pixelSize: {
                            var defaultSize = 29;
                            var digits = (balancePart1.text.length - 1)
                            if (digits > 2 && !(persistentSettings.fiatPriceEnabled && persistentSettings.fiatPriceToggle)) {
                                return defaultSize - 1.1 * digits
                            } else {
                                return defaultSize
                            }
                        }
                        MouseArea {
                            id: balancePart1MouseArea
                            hoverEnabled: true
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                    console.log("Copied to clipboard");
                                    clipboard.setText(balancePart1.text + balancePart2.text);
                                    appWindow.showStatusMessage(qsTr("Copied to clipboard"),3)
                            }
                        }
                    }
                    MoneroComponents.TextPlain {
                        id: balancePart2
                        themeTransition: false
                        anchors.left: balanceRow.horizontalCenter
                        anchors.leftMargin: 0
                        anchors.baseline: balancePart1.baseline
                        horizontalAlignment: Text.AlignLeft
                        color: balancePart1.color
                        text: {
                            if (persistentSettings.fiatPriceEnabled && persistentSettings.fiatPriceToggle) {
                                return balanceFiatString.split('.')[1]
                            } else {
                                return balanceString.split('.')[1]
                            }
                        }
                        font.pixelSize: 16
                        MouseArea {
                            id: balancePart2MouseArea
                            hoverEnabled: true
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: balancePart1MouseArea.clicked(mouse)
                        }
                    }

                    Item { //separator
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                    }
        
                }
        }

        // -------------------- ASSET DROPDOWN --------------------
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 50

            ListModel {
                id: assetTypes
                ListElement { column1: "SAL1" }
            }

            MoneroComponents.StandardDropdown {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 20
                anchors.rightMargin: 20

                id: assetTypeSelector
                dataModel: assetTypes
                itemTopMargin: 2

                // Correct binding: assetType, not logLevel
                currentIndex: findIndexByValue(appWindow.persistentSettings.assetType)

                onChanged: {
                    if (currentIndex < 0 || currentIndex >= assetTypes.count)
                        return;

                    var t = assetTypes.get(currentIndex).column1;

                    // persist selection (by string is best)
                    appWindow.persistentSettings.assetType = t;

                    // notify the app
                    panel.assetTypeChanged(t);
                }
            }

            function setAssetTypes(list) {
                if (!list) return

                // remember currently selected value (prefer persisted value, otherwise current UI)
                var desired = appWindow.persistentSettings.assetType
                if (!desired || desired === "") {
                    if (assetTypeSelector.currentIndex >= 0 && assetTypeSelector.currentIndex < assetTypes.count)
                        desired = assetTypes.get(assetTypeSelector.currentIndex).column1
                }

                assetTypes.clear()
                for (var i = 0; i < list.length; ++i)
                    assetTypes.append({ column1: list[i] })

                // restore selection by value if possible
                var idx = findIndexByValue(desired)
                if (idx < 0) idx = 0

                // update dropdown without “jumping” to arbitrary indices
                assetTypeSelector.currentIndex = idx

                // keep persistent settings coherent
                if (assetTypes.count > 0)
                    appWindow.persistentSettings.assetType = assetTypes.get(idx).column1
            }
        }

        // -------------------- MENU (FILL) --------------------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: menuFlick
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: progressBar.visible ? progressBar.top : networkStatus.top
                clip: true
                contentHeight: menuColumn.height
                boundsBehavior: isMac ? Flickable.DragAndOvershootBounds : Flickable.StopAtBounds

                Column {
                    id: menuColumn
                    anchors.left: parent.left
                    anchors.right: parent.right

                    MoneroComponents.MenuButtonDivider {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 20
                    }
                    
                    MoneroComponents.MenuButtonDivider {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 20
                    }

                    MoneroComponents.MenuButton {
                        id: accountButton
                        anchors.left: parent.left
                        anchors.right: parent.right
                        text: qsTr("Account") + translationManager.emptyString
                        symbol: (isMac ? "⌃" : qsTr("Ctrl+")) + "T" + translationManager.emptyString
                        onClicked: { selectButton(accountButton); dispatchAction("Account"); }
                    }

                    MoneroComponents.MenuButtonDivider { visible: accountButton.present; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 20 }

                    MoneroComponents.MenuButton {
                        id: sendButton
                        anchors.left: parent.left
                        anchors.right: parent.right
                        text: qsTr("Send") + translationManager.emptyString
                        symbol: (isMac ? "⌃" : qsTr("Ctrl+")) + "S" + translationManager.emptyString
                        onClicked: {
                            // parent: toggle/collapse handled by selectButton()
                            selectButton(sendButton)
                            // optional: navigate when clicking parent
                            dispatchAction("Send")
                        }
                    }

                    MoneroComponents.MenuButton {
                        id: addressBookButton
                        under: sendButton
                        anchors.left: parent.left
                        anchors.right: parent.right
                        text: qsTr("Address book") + translationManager.emptyString
                        symbol: (isMac ? "⌃" : qsTr("Ctrl+")) + "B" + translationManager.emptyString
                        onClicked: { selectButton(addressBookButton); dispatchAction("AddressBook"); }
                    }

                    MoneroComponents.MenuButtonDivider { visible: sendButton.present; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 20 }

                    MoneroComponents.MenuButton {
                        id: receiveButton
                        anchors.left: parent.left
                        anchors.right: parent.right
                        text: qsTr("Receive") + translationManager.emptyString
                        symbol: (isMac ? "⌃" : qsTr("Ctrl+")) + "R" + translationManager.emptyString
                        onClicked: { selectButton(receiveButton); dispatchAction("Receive"); }
                    }

                    MoneroComponents.MenuButtonDivider { visible: receiveButton.present; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 20 }

                    MoneroComponents.MenuButton {
                        id: chatButton
                        anchors.left: parent.left
                        anchors.right: parent.right
                        text: qsTr("Salchat") + translationManager.emptyString
                        symbol: (isMac ? "⌃" : qsTr("Ctrl+")) + "M" + translationManager.emptyString
                        onClicked: { selectButton(chatButton); dispatchAction("Chat"); }
                    }

                    MoneroComponents.MenuButtonDivider { visible: chatButton.present; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 20 }

                    MoneroComponents.MenuButton {
                        id: stakingButton
                        anchors.left: parent.left
                        anchors.right: parent.right
                        text: qsTr("Staking") + translationManager.emptyString
                        symbol: (isMac ? "⌃" : qsTr("Ctrl+")) + "K" + translationManager.emptyString
                        visible: currentAccountIndex === 0
                        enabled: currentAccountIndex === 0
                        onClicked: {
                            selectButton(stakingButton)
                            dispatchAction("Staking")
                        }
                    }

                    MoneroComponents.MenuButton {
                        id: yieldButton
                        under: stakingButton
                        anchors.left: parent.left
                        anchors.right: parent.right
                        text: qsTr("Yield Info") + translationManager.emptyString
                        symbol: (isMac ? "⌃" : qsTr("Ctrl+")) + "Y" + translationManager.emptyString
                        onClicked: { selectButton(yieldButton); dispatchAction("Yield"); }
                    }

                    MoneroComponents.MenuButtonDivider { visible: stakingButton.present; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 20 }

                    MoneroComponents.MenuButton {
                        id: auditButton
                        visible: isAuditHF
                        enabled: isAuditHF
                        anchors.left: parent.left
                        anchors.right: parent.right
                        text: qsTr("Audit") + translationManager.emptyString
                        symbol: (isMac ? "⌃" : qsTr("Ctrl+")) + "K" + translationManager.emptyString
                        onClicked: { selectButton(auditButton); dispatchAction("Audit"); }
                    }

                    MoneroComponents.MenuButtonDivider { visible: auditButton.present; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 20 }

                    // --------------- Create Token tab ---------------

                    MoneroComponents.MenuButton {
                        id: createTokenButton
                        anchors.left: parent.left
                        anchors.right: parent.right
                        text: qsTr("Create Token") + translationManager.emptyString
                        onClicked: {
                            selectButton(createTokenButton)
                            dispatchAction("CreateToken")
                        }
                        enabled: currentAccountIndex == 0 && isHF11
                        visible: currentAccountIndex == 0 && isHF11
                    }

                    MoneroComponents.MenuButtonDivider { visible: createTokenButton.present; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 20 }
    
                    MoneroComponents.MenuButton {
                        id: historyButton
                        anchors.left: parent.left
                        anchors.right: parent.right
                        text: qsTr("Transactions") + translationManager.emptyString
                        symbol: (isMac ? "⌃" : qsTr("Ctrl+")) + "H" + translationManager.emptyString
                        onClicked: { selectButton(historyButton); dispatchAction("Transactions"); }
                    }

                    MoneroComponents.MenuButtonDivider { visible: historyButton.present; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 20 }

                    MoneroComponents.MenuButton {
                        id: advancedButton
                        anchors.left: parent.left
                        anchors.right: parent.right
                        visible: appWindow.walletMode >= 2
                        text: qsTr("Advanced") + translationManager.emptyString
                        symbol: (isMac ? "⌃" : qsTr("Ctrl+")) + "D" + translationManager.emptyString
                        onClicked: { selectButton(advancedButton); dispatchAction("Advanced"); }
                    }

                    MoneroComponents.MenuButtonDivider { visible: advancedButton.present && appWindow.walletMode >= 2; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 20 }

                    MoneroComponents.MenuButton {
                        id: settingsButton
                        anchors.left: parent.left
                        anchors.right: parent.right
                        text: qsTr("Settings") + translationManager.emptyString
                        symbol: (isMac ? "⌃" : qsTr("Ctrl+")) + "E" + translationManager.emptyString
                        onClicked: { selectButton(settingsButton); dispatchAction("Settings"); }
                    }

                    MoneroComponents.MenuButtonDivider { visible: settingsButton.present; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 20 }
                }
            }

            // Bottom status area (same ids/aliases)
            MoneroComponents.ProgressBar {
                id: progressBar
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: daemonProgressBar.top
                height: 48
                syncType: qsTr("Wallet") + translationManager.emptyString
                visible: !appWindow.disconnected
            }

            MoneroComponents.ProgressBar {
                id: daemonProgressBar
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: networkStatus.top
                height: 62
                syncType: qsTr("Daemon") + translationManager.emptyString
                visible: !appWindow.disconnected
            }

            MoneroComponents.NetworkStatusItem {
                id: networkStatus
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 5
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5
                connected: Wallet.ConnectionStatus_Disconnected
                height: 48
            }

        }

    }
}
