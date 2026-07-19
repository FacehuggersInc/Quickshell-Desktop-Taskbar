import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Hyprland

import qs.Objects.Design
import qs.Objects.Window
import qs.Objects.Widgets

Item {
    id: workspaceSwitcher
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    property int activeWorkspace: 1
    property var workspaceData: []  // [{id, windowCount}]

    // ── Fetch workspace + window data ─────────────────────────────
    Process {
        id: workspaceProc
        command: root.cmd("hypr_list_workspaces")
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim())
                    var ws = []
                    for (var i = 0; i < data.length; i++) {
                        var w = data[i]
                        // Skip special workspaces
                        if (w.id < 1) continue
                        ws.push({ id: w.id, windowCount: w.windows || 0 })
                    }
                    // Sort by id
                    ws.sort(function(a, b) { return a.id - b.id })
                    workspaceSwitcher.workspaceData = ws
                } catch(e) {}
            }
        }
    }

    Process {
        id: activeProc
        command: root.cmd("hypr_active_workspace")
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim())
                    workspaceSwitcher.activeWorkspace = data.id || 1
                } catch(e) {}
            }
        }
    }

    // Workspace list refreshes every 2s (windows change less often)
    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!workspaceProc.running) workspaceProc.running = true
        }
    }

    // Active workspace polls every 200ms for snappy switching feel
    Timer {
        interval: 200
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!activeProc.running) activeProc.running = true
        }
    }

    function switchTo(id) {
        root.execute(root.cmd("hypr_switch_workspace", {"id": String(id)}))
    }

    function createWorkspace() {
        var ids = workspaceData.map(function(w) { return w.id })
        var next = 1
        while (ids.indexOf(next) !== -1) next++
        root.execute(root.cmd("hypr_switch_workspace", {"id": String(next)}))
    }

    // ── Dot pager ─────────────────────────────────────────────────
    RowLayout {
        id: row
        spacing: 6

        Repeater {
            model: workspaceSwitcher.workspaceData
            delegate: Item {
                required property var modelData
                required property int index

                property bool isActive: modelData.id === workspaceSwitcher.activeWorkspace
                property int winCount: modelData.windowCount

                // Width grows with window count, height stays fixed
                width:  Math.min(10 + winCount * 6, 32)
                height: 10

                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: isActive
                        ? root.settings.theme.primary
                        : winCount > 0
                            ? root.settings.theme.text
                            : root.settings.theme.text
                    opacity: isActive ? 1.0 : winCount > 0 ? 0.55 : 0.2

                    Behavior on opacity { NumberAnimation { duration: 100 } }
                    Behavior on color   { ColorAnimation  { duration: 100 } }

                    // Bright outline on active workspace for extra visibility
                    Rectangle {
                        visible: isActive
                        anchors.fill: parent
                        anchors.margins: -2
                        radius: parent.radius + 2
                        color: "transparent"
                        border.color: root.settings.theme.primary
                        border.width: 1.5
                        opacity: 0.5
                    }
                }

                HoverHandler { id: dotHov; cursorShape: Qt.PointingHandCursor }

                Tooltip {
                    id: dotTooltip
                    text: "Workspace " + modelData.id
                        + (winCount > 0 ? "  (" + winCount + " windows)" : "")
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            workspaceSwitcher.switchTo(modelData.id)
                        } else {
                            workspaceSendPopup.targetWorkspaceId = modelData.id
                            workspaceSendPopup.toggle(workspaceSwitcher)
                        }
                    }
                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered) dotTooltip.showAt(point)
                            else dotTooltip.hide()
                        }
                    }
                }
            }
        }

        // Add workspace button
        IconButton{
            id: addWsBtn
            iconName: "add"
            iconSize: 16

            onClicked: workspaceSwitcher.createWorkspace()
        }
    }
}