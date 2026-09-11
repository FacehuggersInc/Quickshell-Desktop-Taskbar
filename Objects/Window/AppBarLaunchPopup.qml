import Quickshell
import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme
import qs.Objects.Widgets
import qs.Objects.Window

// A short confirmation that something was launched. Rebuilt on the shared
// surface, with a progress line so the auto dismiss is visible rather than
// the popup just vanishing.
PopupPanel {
    id: launchPopup

    implicitWidth: 460
    implicitHeight: body.implicitHeight + tbPadding * 2
    sidePadding: 14
    tbPadding: 12
    fadingEffectMax: 1.0
    scrollingEffect: false
    requireFocusGrab: false

    property var contextIcon: null
    property string subject: ""
    property string iconSource: ""

    readonly property int dwell: 1800

    function setAndOpen(launching, icon) {
        launchPopup.subject = launching || ""
        launchPopup.iconSource = icon || ""
        launchPopup.forceOpen(appBarWidget)
        countdown.restart()
        progress.restart()
    }

    Timer {
        id: countdown
        interval: launchPopup.dwell
        onTriggered: launchPopup.forceClose()
    }

    NumberAnimation {
        id: progress
        target: progressBar
        property: "fraction"
        from: 1
        to: 0
        duration: launchPopup.dwell
    }

    content: ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: Theme.radiusSmall
                color: Theme.alpha(Theme.textBase, 0.08)

                Image {
                    anchors.fill: parent
                    anchors.margins: 5
                    source: launchPopup.iconSource
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 64
                    sourceSize.height: 64
                    smooth: true
                    asynchronous: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: launchPopup.subject
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.labelSize
                    font.weight: 600
                }

                Text {
                    Layout.fillWidth: true
                    text: "started"
                    color: Theme.textMute
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.descSize
                }
            }

            ActionButton {
                label: "Dismiss"
                onActivated: launchPopup.forceClose()
            }
        }

        Rectangle {
            id: progressBar
            Layout.fillWidth: true
            Layout.preferredHeight: 3
            radius: 1.5
            color: Theme.alpha(Theme.textBase, 0.10)

            property real fraction: 0

            Rectangle {
                width: parent.width * parent.fraction
                height: parent.height
                radius: parent.radius
                color: Theme.accent
            }
        }
    }
}
