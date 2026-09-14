import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import qs.Objects.Design
import qs.Objects.Theme
import qs.Objects.Widgets
import qs.Objects.Window

PopupPanel {
    id: popup
    // Was a fixed 350, which left a large dead area under short menus. The
    // padding has to be counted here too, since the block adds it inside.
    tbPadding: 8
    implicitHeight: (popup.subMenuOpen ? subMenuCol.implicitHeight
                                       : mainCol.implicitHeight) + tbPadding * 2
    // Fixed. The content column anchors to its parent, whose width comes from
    // the popup, so sizing the popup from the column is a binding loop.
    implicitWidth: 350
    sidePadding: 0
    fadingEffectMax: 1.0

    // ── Data ────────────────────────────────────────────────────────
    // Plain JS arrays — no ListModel, so nested objects survive intact
    property var actions: []
    property var subMenuData: ({})     // name → children array

    // ── Sub-menu state ──────────────────────────────────────────────
    property var    subMenuItems: []
    property string subMenuTitle: ""
    property bool   subMenuOpen: false

    // The tray hands over whatever the application gave it — usually a
    // Quickshell image provider url, sometimes a path or a themed name. Shell
    // entries use interface icon names and must never be looked up in the icon
    // theme, which is how "send to workspace" ended up as a house.
    property bool trayMode: false

    function resolveIcon(name) {
        if (!name || name === "")
            return ""

        var text = String(name)
        if (text.indexOf("://") !== -1)
            return text
        if (text.charAt(0) === "/")
            return "file://" + text
        return Quickshell.iconPath(text, true)
    }

    function openSubMenu(title) {
        subMenuItems = subMenuData[title] || []
        subMenuTitle = title
        subMenuOpen  = true
    }
    function closeSubMenu() {
        subMenuOpen  = false
        subMenuItems = []
        subMenuTitle = ""
    }

    signal actionTriggered(var action)

    // Reset sub-menu whenever the popup closes
    onClose: closeSubMenu()

    // ── Click-outside dismiss ───────────────────────────────────────
    HyprlandFocusGrab {
        id: menuGrab
        active: false
        windows: [ popup ]
        onActiveChanged: {
            if (!active && popup.visible && !popup.isClosing) {
                popup.forceClose()
            }
        }
    }
    // Small delay before grabbing — gives the popup a frame to render
    // so the grab doesn't race against the open animation
    Timer {
        id: grabDelay
        interval: 50
        onTriggered: menuGrab.active = true
    }
    onOpen:  grabDelay.start()

    // ── Content ─────────────────────────────────────────────────────
    content: Item {
        implicitWidth:  popup.subMenuOpen ? subMenuCol.implicitWidth  : mainCol.implicitWidth
        implicitHeight: popup.subMenuOpen ? subMenuCol.implicitHeight : mainCol.implicitHeight

        // ── Main menu ───────────────────────────────────────────────
        ColumnLayout {
            id: mainCol
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0
            visible: !popup.subMenuOpen

            Repeater {
                model: popup.actions

                delegate: Item {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: modelData.type === "divider"
                        ? dividerRow.implicitHeight + 10
                        : actionBtn.implicitHeight

                    // ── Divider ──────────────────────────────────────
                    RowLayout {
                        id: dividerRow
                        visible: modelData.type === "divider"
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Text {
                            text: modelData.name || ""
                            color: Theme.text
                            opacity: 0.35
                            font.family: root.settings.fontFamily
                            font.weight: 600
                            font.pixelSize: 11
                            font.capitalization: Font.AllUppercase
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.text
                            opacity: 0.08
                        }
                    }

                    // ── Action / Sub-menu trigger button ────────────
                    RoundButton {
                        id: actionBtn
                        visible: modelData.type !== "divider"
                        anchors.left: parent.left
                        anchors.right: parent.right

                        text: modelData.name || ""
                        font.family: root.settings.fontFamily
                        font.weight: 700
                        font.pixelSize: 14
                        padding: 5
                        horizontalPadding: 10

                        contentItem: RowLayout {
                            spacing: 6
                            Image {
                                source: popup.trayMode
                                    ? popup.resolveIcon(modelData.icon) : ""
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                sourceSize.width: 32
                                sourceSize.height: 32
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                visible: popup.trayMode && source != ""
                            }

                            Icon {
                                iconName: modelData.icon ? modelData.icon : ""
                                iconSize: 15
                                color: Theme.textDim
                                visible: !popup.trayMode && modelData.icon !== undefined && modelData.icon !== ""
                            }
                            Text {
                                text: actionBtn.text
                                color: Theme.text
                                font: actionBtn.font
                                horizontalAlignment: Text.AlignLeft
                                elide: Text.ElideNone
                                wrapMode: Text.NoWrap
                                Layout.fillWidth: true
                            }
                            // Arrow for sub-menu triggers
                            Text {
                                visible: modelData.type === "submenu"
                                text: "›"
                                color: Theme.accent
                                font.family: root.settings.fontFamily
                                font.pixelSize: 18
                                font.weight: 700
                            }
                        }

                        HoverHandler {
                            id: btnHov
                            cursorShape: Qt.PointingHandCursor
                        }
                        background: Rectangle {
                            radius: 6
                            color: btnHov.hovered
                                ? Theme.accent
                                : "transparent"
                            opacity: btnHov.hovered
                                ? (modelData.type === "submenu" ? 0.15 : 1.0)
                                : 1.0
                            border.width: modelData.type === "submenu" && btnHov.hovered ? 1 : 0
                            border.color: modelData.type === "submenu" && btnHov.hovered
                                ? Theme.accent
                                : "transparent"
                        }

                        onClicked: {
                            if (modelData.type === "submenu") {
                                popup.openSubMenu(modelData.name)
                            } else {
                                popup.actionTriggered(modelData)
                                popup.forceClose()
                            }
                        }
                    }
                }
            }
        }

        // ── Sub-menu ────────────────────────────────────────────────
        ColumnLayout {
            id: subMenuCol
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0
            visible: popup.subMenuOpen

            // Back button
            RoundButton {
                Layout.fillWidth: true
                padding: 5
                horizontalPadding: 10

                contentItem: RowLayout {
                    spacing: 6
                    Text {
                        text: "‹"
                        color: Theme.text
                        font.family: root.settings.fontFamily
                        font.pixelSize: 18
                        font.weight: 700
                        opacity: 0.5
                    }
                    Text {
                        text: popup.subMenuTitle
                        color: Theme.text
                        font.family: root.settings.fontFamily
                        font.weight: 700
                        font.pixelSize: 14
                        opacity: 0.7
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                HoverHandler { id: backHov; cursorShape: Qt.PointingHandCursor }
                background: Rectangle {
                    radius: 6
                    color: backHov.hovered ? Theme.accent : "transparent"
                    opacity: backHov.hovered ? 0.2 : 1
                }
                onClicked: popup.closeSubMenu()
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 8; Layout.rightMargin: 8
                height: 1; color: Theme.text; opacity: 0.08
            }

            // Sub-menu items
            Repeater {
                model: popup.subMenuItems

                delegate: RoundButton {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true

                    text: modelData.name || ""
                    font.family: root.settings.fontFamily
                    font.weight: 700
                    font.pixelSize: 14
                    padding: 5
                    horizontalPadding: 10

                    contentItem: RowLayout {
                        spacing: 6
                        Image {
                            source: popup.trayMode
                                ? popup.resolveIcon(modelData.icon) : ""
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            sourceSize.width: 32
                            sourceSize.height: 32
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            visible: popup.trayMode && source != ""
                        }

                        Icon {
                            iconName: modelData.icon ? modelData.icon : ""
                            iconSize: 15
                            color: Theme.textDim
                            visible: !popup.trayMode && modelData.icon !== undefined && modelData.icon !== ""
                        }
                        Text {
                            text: modelData.name || ""
                            color: Theme.text
                            font: parent.parent.font
                            horizontalAlignment: Text.AlignLeft
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    HoverHandler { id: subHov; cursorShape: Qt.PointingHandCursor }
                    background: Rectangle {
                        radius: 6
                        color: subHov.hovered
                            ? Theme.accent : "transparent"
                    }
                    onClicked: {
                        popup.actionTriggered(modelData)
                        popup.forceClose()
                    }
                }
            }
        }
    }
}
