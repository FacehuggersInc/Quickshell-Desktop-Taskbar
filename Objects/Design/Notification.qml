import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts
import QtQuick.Controls

import qs.Objects.Design
import qs.Objects.Widgets
import qs.Objects.Theme

RoundedBlock {
    id: display
    alpha: 1.0
    radius: 10
    leftPadding: 12
    rightPadding: 12
    topPadding: 12
    bottomPadding: 12
    color: Theme.panelScrim

    // The live Notification object from the server
    property var notification: null

    // Derived display properties
    property string title: notification ? notification.summary : ""
    property string body:  notification ? notification.body    : ""
    property string icon:  notification
        ? (notification.appIcon.trim()  !== "" ? notification.appIcon.trim()
        :  notification.image.trim()    !== "" ? notification.image.trim()
        :  "notify")
        : "notify"

    function setIcon(iconName) {
        notifyIcon.setIcon(iconName)
    }

    ColumnLayout {
        width: parent.width - display.leftPadding - display.rightPadding
        spacing: 8

        // ── Header row: icon + title + dismiss ───────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            IconButton {
                id: notifyIcon
                iconName: display.icon
                iconSize: 20
                color: root.theme.primary
                tooltipText: notification ? notification.appName : ""
            }

            Text {
                text: display.title
                color: root.theme.text
                font.weight: 600
                font.family: root.settings.fontFamily
                font.pixelSize: 16
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: notification ? notification.appName : ""
                color: root.theme.text
                opacity: 0.5
                font.family: root.settings.fontFamily
                font.pixelSize: 12
                visible: text !== ""
            }

            IconButton {
                iconName: "close"
                iconSize: 16
                color: "#e05555"
                tooltipText: "Dismiss"
                onClicked: {
                    if (notification) notification.dismiss()
                }
            }
        }

        // ── Body text ────────────────────────────────────────────
        Text {
            text: display.body
            color: root.theme.text
            font.family: root.settings.fontFamily
            font.pixelSize: 14
            opacity: 0.85
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            visible: text !== ""
            textFormat: Text.PlainText
        }

        // ── Action buttons ───────────────────────────────────────
        // Renders all server-sent actions from notification.actions
        // notify-send --action=open="Open in Files" already populates this
        Flow {
            Layout.fillWidth: true
            spacing: 6
            visible: actionRepeater.count > 0

            Repeater {
                id: actionRepeater
                model: notification ? notification.actions : []
                delegate: RoundButton {
                    required property var modelData
                    text: modelData.text
                    font.family: root.settings.fontFamily
                    font.pixelSize: 13
                    font.weight: 500
                    padding: 6
                    horizontalPadding: 12

                    contentItem: Text {
                        text: parent.text
                        font: parent.font
                        color: root.theme.text
                        horizontalAlignment: Text.AlignHCenter
                    }
                    background: Rectangle {
                        radius: 6
                        color: root.theme.primary
                        opacity: 0.25
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    onClicked: {
                        // For USB notifications, handle the open action ourselves
                        // since notify-send doesn't have a live callback listener
                        if (modelData.identifier === "open" && root.usbLastMountpoint !== "") {
                            root.execute(["nautilus", root.usbLastMountpoint])
                        } else {
                            modelData.invoke()
                        }
                        if (notification && !notification.resident)
                            notification.dismiss()
                    }
                }
            }
        }
    }
}