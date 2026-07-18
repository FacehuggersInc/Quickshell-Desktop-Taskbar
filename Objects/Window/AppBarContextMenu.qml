import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import qs.Objects.Design
import qs.Objects.Widgets
import qs.Objects.Window

PopupPanel {
    id: popup
    implicitHeight: 350
    implicitWidth: popupColumn.implicitWidth + 16
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
                            color: root.settings.theme.text
                            opacity: 0.35
                            font.family: root.settings.fontFamily
                            font.weight: 600
                            font.pixelSize: 11
                            font.capitalization: Font.AllUppercase
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: root.settings.theme.text
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
                                source: modelData.icon
                                    ? root.iconSource(modelData.icon) : ""
                                width: 16; height: 16
                                fillMode: Image.PreserveAspectFit
                                visible: source != ""
                            }
                            Text {
                                text: actionBtn.text
                                color: root.settings.theme.text
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
                                color: root.settings.theme.primary
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
                                ? root.settings.theme.primary
                                : "transparent"
                            opacity: btnHov.hovered
                                ? (modelData.type === "submenu" ? 0.15 : 1.0)
                                : 1.0
                            border.width: modelData.type === "submenu" && btnHov.hovered ? 1 : 0
                            border.color: modelData.type === "submenu" && btnHov.hovered
                                ? root.settings.theme.primary
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
                        color: root.settings.theme.text
                        font.family: root.settings.fontFamily
                        font.pixelSize: 18
                        font.weight: 700
                        opacity: 0.5
                    }
                    Text {
                        text: popup.subMenuTitle
                        color: root.settings.theme.text
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
                    color: backHov.hovered ? root.settings.theme.primary : "transparent"
                    opacity: backHov.hovered ? 0.2 : 1
                }
                onClicked: popup.closeSubMenu()
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 8; Layout.rightMargin: 8
                height: 1; color: root.settings.theme.text; opacity: 0.08
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
                            source: modelData.icon
                                ? root.iconSource(modelData.icon) : ""
                            width: 16; height: 16
                            fillMode: Image.PreserveAspectFit
                            visible: source != ""
                        }
                        Text {
                            text: modelData.name || ""
                            color: root.settings.theme.text
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
                            ? root.settings.theme.primary : "transparent"
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
