import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects

import qs.Objects.Design
import qs.Objects.Window
import qs.Objects.Widgets

// Shared popup — used by WorkspaceSwitcher right-click AND AppBar "Send to workspace"
// Caller sets targetPid or targetClass before opening
PopupWindow {
    id: workspaceSendPopup

    anchor.window: mainWindow
    anchor.rect.x: 0
    anchor.rect.y: mainWindow.height + 5

    property int panelWidth: 200
    property int panelHeight: sendColumn.implicitHeight + 16

    implicitWidth: panelWidth
    implicitHeight: Math.max(panelHeight, 60)
    color: "transparent"
    visible: false

    // Set one of these before opening
    property string targetPid: ""    // send a specific PID
    property string targetClass: ""  // send all windows of a class
    property int targetWorkspaceId: 0  // pre-selected workspace (from dot right-click)

    property var workspaceData: []

    mask: Region { item: background }
    property bool isClosing: false

    PropertyAnimation {
        id: alphaAnim
        target: background
        property: "opacity"
        duration: 120
        onFinished: {
            if (workspaceSendPopup.isClosing) {
                workspaceSendPopup.visible = false
                workspaceSendPopup.isClosing = false
                background.opacity = 0
            }
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        active: false
        windows: [ workspaceSendPopup ]
        onCleared: {
            alphaAnim.stop()
            workspaceSendPopup.isClosing = false
            workspaceSendPopup.visible = false
            background.opacity = 0
        targetPid = ""
        targetClass = ""
        }
    }

    Process {
        id: wsListProc
        command: ["hyprctl", "workspaces", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim())
                    var ws = []
                    for (var i = 0; i < data.length; i++) {
                        if (data[i].id < 1) continue
                        ws.push({ id: data[i].id, windows: data[i].windows || 0 })
                    }
                    ws.sort(function(a, b) { return a.id - b.id })
                    // Add next empty workspace
                    var ids = ws.map(function(w) { return w.id })
                    var next = 1
                    while (ids.indexOf(next) !== -1) next++
                    ws.push({ id: next, windows: 0 })
                    workspaceSendPopup.workspaceData = ws
                } catch(e) {}
            }
        }
    }

    function sendToWorkspace(wsId) {
        var dispatch = targetPid !== ""
            ? ["hyprctl", "dispatch", "movetoworkspacesilent", wsId + ",pid:" + targetPid]
            : ["hyprctl", "dispatch", "movetoworkspacesilent", wsId + ",class:" + targetClass]
        root.execute(dispatch)
        workspaceSendPopup.forceClose()
    }

    Rectangle {
        id: background
        width: panelWidth
        height: Math.max(workspaceSendPopup.panelHeight, 60)
        radius: 10
        color: root.settings.theme.background
        opacity: 0
        clip: true

        layer.enabled: true
        layer.effect: DropShadow {
            transparentBorder: true
            horizontalOffset: 1
            verticalOffset: 1
            radius: 14
            samples: 28
            color: "#80000000"
            source: background
        }

        ColumnLayout {
            id: sendColumn
            anchors.fill: parent
            anchors.margins: 8
            spacing: 2

            Text {
                text: "Send to workspace"
                color: root.settings.theme.text
                opacity: 0.55
                font.family: root.settings.fontFamily
                font.pixelSize: 11
                font.weight: 600
                Layout.bottomMargin: 2
            }

            Repeater {
                model: workspaceSendPopup.workspaceData
                delegate: RoundButton {
                    required property var modelData
                    Layout.fillWidth: true
                    padding: 5
                    horizontalPadding: 10

                    contentItem: RowLayout {
                        spacing: 8

                        // Dot indicator
                        Rectangle {
                            width: 8; height: 8
                            radius: 4
                            color: modelData.id === workspaceSendPopup.targetWorkspaceId
                                ? root.settings.theme.primary
                                : modelData.windows > 0
                                    ? root.settings.theme.text
                                    : root.settings.theme.surface
                            opacity: modelData.windows > 0 ? 0.8 : 0.3
                        }

                        Text {
                            text: "Workspace " + modelData.id
                                + (modelData.windows === 0 ? "  (empty)" : "  (" + modelData.windows + ")")
                            font.family: root.settings.fontFamily
                            font.pixelSize: 13
                            color: root.settings.theme.text
                            Layout.fillWidth: true
                        }
                    }

                    background: Rectangle {
                        radius: 6
                        color: wsHov.hovered ? root.settings.theme.primary : "transparent"
                        opacity: wsHov.hovered ? 0.18 : 1
                    }
                    HoverHandler { id: wsHov; cursorShape: Qt.PointingHandCursor }
                    onClicked: workspaceSendPopup.sendToWorkspace(modelData.id)
                }
            }
        }
    }

    function updatePosition(widget) {
        let pos = mainWindow.itemPosition(widget)
        workspaceSendPopup.anchor.rect.x = (pos.x + widget.width / 2) - panelWidth / 2
    }

    function forceOpen(widget) {
        if (isClosing) { alphaAnim.stop(); isClosing = false }
        updatePosition(widget)
        background.opacity = 0
        workspaceSendPopup.visible = true
        alphaAnim.from = 0
        alphaAnim.to = 1.0
        alphaAnim.start()
        focusGrab.active = true
        if (!wsListProc.running) wsListProc.running = true
    }

    function forceClose() {
        if (isClosing) return
        isClosing = true
        alphaAnim.from = background.opacity
        alphaAnim.to = 0
        alphaAnim.start()
        focusGrab.active = false
        targetPid = ""
        targetClass = ""
    }

    function toggle(widget) {
        if (!workspaceSendPopup.visible || isClosing) forceOpen(widget)
        else forceClose()
    }
}