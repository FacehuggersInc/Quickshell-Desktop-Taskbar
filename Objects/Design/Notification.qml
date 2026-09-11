import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme

// One notification, used by both the toast and the panel. Width comes from
// whoever placed it; height follows the content. The previous version let the
// text drive the width, which is why long summaries ran past the panel.
RoundedBlock {
    id: display

    property var notification: null
    property bool showActions: true
    property bool showDismiss: true

    readonly property string title: notification ? notification.summary : ""
    readonly property string bodyText: notification ? notification.body : ""
    readonly property string appName: notification ? notification.appName : ""

    readonly property bool urgent: notification
        ? String(notification.urgency).toLowerCase().indexOf("critical") !== -1
        : false

    // appIcon is a themed name, image is a path the sender supplied
    readonly property string iconName: notification && notification.appIcon
        && notification.appIcon.trim() !== "" ? notification.appIcon.trim() : ""
    readonly property string imagePath: notification && notification.image
        && notification.image.trim() !== "" ? notification.image.trim() : ""

    alpha: 1.0
    radius: Theme.radius
    sidePadding: 0
    tbPadding: 0
    color: Theme.panelScrim
    border: true
    highlight: false
    elevated: false

    implicitHeight: layout.implicitHeight + 24

    function setIcon(name) { /* kept for callers that pre-set an icon */ }

    // Urgency reads as a stripe rather than as loud text
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 6
        width: 3
        radius: 1.5
        visible: display.urgent
        color: Theme.danger
    }

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 12
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                Layout.alignment: Qt.AlignTop
                radius: Theme.radiusSmall
                color: Theme.alpha(Theme.textBase, 0.08)

                Image {
                    anchors.fill: parent
                    anchors.margins: 3
                    visible: display.imagePath !== ""
                    source: display.imagePath
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 64
                    sourceSize.height: 64
                    smooth: true
                    asynchronous: true
                }

                Image {
                    anchors.fill: parent
                    anchors.margins: 5
                    visible: display.imagePath === "" && display.iconName !== ""
                    source: display.iconName !== ""
                        ? Quickshell.iconPath(display.iconName, true) : ""
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 64
                    sourceSize.height: 64
                    smooth: true
                    asynchronous: true
                }

                Icon {
                    anchors.centerIn: parent
                    visible: display.imagePath === "" && display.iconName === ""
                    iconName: "notify"
                    iconSize: 16
                    color: Theme.accentIcon
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: display.title
                    // Wraps rather than running off; two lines is plenty for a
                    // summary and the body carries the detail
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.labelSize
                    font.weight: 700
                }

                Text {
                    Layout.fillWidth: true
                    visible: display.appName !== ""
                    text: display.appName
                    elide: Text.ElideRight
                    color: Theme.textMute
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.descSize
                }
            }

            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignTop
                visible: display.showDismiss
                radius: Theme.radiusSmall
                color: dismissArea.containsMouse ? Theme.alpha(Theme.danger, 0.25)
                                                 : "transparent"

                Icon {
                    anchors.centerIn: parent
                    iconName: "close"
                    iconSize: 13
                    color: dismissArea.containsMouse ? Theme.danger : Theme.textMute
                }

                MouseArea {
                    id: dismissArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (display.notification)
                            display.notification.dismiss()
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: display.bodyText !== ""
            text: display.bodyText
            wrapMode: Text.WordWrap
            maximumLineCount: 6
            elide: Text.ElideRight
            textFormat: Text.PlainText
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.valueSize
        }

        // ## Actions
        // The same buttons the toast had, kept when the notification is only
        // visible in the panel — a missed notification is exactly when its
        // action is still worth having.
        Flow {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 6
            visible: display.showActions && actionRepeater.count > 0

            Repeater {
                id: actionRepeater
                model: display.notification ? display.notification.actions : []

                delegate: ActionButton {
                    required property var modelData

                    label: modelData.text && modelData.text !== ""
                        ? modelData.text : "Open"
                    tone: "accent"

                    onActivated: {
                        // notify-send has no live callback, so the usb open
                        // action is handled here rather than round tripping
                        if (modelData.identifier === "open"
                                && root.usbLastMountpoint !== "") {
                            root.execute(root.cmd("files_open",
                                { "path": root.usbLastMountpoint }))
                        } else {
                            modelData.invoke()
                        }

                        if (display.notification && !display.notification.resident)
                            display.notification.dismiss()
                    }
                }
            }
        }
    }
}
