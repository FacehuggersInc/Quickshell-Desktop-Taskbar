import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Window
import QtQuick.Controls

import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Widgets
import qs.Objects.Theme
import qs.Objects.Window.Settings



PanelWindow {
    id: mainWindow

    // Shared tooltip window — all Tooltip items delegate here
    TooltipWindow {
        id: tooltipWindow
    }

    // ## Glass
    // Blur is a property of the surface, not of the blocks, so the region is a
    // union of the four block regions. Gaps between groups stay unblurred. Each
    // block subtracts its own cut corners — see RoundedBlock.blurRegion.

    WlrLayershell.namespace: "quickshell:bar"

    property Region barBlurRegion: Region {
        regions: [
            leftModules.blurRegion,
            appbar.blurRegion,
            trayBlock.blurRegion,
            rightModules.blurRegion
        ]
    }

    BackgroundEffect.blurRegion:
        (Theme.glass && Theme.blurMode === "protocol" && !mainWindow.gamingMode)
            ? mainWindow.barBlurRegion : null
    anchors {
        top: true 
        left: true
        right: true
    }

    // ── Gaming mode ─────────────────────────────────────────────────
    property bool gamingMode: root.settings.gaming ? root.settings.gaming.enabled : false
    property int  gamingBarHeight: root.settings.gaming ? (root.settings.gaming.barHeight || 14) : 14
    property bool gamingBarRevealed: false

    // Height of the bar window in normal mode.
    property int barHeight: 42

    // Height of the RoundedBlocks themselves. Equal to barHeight means the
    // blocks fill the bar completely — drop this (e.g. 34) if you want slim
    // blocks hanging from the top edge instead.
    property int blockHeight: barHeight

    implicitHeight: gamingMode
        ? (gamingBarRevealed ? gamingBarHeight : 2)
        : barHeight
    color: '#00ffffff'

    Behavior on implicitHeight {
        NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
    }

    // Blocks sit flush against the bar window, so there is no outer padding.
    property int padding: 0
    property int spacing: 5

    // ── Gaming mode: hover zone + revealed bar ──────────────────────
    // A 2px sliver is always present so the mouse has something to enter.
    // After hovering for 1 second the bar expands to gamingBarHeight.
    MouseArea {
        id: gamingHoverZone
        anchors.fill: parent
        hoverEnabled: true
        visible: mainWindow.gamingMode
        z: 10  // above everything else in gaming mode

        onEntered: gamingRevealTimer.start()
        onExited: {
            gamingRevealTimer.stop()
            mainWindow.gamingBarRevealed = false
        }
        onClicked: {
            if (mainWindow.gamingBarRevealed) {
                // If a gaming app triggered this, just pause (show re-enter button)
                // If settings-triggered (no game running), fully exit
                if (appbar.gamingAppActive) {
                    appbar.gamingUserPaused = true
                } 
                root.settings.gaming.enabled = false
                root.saveSettings()
                mainWindow.gamingBarRevealed = false
            }
        }

        cursorShape: gamingBarRevealed ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    Timer {
        id: gamingRevealTimer
        interval: 1000
        onTriggered: mainWindow.gamingBarRevealed = true
    }

    // The visible bar content — only shown when revealed
    Rectangle {
        id: gamingBar
        anchors.fill: parent
        visible: mainWindow.gamingMode && mainWindow.gamingBarRevealed
        // Use alpha in color, NOT the opacity property — opacity cascades
        // into children and makes the clock/dot invisible
        color: Theme.alpha(Theme.scrimBase, 0.25)

        // Subtle clock
        Text {
            id: gamingClock
            anchors.centerIn: parent
            color: root.theme.text
            font.family: root.settings.fontFamily
            font.weight: 600
            font.pixelSize: 11

            Process {
                id: gamingClockProc
                command: root.newUtill(["--format", "%I:%M %p"])
                running: mainWindow.gamingMode
                stdout: StdioCollector {
                    onStreamFinished: gamingClock.text = this.text.trim()
                }
            }
            Timer {
                interval: 30000
                running: mainWindow.gamingMode
                repeat: true
                onTriggered: gamingClockProc.running = true
            }
        }

        // Notification dot
        Rectangle {
            width: 4; height: 4; radius: 2
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: gamingClock.right
            anchors.leftMargin: 6
            color: root.theme.primary
            opacity: 0.6
            visible: root.notifyServer
                ? root.notifyServer.trackedNotifications.values.length > 0
                : false
        }
    }

    // ── Normal bar content ──────────────────────────────────────────
    Pane{
        anchors.fill: parent
        visible: !mainWindow.gamingMode

        background : Rectangle {
            color: '#00000000'
            radius: 0
        }
        padding: 0

        // LEFT MODULES
        Row {
            anchors.left: parent.left
            anchors.leftMargin: mainWindow.padding
            anchors.top: parent.top
            spacing: mainWindow.spacing

            RoundedBlock {
                id: leftModules
                sidePadding: 15
                tbPadding: 0
                height: mainWindow.blockHeight

                angular: true
                flushTop: true
                flushLeft: true

                WorkspaceSwitcherWidget {
                    anchors.centerIn: parent
                }
            }
        }

        // CENTER MODULES
        Row{
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            spacing: mainWindow.spacing

            AppBarWidget{
                id: appbar
                height: mainWindow.blockHeight

                angular: true
                flushTop: true
            }
        }

        // RIGHT MODULES
        Row{
            anchors.right: parent.right
            anchors.rightMargin: mainWindow.padding
            anchors.top: parent.top
            spacing: mainWindow.spacing

            SystemTray {
                id: trayBlock
                height: mainWindow.blockHeight

                angular: true
                flushTop: true
            }

            RoundedBlock{
                id: rightModules
                height: mainWindow.blockHeight

                angular: true
                flushTop: true
                flushRight: true

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    ClockWidget {}

                    DateWidget {}

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 18
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                        color: Theme.border
                    }

                    VolumeWidget {}
                    NetworkWidget {}
                    BluetoothWidget {}
                    IconButton{
                        id: settingsIconButton
                        iconName: "settings"
                        iconSize: 22
                        color: root.theme.primary
                        tooltipText: "Open Settings"
                        onClicked: {
                            quickSettingsPopup.toggle(settingsIconButton)
                        }

                        // The dense panel is still reachable from All Settings
                        // until the granular settings window replaces it
                        QuickSettingsPopup {
                            id: quickSettingsPopup
                            onOpenFullSettings: settingsWindow.open()
                            onOpenPower: powerPopupWin.open()
                        }

                        PowerPopup {
                            id: powerPopupWin
                        }

                        SettingsWindow {
                            id: settingsWindow
                        }
                        
                    }
                    NotificationsWidget {}
                }
            }
        }
    }
}