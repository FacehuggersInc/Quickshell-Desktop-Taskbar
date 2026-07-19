import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Window
import QtQuick.Controls

import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Widgets



PanelWindow {
    id: mainWindow

    // Shared tooltip window — all Tooltip items delegate here
    TooltipWindow {
        id: tooltipWindow
    }
    anchors {
        top: true
        left: true
        right: true
    }

    // ── Gaming mode ─────────────────────────────────────────────────
    property bool gamingMode: root.settings.gaming ? root.settings.gaming.enabled : false
    property int  gamingBarHeight: root.settings.gaming ? (root.settings.gaming.barHeight || 14) : 14
    property bool gamingBarRevealed: false

    implicitHeight: gamingMode
        ? (gamingBarRevealed ? gamingBarHeight : 2)
        : 60
    color: '#00ffffff'

    Behavior on implicitHeight {
        NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
    }

    property int padding: 8
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
        color: {
            var c = root.settings.theme.surface
            return Qt.rgba(c.r, c.g, c.b, 0.25)
        }

        // Subtle clock
        Text {
            id: gamingClock
            anchors.centerIn: parent
            color: root.settings.theme.text
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
            color: root.settings.theme.primary
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
        topPadding: mainWindow.padding

        // LEFT MODULES
        Row {
            anchors.left: parent.left
            anchors.leftMargin: mainWindow.padding
            anchors.verticalCenter: parent.verticalCenter
            spacing: mainWindow.spacing

            RoundedBlock {
                id: leftModules
                anchors.verticalCenter: parent.verticalCenter
                sidePadding: 15
                tbPadding: 0
                // Match implicit height to rightModules so they look the same
                implicitHeight: rightModules.implicitHeight

                WorkspaceSwitcherWidget {
                    anchors.centerIn: parent
                }
            }
        }
        
        // CENTER MODULES
        Row{
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: mainWindow.spacing

            AppBarWidget{
                id: appbar
                implicitHeight: rightModules.height 
            }
        }
        
        // RIGHT MODULES
        Row{
            anchors.right: parent.right
            anchors.rightMargin: mainWindow.padding
            anchors.verticalCenter: parent.verticalCenter
            spacing: mainWindow.spacing

            SystemTray {
                implicitHeight: rightModules.height
            }

            RoundedBlock{
                id: rightModules
                
                RowLayout {
                    spacing: 8

                    ColorPickerWidget {}
                    VolumeWidget {}
                    DatetimeWidget { 
                        format: root.settings.timeDateFormat
                        textColor: '#7be376'
                    }
                    InterfaceWidget {}
                    BluetoothWidget {}
                    IconButton{
                        id: settingsIconButton
                        iconName: "settings"
                        iconSize: 22
                        color: root.settings.theme.primary
                        tooltipText: "Open Settings"
                        onClicked: {
                            settingsPopupWin.toggle(settingsIconButton) 
                        }

                        SettingsManagementPopup{
                            id: settingsPopupWin
                        }
                        
                    }
                    NotificationsWidget {}
                }
            }
        }
    }
}