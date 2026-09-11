import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Theme
import qs.Objects.Systems

PanelWindow {
    id: powerPopup

    visible: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:power"
    WlrLayershell.keyboardFocus: powerPopup.visible ? WlrKeyboardFocus.Exclusive
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
        (powerPopup.visible && Theme.glass && Theme.blurMode === "protocol")
            ? glassBlurRegion : null

    readonly property var actions: [
        { icon: "download", key: "update", label: "Update System",
          desc: powerUpdateLabel.text, danger: false },
        { icon: "lock", key: "lock", label: "Lock", desc: "Lock the session", danger: false },
        { icon: "hide", key: "logout", label: "Log Out", desc: "End the session", danger: false },
        { icon: "dark_mode", key: "suspend", label: "Suspend", desc: "Sleep to RAM", danger: false },
        { icon: "restart", key: "reboot", label: "Restart", desc: "Reboot now", danger: true },
        { icon: "stop", key: "poweroff", label: "Power Off", desc: "Shut down now", danger: true }
    ]

    function open() {
        powerPopup.visible = true
        keyHandler.forceActiveFocus()
    }

    function close() {
        powerPopup.visible = false
    }

    function toggle() {
        if (powerPopup.visible) close()
        else open()
    }

    function run(key) {
        close()
        if (key === "update") {
            PackageSystem.updateAll()
            return
        }
        root.cmdExec(key)
    }

    // Kept as an item so the description tracks the update count
    QtObject {
        id: powerUpdateLabel
        readonly property string text: PackageSystem.updateCount > 0
            ? PackageSystem.updateCount + " updates waiting"
            : "Check for and install updates"
    }

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: powerPopup.visible
        Keys.onEscapePressed: powerPopup.close()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.overlayScrim

        MouseArea {
            anchors.fill: parent
            onClicked: powerPopup.close()
        }
    }

    Rectangle {
        id: card

        // Swallows clicks so empty space inside the card does not reach the
        // dismiss area behind it
        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.AllButtons
            onClicked: {}
            onPressed: {}
        }
        anchors.centerIn: parent
        width: 300
        height: column.implicitHeight + 28
        radius: Theme.radius
        color: Theme.panelScrim
        border.width: Theme.borderWidth
        border.color: Theme.borderStrong

        ColumnLayout {
            id: column
            x: 14
            y: 14
            width: card.width - 28
            spacing: 3

            Text {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                text: "Session"
                color: Theme.textMute
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: 700
                font.letterSpacing: 1.2
            }

            Repeater {
                model: powerPopup.actions

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: Theme.radiusSmall
                    color: rowArea.containsMouse
                        ? Theme.alpha(modelData.danger ? Theme.danger : Theme.accent, 0.20)
                        : "transparent"

                    Behavior on color { ColorAnimation { duration: Theme.durFast } }

                    Icon {
                        id: rowIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: modelData.icon
                        iconSize: 18
                        color: rowArea.containsMouse
                            ? (modelData.danger ? Theme.danger : Theme.accentText)
                            : Theme.textDim
                    }

                    Column {
                        anchors.left: rowIcon.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        Text {
                            text: modelData.label
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.labelSize
                            font.weight: 600
                        }

                        Text {
                            text: modelData.desc
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
                        onClicked: powerPopup.run(modelData.key)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 6
                horizontalAlignment: Text.AlignHCenter
                text: "esc to dismiss"
                color: Theme.textMute
                font.family: Theme.fontFamily
                font.pixelSize: Theme.descSize
            }
        }
    }
}
