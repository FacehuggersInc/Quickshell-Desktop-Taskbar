import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme

ColumnLayout {
    id: page
    spacing: 0

    property int revision: 0

    readonly property var launchers: {
        var bump = page.revision
        return (root.settings.launchers || []).slice()
    }

    function move(index, delta) {
        var list = (root.settings.launchers || []).slice()
        var target = index + delta
        if (target < 0 || target >= list.length)
            return
        var item = list.splice(index, 1)[0]
        list.splice(target, 0, item)
        root.settings.launchers = list
        root.saveSettings()
        page.revision++
    }

    function unpin(index) {
        var list = (root.settings.launchers || []).slice()
        list.splice(index, 1)
        root.settings.launchers = list
        root.saveSettings()
        page.revision++
    }

    SectionLabel {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        text: "Pinned Applications"
    }

    SettingRow {
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        iconName: "apps"
        label: "Add Application"
        description: "Pick an installed app, or create a custom launcher"

        Row {
            spacing: 6

            ActionButton {
                label: "Installed"
                tone: "accent"
                enabled: root.addAppWindow !== null
                onActivated: {
                    if (root.addAppWindow) root.addAppWindow.openExisting()
                }
            }

            ActionButton {
                label: "Custom"
                enabled: root.addAppWindow !== null
                onActivated: {
                    if (root.addAppWindow) root.addAppWindow.openCustom()
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 8
        visible: page.launchers.length === 0
        text: "Nothing pinned yet. Use the add button on the app bar."
        color: Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: Theme.descSize
    }

    Repeater {
        model: page.launchers

        delegate: Rectangle {
            required property var modelData
            required property int index

            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.preferredHeight: 54
            radius: Theme.radiusSmall
            color: Theme.alpha(Theme.scrimBase, 0.35)
            border.width: Theme.borderWidth
            border.color: Theme.alpha(Theme.textBase, 0.08)

            Rectangle {
                id: iconBox
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 36
                radius: Theme.radiusSmall
                color: Theme.alpha(Theme.textBase, 0.06)

                Image {
                    anchors.fill: parent
                    anchors.margins: 5
                    source: modelData.icon ? modelData.icon : ""
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 64
                    sourceSize.height: 64
                    smooth: true
                    asynchronous: true
                }
            }

            Column {
                anchors.left: iconBox.right
                anchors.leftMargin: 10
                anchors.right: buttons.left
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
                    text: modelData.command ? modelData.command : ""
                    elide: Text.ElideRight
                    color: Theme.textMute
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.descSize
                }
            }

            Row {
                id: buttons
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                ActionButton {
                    label: "\u2191"
                    enabled: index > 0
                    onActivated: page.move(index, -1)
                }

                ActionButton {
                    label: "\u2193"
                    enabled: index < page.launchers.length - 1
                    onActivated: page.move(index, 1)
                }

                ActionButton {
                    label: "Unpin"
                    tone: "danger"
                    onActivated: page.unpin(index)
                }
            }
        }
    }
}
