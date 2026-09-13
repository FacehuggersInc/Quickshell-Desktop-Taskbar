import QtQuick

import qs.Objects.Design
import qs.Objects.Theme

// Opens the main menu. A widget rather than a fixture of the app bar, so it can
// be placed anywhere or left out entirely — the hotkey and the bar swipe still
// reach the menu without it.
Item {
    id: menuWidget

    implicitWidth: 26
    implicitHeight: 26

    Component.onCompleted: root.menuAnchor = menuWidget

    // Four marks rather than a gear: this opens everything, not settings
    Grid {
        anchors.centerIn: parent
        columns: 2
        spacing: 3.5

        Repeater {
            model: 4

            delegate: Rectangle {
                width: 6
                height: 6
                radius: 3
                color: menuArea.containsMouse ? Theme.accentIcon : Theme.textDim

                Behavior on color { ColorAnimation { duration: Theme.durFast } }
            }
        }
    }

    Tooltip {
        id: menuTip
        text: "Menu"
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered) menuTip.showAt(point)
            else menuTip.hide()
        }
    }

    MouseArea {
        id: menuArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mainWindow.toggleMenu()
    }
}
