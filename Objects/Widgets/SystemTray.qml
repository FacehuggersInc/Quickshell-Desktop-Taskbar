import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick.Controls.Material

import qs.Objects.Design
import qs.Objects.Window
import qs.Objects.Widgets

RoundedBlock {
    id: tray
    visible: true

    // Its content is centre anchored, so nothing reported a size. That was fine
    // while it had an explicit block height, but it now sits inside a layout.
    implicitWidth: row.implicitWidth + tray.sidePadding * 2
    implicitHeight: Math.max(24, row.implicitHeight)

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            tray.visible = row.children.length > 1 ? true : false
        }
    }

    // ## Menu
    // The platform draws its own menu through item.display(). Feeding the
    // entries into the shell's context menu instead means the tray matches the
    // app bar, including its focus grab and dismissal.

    Component.onCompleted: root.claimRightClick(tray)

    QsMenuOpener { id: rootOpener }
    QsMenuOpener { id: subOpener }

    function mapEntries(model) {
        var out = []
        var list = model ? model.values : []
        for (var i = 0; i < list.length; i++) {
            var entry = list[i]
            out.push({
                type: entry.isSeparator ? "divider"
                    : (entry.hasChildren ? "submenu" : "action"),
                name: entry.text ? entry.text : "",
                icon: "",
                entry: entry
            })
        }
        return out
    }

    function openMenu(item, anchorItem) {
        rootOpener.menu = item.menu
        subOpener.menu = null
        trayMenu.actions = tray.mapEntries(rootOpener.children)
        trayMenu.subMenuData = ({})
        trayMenu.forceOpen(anchorItem)
    }

    AppBarContextMenu {
        id: trayMenu

        onActionTriggered: (action) => {
            if (action && action.entry)
                action.entry.triggered()
        }

        // Children are only enumerable once a menu is assigned, so the submenu
        // is filled after the menu asks for it rather than up front
        onSubMenuTitleChanged: {
            if (trayMenu.subMenuTitle === "") {
                subOpener.menu = null
                return
            }
            for (var i = 0; i < trayMenu.actions.length; i++) {
                if (trayMenu.actions[i].name === trayMenu.subMenuTitle) {
                    subOpener.menu = trayMenu.actions[i].entry
                    return
                }
            }
        }
    }

    Connections {
        target: rootOpener
        function onChildrenChanged() {
            if (trayMenu.visible)
                trayMenu.actions = tray.mapEntries(rootOpener.children)
        }
    }

    Connections {
        target: subOpener
        function onChildrenChanged() {
            if (trayMenu.subMenuTitle !== "")
                trayMenu.subMenuItems = tray.mapEntries(subOpener.children)
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent

        Repeater {
            model: SystemTray.items
            delegate: Item {
                width: 24
                height: 24

                property var item: modelData

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button == Qt.LeftButton){
                            item.activate()
                        } else if (mouse.button == Qt.RightButton){
                            tray.openMenu(item, parent)
                        } 
                    }

                    IconImage {
                        id: iconImage
                        anchors.fill: parent
                        source: item.icon

                        Material.foreground: "white"

                        Tooltip {
                            id: tooltip
                            text: item.title ? item.title : "Tray App"
                        }

                        HoverHandler {
                            id: hoverHandler
                            cursorShape: Qt.PointingHandCursor
                            onHoveredChanged: {
                                if (hovered) {
                                    tooltip.showAt(hoverHandler.point)
                                } else {
                                    tooltip.hide()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}