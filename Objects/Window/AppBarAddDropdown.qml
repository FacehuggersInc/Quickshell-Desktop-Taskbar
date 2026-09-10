import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import qs.Objects.Design
import qs.Objects.Widgets
import qs.Objects.Window

PopupPanel {
    id: addDropdown
    implicitHeight: addDropdownColumn.implicitHeight + 8
    implicitWidth: Math.max(addDropdownColumn.implicitWidth + 32, 240)
    sidePadding: 0
    fadingEffectMax: 1.0
    scrollingEffect: false

    property var appWindow: null

    signal runRequested()
    signal historyRequested()

    component DropdownButton: RoundButton {
        property string iconName: ""
        Layout.fillWidth: true
        font.family: root.settings.fontFamily
        font.pixelSize: 13
        font.weight: 600
        padding: 6
        horizontalPadding: 16
        contentItem: RowLayout {
            spacing: 6
            Image {
                source: root.iconSource(parent.parent.iconName)
                width: 14; height: 14
                fillMode: Image.PreserveAspectFit
            }
            Text {
                text: parent.parent.text
                font: parent.parent.font
                color: root.theme.text
                Layout.fillWidth: true
            }
        }
        background: Rectangle {
            radius: 6
            color: dbHov.hovered ? root.theme.primary : "transparent"
            opacity: dbHov.hovered ? 0.18 : 1
        }
        HoverHandler { id: dbHov; cursorShape: Qt.PointingHandCursor }
    }

    content: ColumnLayout {
        id: addDropdownColumn
        anchors.fill: parent
        spacing: 0

        DropdownButton {
            text: "Add Pinned App\nFrom Installed Apps"
            iconName: "search"
            onClicked: {
                addDropdown.forceClose()
                if (addDropdown.appWindow) addDropdown.appWindow.openExisting()
            }
        }

        DropdownButton {
            text: "Run Command"
            iconName: "terminal"
            onClicked: {
                addDropdown.forceClose()
                addDropdown.runRequested()
            }
        }

        DropdownButton {
            text: "Command History"
            iconName: "history"
            onClicked: {
                addDropdown.forceClose()
                addDropdown.historyRequested()
            }
        }

        DropdownButton {
            text: "Add Custom Pinned App"
            iconName: "settings"
            onClicked: {
                addDropdown.forceClose()
                if (addDropdown.appWindow) addDropdown.appWindow.openCustom()
            }
        }
    }
}