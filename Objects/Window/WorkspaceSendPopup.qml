import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Theme
import qs.Objects.Systems
import qs.Objects.Window.WorkspaceOverview

PanelWindow {
    id: sendPopup

    visible: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:send"
    WlrLayershell.keyboardFocus: sendPopup.visible ? WlrKeyboardFocus.Exclusive
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
        (sendPopup.visible && Theme.glass && Theme.blurMode === "protocol")
            ? glassBlurRegion : null

    property string targetAddress: ""
    property string targetClass: ""
    property string targetPid: ""

    property real tileHeight: 170

    // ## Owner contract
    // MonitorTile and WindowTile expect an owner. Nothing here drags, so the
    // drag half is inert and only the preview tick is real.

    signal previewTick()
    readonly property string dragAddress: ""
    readonly property string dropTarget: ""

    function open() {
        HyprlandSystem.refresh()
        sendPopup.visible = true
        keyHandler.forceActiveFocus()
        tickTimer.restart()
    }

    function close() {
        sendPopup.visible = false
    }

    function toggle() {
        if (sendPopup.visible) close()
        else open()
    }

    Timer {
        id: tickTimer
        interval: 140
        onTriggered: sendPopup.previewTick()
    }

    function sendTo(monitorName) {
        var mon = HyprlandSystem.monitorByName(monitorName)
        if (!mon) {
            close()
            return
        }

        if (sendPopup.targetAddress !== "") {
            HyprlandSystem.moveWindowToWorkspace(
                sendPopup.targetAddress, mon.activeWorkspaceId, false)
        } else if (sendPopup.targetClass !== "") {
            var wins = HyprlandSystem.windowsInClass(sendPopup.targetClass)
            for (var i = 0; i < wins.length; i++) {
                HyprlandSystem.moveWindowToWorkspace(
                    wins[i].address, mon.activeWorkspaceId, false)
            }
        }
        close()
    }

    function stashTo(bucket) {
        if (sendPopup.targetAddress !== "")
            HyprlandSystem.stashWindow(sendPopup.targetAddress, bucket)
        close()
    }

    readonly property var bucketNames: {
        var names = (root.settings.buckets || []).slice()
        var live = HyprlandSystem.specialWorkspaces()
        for (var i = 0; i < live.length; i++) {
            var short = live[i].name.replace("special:", "")
            if (names.indexOf(short) === -1)
                names.push(short)
        }
        return names
    }

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: sendPopup.visible
        Keys.onEscapePressed: sendPopup.close()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.overlayScrim

        MouseArea {
            anchors.fill: parent
            onClicked: sendPopup.close()
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 100, column.implicitWidth + 44)
        height: column.implicitHeight + 44
        radius: Theme.radius
        color: Theme.panelScrim
        border.width: Theme.borderWidth
        border.color: Theme.borderStrong

        ColumnLayout {
            id: column
            x: 22
            y: 22
            width: card.width - 44
            spacing: 14

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: sendPopup.targetClass !== ""
                    ? "Send " + sendPopup.targetClass + " to"
                    : "Send window to"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: 700
            }

            Flow {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: sendPopup.width - 160
                spacing: 22

                Repeater {
                    model: HyprlandSystem.monitors

                    delegate: MonitorTile {
                        required property var modelData

                        monitor: modelData
                        owner: sendPopup
                        tileHeight: sendPopup.tileHeight
                        selectMode: true
                        onSelected: sendPopup.sendTo(modelData.name)
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                visible: sendPopup.bucketNames.length > 0
                    && sendPopup.targetAddress !== ""
                text: "or stash it"
                color: Theme.textMute
                font.family: Theme.fontFamily
                font.pixelSize: Theme.descSize
            }

            Flow {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: sendPopup.width - 160
                spacing: 8
                visible: sendPopup.bucketNames.length > 0
                    && sendPopup.targetAddress !== ""

                Repeater {
                    model: sendPopup.bucketNames

                    delegate: Rectangle {
                        required property var modelData

                        width: bucketText.implicitWidth + 26
                        height: 32
                        radius: Theme.radiusSmall
                        color: bucketArea.containsMouse ? Theme.alpha(Theme.accent, 0.22)
                                                        : Theme.alpha(Theme.scrimBase, 0.45)
                        border.width: Theme.borderWidth
                        border.color: Theme.border

                        Text {
                            id: bucketText
                            anchors.centerIn: parent
                            text: modelData.indexOf("bucket-") === 0
                                ? "Bucket " + modelData.substring(7) : modelData
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.valueSize
                            font.weight: 600
                        }

                        MouseArea {
                            id: bucketArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sendPopup.stashTo(modelData)
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                text: "esc to cancel"
                color: Theme.textMute
                font.family: Theme.fontFamily
                font.pixelSize: Theme.descSize
            }
        }
    }
}
