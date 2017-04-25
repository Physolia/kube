/*
 *  Copyright (C) 2017 Michael Bohlender, <michael.bohlender@kdemail.net>
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

import QtQuick 2.4
import QtQuick.Layouts 1.1
import org.kube.framework 1.0 as Kube

FocusScope {
    id: root
    property string currentAccount: null

    ColumnLayout {
        anchors.fill: parent

        Repeater {
            model: Kube.AccountsModel {}
            onItemAdded: {
                //Autoselect the first account to appear
                if (!currentAccount) {
                    root.currentAccount = item.currentData.accountId
                }
            }

            delegate: Item {
                id: accountDelegate
                property variant currentData: model
                property bool isCurrent: (model.accountId == root.currentAccount)

                height: Kube.Units.gridUnit
                width: root.width
                Layout.fillHeight: isCurrent

                Rectangle {
                    id: accountLabel

                    height: Kube.Units.gridUnit
                    width: parent.width

                    color: Kube.Colors.textColor
                    activeFocusOnTab: !isCurrent
                    Keys.onReturnPressed: {
                        root.currentAccount = model.accountId
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.currentAccount = model.accountId
                        }
                    }

                    Row {
                        spacing: Kube.Units.smallSpacing
                        anchors.verticalCenter: parent.verticalCenter
                        Layout.fillHeight: true

                        Kube.Label{
                            text: model.name
                            font.weight: Font.Bold
                            color: Kube.Colors.highlightedTextColor
                        }

                        Kube.Icon {
                            id: statusIcon
                            visible: false
                            iconName: ""
                            states: [
                            State {
                                name: "busy"; when: model.status == Kube.AccountsModel.BusyStatus
                                PropertyChanges { target: statusIcon; iconName: Kube.Icons.busy_inverted; visible: true }
                            },
                            State {
                                name: "error"; when: model.status == Kube.AccountsModel.ErrorStatus
                                PropertyChanges { target: statusIcon; iconName: Kube.Icons.error_inverted; visible: true }
                            },
                            State {
                                name: "checkmark"; when: model.status == Kube.AccountsModel.ConnectedStatus
                                PropertyChanges { target: statusIcon; iconName: Kube.Icons.connected_inverted; visible: true }
                            },
                            State {
                                name: "disconnected"; when: model.status == Kube.AccountsModel.OfflineStatus
                                PropertyChanges { target: statusIcon; iconName: Kube.Icons.noNetworkConnection_inverted; visible: true }
                            }
                            ]
                        }
                    }
                }

                Kube.FolderListView {
                    anchors {
                        top: accountLabel.bottom
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }
                    activeFocusOnTab: true

                    accountId: currentData.accountId
                    visible: isCurrent
                }
            }
        }
    }
}
