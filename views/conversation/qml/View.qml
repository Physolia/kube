/*
 *  Copyright (C) 2017 Michael Bohlender, <michael.bohlender@kdemail.net>
 *  Copyright (C) 2017 Christian Mollekopf, <mollekopf@kolabsys.com>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */


import QtQuick 2.9
import QtQuick.Controls 1.3 as Controls1
import QtQuick.Controls 2
import QtQuick.Layouts 1.1

import org.kube.framework 1.0 as Kube

Kube.View {
    id: root
    property alias currentAccount: accountFolderview.currentAccount

    property rect searchArea: Qt.rect(mailListView.parent.x, 0, (mailView.x + mailView.width) - mailListView.parent.x, (mailView.y + mailView.height) - mailListView.y)

    property bool hasHelp: true
    function showHelp() {
        helpViewComponent.createObject(root).open()
    }

    Shortcut {
        sequences: ['j']
        onActivated: Kube.Fabric.postMessage(Kube.Messages.selectNextConversation, {})
    }
    Shortcut {
        sequences: ['k']
        onActivated: Kube.Fabric.postMessage(Kube.Messages.selectPreviousConversation, {})
    }
    Shortcut {
        sequences: ['Shift+J']
        onActivated: Kube.Fabric.postMessage(Kube.Messages.scrollConversationDown, {})
    }
    Shortcut {
        sequences: ['Shift+K']
        onActivated: Kube.Fabric.postMessage(Kube.Messages.scrollConversationUp, {})
    }
    Shortcut {
        sequences: ['n']
        onActivated: Kube.Fabric.postMessage(Kube.Messages.selectNextMessage, {})
    }
    Shortcut {
        sequences: ['p']
        onActivated: Kube.Fabric.postMessage(Kube.Messages.selectPreviousMessage, {})
    }
    Shortcut {
        sequences: ['f,n']
        onActivated: Kube.Fabric.postMessage(Kube.Messages.selectNextFolder, {})
    }
    Shortcut {
        sequences: ['f,p']
        onActivated: Kube.Fabric.postMessage(Kube.Messages.selectPreviousFolder, {})
    }
    Shortcut {
        sequences: ['c']
        onActivated: Kube.Fabric.postMessage(Kube.Messages.compose, {})
    }
    Shortcut {
        sequence: "?"
        onActivated: showHelp()
    }


    Controls1.SplitView {
        anchors.fill: parent
        Rectangle {
            width: Kube.Units.gridUnit * 10
            Layout.fillHeight: parent.height
            color: Kube.Colors.textColor

            Kube.PositiveButton {
                id: newMailButton
                objectName: "newMailButton"

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: Kube.Units.largeSpacing
                }
                focus: true
                text: qsTr("New Email")
                onClicked: Kube.Fabric.postMessage(Kube.Messages.compose, {})
            }

            Kube.InlineAccountSwitcher {
                id: accountFolderview
                activeFocusOnTab: true
                anchors {
                    top: newMailButton.bottom
                    topMargin: Kube.Units.largeSpacing
                    bottom: statusBarContainer.top
                    left: newMailButton.left
                    right: parent.right
                }
            }

            Item {
                id: statusBarContainer
                anchors {
                    topMargin: Kube.Units.smallSpacing
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                }
                height: childrenRect.height

                Rectangle {
                    id: border
                    visible: statusBar.visible
                    anchors {
                        right: parent.right
                        left: parent.left
                        margins: Kube.Units.smallSpacing
                    }
                    height: 1
                    color: Kube.Colors.viewBackgroundColor
                    opacity: 0.3
                }
                Kube.StatusBar {
                    id: statusBar
                    accountId: accountFolderview.currentAccount
                    height: Kube.Units.gridUnit * 2
                    anchors {
                        top: border.bottom
                        left: statusBarContainer.left
                        right: statusBarContainer.right
                    }
                }
            }
        }

        Rectangle {
            width: Kube.Units.gridUnit * 18
            Layout.fillHeight: parent.height

            color: "transparent"
            border.width: 1
            border.color: Kube.Colors.buttonColor

            Kube.MailListView  {
                id: mailListView
                objectName: "mailListView"
                anchors.fill: parent
                activeFocusOnTab: true
                Layout.minimumWidth: Kube.Units.gridUnit * 10
                Kube.Listener {
                    filter: Kube.Messages.folderSelection
                    onMessageReceived: mailListView.parentFolder = message.folder
                }

                Kube.Listener {
                    filter: Kube.Messages.search
                    onMessageReceived: {
                        searchComponent.createObject(root).open()
                    }
                }
                onCurrentMailChanged: {
                    Kube.Fabric.postMessage(Kube.Messages.mailSelection, {"mail": currentMail})
                }
            }
        }

        Kube.ConversationView {
            id: mailView
            objectName: "mailView"
            Layout.fillWidth: true
            Layout.fillHeight: parent.height
            activeFocusOnTab: true
            Kube.Listener {
                filter: Kube.Messages.mailSelection
                onMessageReceived: {
                    mailView.mail = message.mail
                }
            }

            Kube.Listener {
                filter: Kube.Messages.folderSelection
                onMessageReceived: {
                    mailView.hideTrash = !message.trash
                    mailView.hideNonTrash = message.trash
                }
            }

        }
    }

    Component {
        id: helpViewComponent
        Kube.HelpPopup {
            ListModel {
                ListElement { description: qsTr("Jump to next thread:"); shortcut: "j" }
                ListElement { description: qsTr("Jump to previous thread:"); shortcut: "k" }
                ListElement { description: qsTr("Jump to next message:"); shortcut: "n" }
                ListElement { description: qsTr("Jump to previous message:"); shortcut: "p" }
                ListElement { description: qsTr("Jump to next folder:"); shortcut: "f,n" }
                ListElement { description: qsTr("Jump to previous previous folder:"); shortcut: "f,p" }
                ListElement { description: qsTr("Compose new message:"); shortcut: "c" }
                ListElement { description: qsTr("Reply to the currently focused message:"); shortcut: "r" }
                ListElement { description: qsTr("Delete the currently focused message:"); shortcut: "d" }
                ListElement { description: qsTr("Show this help text:"); shortcut: "?" }
            }
        }
    }

    Component {
        id: searchComponent
        Kube.SearchPopup {
            id: searchPopup

            //x: (parent.width / 2) - (width / 2)
            //y: parent.height / 3
            //height: Kube.Units.gridUnit * 2
            //width: Kube.Units.gridUnit * 30

            parent: root
            //x: root.x + Kube.Units.gridUnit
            x: root.searchArea.x
            y: root.searchArea.y
            width: root.searchArea.width
            height: root.searchArea.height


            modal: false
            dim: true
            //closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            closePolicy: Popup.CloseOnEscape

            //TODO use dimming outside of search area
            //Use popup transparency for main area (how do we interact with the content?
            //Overlay.modal: Item {}

            background: Rectangle {
                color: "transparent"
                enabled: false
                border {
                    width: 2
                    color: Kube.Colors.highlightColor
                }
                Rectangle {
                    anchors.fill: parent
                    color: Kube.Colors.backgroundColor
                    opacity: 0.2
                }

            }

            Rectangle {
                id: filterField
                enabled: false

                //anchors.fill: parent
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
                y: parent.height / 3
                height: Kube.Units.gridUnit * 2
                width: Kube.Units.gridUnit * 30


                color: Kube.Colors.buttonColor

                states: [
                    State {
                        name: "searchInProgress"
                        when: find.text.length != 0
                        PropertyChanges {target: filterField; y: Kube.Units.gridUnit}
                        PropertyChanges {target: searchPopup; closePolicy: Popup.CloseOnEscape}
                        PropertyChanges {target: searchPopup; modal: false}
                    }
                ]

                function clearSearch() {
                    find.text = ""
                    mailListView.filter = ""
                    close()
                }

                RowLayout {
                    anchors {
                        verticalCenter: parent.verticalCenter
                    }

                    width: parent.width - Kube.Units.smallSpacing
                    spacing: 0

                    Kube.IconButton {
                        iconName: Kube.Icons.remove
                        activeFocusOnTab: visible
                        onClicked: filterField.clearSearch()
                    }

                    Kube.TextField {
                        id: find
                        Layout.fillWidth: true
                        placeholderText: qsTr("Filter...")
                        onTextChanged: mailListView.filter = text
                        activeFocusOnTab: visible
                        focus: visible
                        Keys.onEscapePressed: filterField.clearSearch()
                    }
                }
            }
        }
    }

}
