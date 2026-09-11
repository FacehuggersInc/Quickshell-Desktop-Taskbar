import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme
import qs.Objects.Systems

// A reusable installed-application picker. Emits the desktop id so callers can
// use it for whatever they like rather than assuming it is being pinned.
PanelWindow {
    id: chooser

    visible: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:appchooser"
    WlrLayershell.keyboardFocus: chooser.visible ? WlrKeyboardFocus.Exclusive
                                                 : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: 0

    screen: {
        var target = HyprlandSystem.focusedMonitor
        var list = Quickshell.screens
        for (var i = 0; i < list.length; i++) {
            if (list[i].name === target)
                return list[i]
        }
        return list.length > 0 ? list[0] : null
    }

    property Region glassBlurRegion: Region { item: card }
    BackgroundEffect.blurRegion:
        (chooser.visible && Theme.glass && Theme.blurMode === "protocol")
            ? glassBlurRegion : null

    property string heading: "Choose an Application"
    property string context: ""
    signal chosen(string desktopId)

    property string query: ""

    readonly property var apps: {
        var q = chooser.query.trim().toLowerCase()
        var out = []
        var list = DesktopEntries.applications
            ? DesktopEntries.applications.values : []

        for (var i = 0; i < list.length; i++) {
            var entry = list[i]
            if (!entry.id || entry.noDisplay)
                continue

            var name = entry.name || entry.id
            var comment = entry.comment || entry.genericName || ""
            if (q !== "" && name.toLowerCase().indexOf(q) === -1
                    && entry.id.toLowerCase().indexOf(q) === -1
                    && comment.toLowerCase().indexOf(q) === -1)
                continue

            out.push({
                id: entry.id + ".desktop",
                name: name,
                comment: comment,
                icon: entry.icon || ""
            })
        }

        out.sort(function(a, b) { return a.name.localeCompare(b.name) })
        return out
    }

    function open(title, subtitle) {
        chooser.heading = title ? title : "Choose an Application"
        chooser.context = subtitle ? subtitle : ""
        chooser.query = ""
        searchField.text = ""
        chooser.visible = true
        keyHandler.forceActiveFocus()
    }

    function close() { chooser.visible = false }

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: chooser.visible
        Keys.onEscapePressed: chooser.close()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.overlayScrim

        MouseArea {
            anchors.fill: parent
            onClicked: chooser.close()
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 140, 620)
        height: Math.min(parent.height - 140, 620)
        radius: Theme.radius
        color: Theme.panelScrim
        border.width: Theme.borderWidth
        border.color: Theme.borderStrong
        clip: true

        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.AllButtons
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: Theme.gap

            Text {
                Layout.fillWidth: true
                text: chooser.heading
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.weight: 700
            }

            Text {
                Layout.fillWidth: true
                visible: chooser.context !== ""
                text: chooser.context
                elide: Text.ElideRight
                color: Theme.textMute
                font.family: Theme.fontFamily
                font.pixelSize: Theme.descSize
            }

            InputField {
                id: searchField
                Layout.fillWidth: true
                placeholder: "Search installed applications"
                onTextChanged: chooser.query = text
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 3
                model: chooser.apps

                delegate: Rectangle {
                    required property var modelData

                    width: ListView.view.width
                    height: 50
                    radius: Theme.radiusSmall
                    color: rowArea.containsMouse ? Theme.alpha(Theme.accent, 0.18)
                                                 : Theme.alpha(Theme.scrimBase, 0.35)
                    border.width: Theme.borderWidth
                    border.color: Theme.alpha(Theme.textBase, 0.08)

                    Rectangle {
                        id: iconBox
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        height: 34
                        radius: Theme.radiusSmall
                        color: Theme.alpha(Theme.textBase, 0.06)

                        Image {
                            anchors.fill: parent
                            anchors.margins: 5
                            source: modelData.icon !== ""
                                ? Quickshell.iconPath(modelData.icon, true) : ""
                            fillMode: Image.PreserveAspectFit
                            sourceSize.width: 64
                            sourceSize.height: 64
                            smooth: true
                            asynchronous: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: modelData.icon === ""
                            text: modelData.name.charAt(0).toUpperCase()
                            color: Theme.textMute
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.weight: 700
                        }
                    }

                    Column {
                        anchors.left: iconBox.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: modelData.name
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.labelSize
                            font.weight: 600
                        }

                        Text {
                            width: parent.width
                            text: modelData.comment !== "" ? modelData.comment : modelData.id
                            elide: Text.ElideRight
                            color: Theme.textMute
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.descSize
                        }
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            chooser.close()
                            chooser.chosen(modelData.id)
                        }
                    }
                }
            }
        }
    }
}
