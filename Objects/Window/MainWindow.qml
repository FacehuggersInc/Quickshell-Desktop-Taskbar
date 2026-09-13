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
import qs.Objects.Systems
import qs.Objects.Window.Settings



PanelWindow {
    id: mainWindow

    // Shared tooltip window — all Tooltip items delegate here
    TooltipWindow {
        id: tooltipWindow
    }

    // ## Layout from config

    // A shallow copy, so the property identity changes on every write. Returning
    // the same object reference would leave dependents thinking nothing moved
    // even though the arrays inside it had been replaced.
    readonly property var barConfig: {
        var bump = root.settingsRevision
        var source = root.settings.bar || ({})
        var out = ({})
        for (var key in source)
            out[key] = source[key]
        return out
    }
    readonly property bool atBottom: barConfig.position === "bottom"
    readonly property bool fullWidth: barConfig.style === "full"

    readonly property var leftWidgets:
        barConfig.left !== undefined ? barConfig.left : ["menu", "workspaces"]
    readonly property var centerWidgets:
        barConfig.center !== undefined ? barConfig.center : ["appbar"]

    // The app bar keeps its own block because it grows with your windows, so
    // the centre is split around it — anything listed before it sits to its
    // left, which the single trailing block made impossible.
    readonly property int appbarIndex: mainWindow.centerWidgets.indexOf("appbar")

    readonly property var centerBefore: {
        var out = []
        var stop = mainWindow.appbarIndex === -1
            ? mainWindow.centerWidgets.length : mainWindow.appbarIndex
        for (var i = 0; i < stop; i++)
            out.push(mainWindow.centerWidgets[i])
        return out
    }

    readonly property var centerAfter: {
        var out = []
        if (mainWindow.appbarIndex === -1)
            return out
        for (var i = mainWindow.appbarIndex + 1; i < mainWindow.centerWidgets.length; i++)
            out.push(mainWindow.centerWidgets[i])
        return out
    }
    readonly property var rightWidgets:
        barConfig.right !== undefined ? barConfig.right
            : ["media", "clock", "date", "separator", "volume", "mic",
               "network", "bluetooth", "tray", "notifications"]

    // Anything opened from the quick panel anchors here, since the widget that
    // owns the popup may not be the one that asked for it
    property var settingsAnchor: root.menuAnchor

    // Popups anchor under a top bar and above a bottom one
    function popupOffset(popupHeight) {
        return mainWindow.atBottom ? -(popupHeight + 5) : mainWindow.height + 5
    }

    // ## Glass
    // Blur is a property of the surface, not of the blocks, so the region is a
    // union of the four block regions. Gaps between groups stay unblurred. Each
    // block subtracts its own cut corners — see RoundedBlock.blurRegion.

    WlrLayershell.namespace: "quickshell:bar"

    property Region barBlurRegion: Region {
        regions: mainWindow.fullWidth
            ? [ fullBar.blurRegion ]
            : [
                leftModules.blurRegion,
                centerLeading.blurRegion,
                appbar.blurRegion,
                centerModules.blurRegion,
                rightModules.blurRegion
            ]
    }

    BackgroundEffect.blurRegion:
        (Theme.glass && Theme.blurMode === "protocol" && !mainWindow.gamingMode)
            ? mainWindow.barBlurRegion : null
    anchors {
        top: !mainWindow.atBottom
        bottom: mainWindow.atBottom
        left: true
        right: true
    }

    // ── Gaming mode ─────────────────────────────────────────────────
    property bool gamingMode: root.settings.gaming ? root.settings.gaming.enabled : false
    readonly property int gamingBarHeight: {
        var bump = root.settingsRevision
        return root.settings.gaming ? (root.settings.gaming.barHeight || 14) : 14
    }
    property bool gamingBarRevealed: false

    // Height of the bar window in normal mode.
    readonly property int barHeight:
        barConfig.height !== undefined ? barConfig.height : 42

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

    // Outer inset before the first block, and the gap between blocks
    readonly property int padding:
        barConfig.padding !== undefined ? barConfig.padding : 0
    readonly property int spacing:
        barConfig.spacing !== undefined ? barConfig.spacing : 5

    // Gap between widgets inside a block
    readonly property int widgetSpacing:
        barConfig.widgetSpacing !== undefined ? barConfig.widgetSpacing : 8

    // Inset between a block's edge and its widgets. This was a hardcoded 15 and
    // is what pushes the outermost widgets away from the screen edges.
    readonly property int blockPadding:
        barConfig.blockPadding !== undefined ? barConfig.blockPadding : 15

    // ## Shared popups
    // Owned by the bar window, not by the widgets. A widget removed from the
    // zone config took its popup with it, so the quick panel had nothing to open.

    AudioManagementPopup {
        id: sharedAudioPopup
        Component.onCompleted: root.audioPopup = sharedAudioPopup
    }

    NetworkPopup {
        id: sharedNetworkPopup
        Component.onCompleted: root.networkPopup = sharedNetworkPopup
    }

    BluetoothPopup {
        id: sharedBluetoothPopup
        Component.onCompleted: root.bluetoothPopup = sharedBluetoothPopup
    }

    QuickSettingsPopup {
        id: quickSettingsPopup
        onOpenFullSettings: settingsWindow.open()
        onOpenPower: powerPopupWin.open()
        onOpenSettingsPage: (page) => {
            if (page !== "")
                settingsWindow.pageId = page
            settingsWindow.open()
        }
    }

    PowerPopup {
        id: powerPopupWin
    }

    SettingsWindow {
        id: settingsWindow
    }

    CalendarWindow {
        id: calendarWindow
        Component.onCompleted: root.calendarWindow = calendarWindow
    }

    ClockWindow {
        id: clockWindow
        Component.onCompleted: root.clockWindow = clockWindow
    }

    AlertWindow {
        id: alertWindow
    }

    AlertPopup {
        id: alertPopup
    }

    // Full screen when opted in, the quiet popup otherwise — and either way the
    // clock widget animates so the bar itself shows something happened
    Connections {
        target: ClockSystem

        function onAlert(kind, label, popup) {
            root.alertPulse = Date.now()

            if (popup) {
                alertWindow.show(kind, label)
                return
            }

            root.notify("Clock", label, "history")
            alertPopup.show(kind, label,
                root.clockAnchor ? root.clockAnchor : mainWindow.settingsAnchor)
        }
    }

    // ## Menu
    // Opened from the app bar's menu button, a hotkey, or an upward swipe on
    // the bar. Centred rather than hung off a button, since it is no longer
    // tied to one.
    function toggleMenu() {
        if (quickSettingsPopup.visible)
            quickSettingsPopup.forceClose()
        else
            quickSettingsPopup.forceOpen(root.menuAnchor
                ? root.menuAnchor : mainWindow.contentItem)
    }

    IpcHandler {
        target: "menu"
        function toggle() { mainWindow.toggleMenu() }
        function open() { quickSettingsPopup.forceOpen(root.menuAnchor) }
        function close() { quickSettingsPopup.forceClose() }
    }

    // Owned here rather than reached for through the app bar
    AppBarAddDropdown {
        id: barMenu
        appWindow: root.addAppWindow

        onRunRequested: {
            if (root.barMenu) root.barMenu.runRequested()
        }
        onHistoryRequested: {
            if (root.barMenu) root.barMenu.historyRequested()
        }
        onOverviewRequested: root.overview.open()
        onPowerRequested: powerPopupWin.open()
        onWallpaperRequested: root.nextWallpaper()

        onGamingRequested: {
            if (!root.settings.gaming)
                root.settings.gaming = ({ enabled: true, apps: [] })
            else
                root.settings.gaming.enabled = !root.settings.gaming.enabled
            root.saveSettings()
        }

        onSettingsRequested: (page) => {
            if (page !== "")
                settingsWindow.pageId = page
            settingsWindow.open()
        }
    }

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

        // ## Bar context menu
        // On the bar container itself rather than its background, which sits
        // beneath the blocks and never saw the press. A handler here still sees
        // events the blocks do not take, and unlike a MouseArea it carries no
        // cursor shape, so nothing below is shadowed.
        // ## Swipe
        // Dragging up from the bar opens the menu. A handler rather than a
        // MouseArea, for the same reason the right click one is.
        DragHandler {
            id: barSwipe
            target: null
            enabled: !mainWindow.gamingMode
            yAxis.enabled: true
            xAxis.enabled: false

            property real origin: 0

            onActiveChanged: {
                if (active) {
                    barSwipe.origin = centroid.position.y
                    return
                }

                // Dragged away from whichever edge the bar sits on
                var travel = mainWindow.atBottom
                    ? barSwipe.origin - centroid.position.y
                    : centroid.position.y - barSwipe.origin

                if (travel > 18)
                    mainWindow.toggleMenu()
            }
        }

        TapHandler {
            id: barTap
            acceptedButtons: Qt.RightButton
            gesturePolicy: TapHandler.ReleaseWithinBounds
            enabled: !mainWindow.gamingMode
            onTapped: {
                if (barMenu.visible)
                    barMenu.forceClose()
                else
                    barMenu.forceOpenAt(barTap.point.position.x)
            }
        }

        // ## Full width backing
        // In full mode the per-group blocks go transparent and this single
        // block draws the bar, so the widgets keep their existing positions.

        RoundedBlock {
            id: fullBar
            visible: mainWindow.fullWidth
            z: -1

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: mainWindow.atBottom ? undefined : parent.top
            anchors.bottom: mainWindow.atBottom ? parent.bottom : undefined
            height: mainWindow.blockHeight

            sidePadding: 0
            tbPadding: 0
            angular: true
            flushLeft: true
            flushRight: true
            flushTop: !mainWindow.atBottom
            flushBottom: mainWindow.atBottom
            elevated: false
        }

        // LEFT MODULES
        Row {
            anchors.left: parent.left
            anchors.leftMargin: mainWindow.fullWidth
                ? Math.max(15, mainWindow.padding) : mainWindow.padding
            anchors.top: mainWindow.atBottom ? undefined : parent.top
            anchors.bottom: mainWindow.atBottom ? parent.bottom : undefined
            spacing: mainWindow.spacing

            RoundedBlock {
                id: leftModules
                sidePadding: mainWindow.blockPadding
                tbPadding: 0
                height: mainWindow.blockHeight
                color: mainWindow.fullWidth ? "transparent" : Theme.surface
                border: !mainWindow.fullWidth
                highlight: !mainWindow.fullWidth
                visible: mainWindow.leftWidgets.length > 0

                angular: true
                flushTop: !mainWindow.atBottom
                flushBottom: mainWindow.atBottom
                flushLeft: true

                RowLayout {
                    anchors.centerIn: parent
                    spacing: mainWindow.widgetSpacing

                    Repeater {
                        model: mainWindow.leftWidgets
                        delegate: BarWidget {
                            required property var modelData
                            widgetId: modelData
                        }
                    }
                }
            }
        }

        // CENTER MODULES
        Row{
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: mainWindow.atBottom ? undefined : parent.top
            anchors.bottom: mainWindow.atBottom ? parent.bottom : undefined
            spacing: mainWindow.spacing

            // Before the app bar
            RoundedBlock {
                id: centerLeading
                height: mainWindow.blockHeight
                sidePadding: mainWindow.blockPadding
                visible: mainWindow.centerBefore.length > 0
                color: mainWindow.fullWidth ? "transparent" : Theme.surface
                border: !mainWindow.fullWidth
                highlight: !mainWindow.fullWidth

                angular: true
                flushTop: !mainWindow.atBottom
                flushBottom: mainWindow.atBottom

                RowLayout {
                    anchors.centerIn: parent
                    spacing: mainWindow.widgetSpacing

                    Repeater {
                        model: mainWindow.centerBefore
                        delegate: BarWidget {
                            required property var modelData
                            widgetId: modelData
                        }
                    }
                }
            }

            AppBarWidget{
                id: appbar
                height: mainWindow.blockHeight

                // Inherited RoundedBlock's default 15 rather than the bar's
                // setting, so it never lined up with the blocks beside it
                sidePadding: mainWindow.blockPadding
                visible: mainWindow.centerWidgets.indexOf("appbar") !== -1
                color: mainWindow.fullWidth ? "transparent" : Theme.surface
                border: !mainWindow.fullWidth
                highlight: !mainWindow.fullWidth

                angular: true
                flushTop: !mainWindow.atBottom
                flushBottom: mainWindow.atBottom
            }

            // After the app bar
            RoundedBlock {
                id: centerModules
                height: mainWindow.blockHeight
                sidePadding: mainWindow.blockPadding
                visible: mainWindow.centerAfter.length > 0
                color: mainWindow.fullWidth ? "transparent" : Theme.surface
                border: !mainWindow.fullWidth
                highlight: !mainWindow.fullWidth

                angular: true
                flushTop: !mainWindow.atBottom
                flushBottom: mainWindow.atBottom

                RowLayout {
                    anchors.centerIn: parent
                    spacing: mainWindow.widgetSpacing

                    Repeater {
                        model: mainWindow.centerAfter
                        delegate: BarWidget {
                            required property var modelData
                            widgetId: modelData
                        }
                    }
                }
            }
        }

        // RIGHT MODULES
        Row{
            anchors.right: parent.right
            anchors.rightMargin: mainWindow.fullWidth
                ? Math.max(15, mainWindow.padding) : mainWindow.padding
            anchors.top: mainWindow.atBottom ? undefined : parent.top
            anchors.bottom: mainWindow.atBottom ? parent.bottom : undefined
            spacing: mainWindow.spacing

            RoundedBlock{
                id: rightModules
                height: mainWindow.blockHeight
                sidePadding: mainWindow.blockPadding
                color: mainWindow.fullWidth ? "transparent" : Theme.surface
                border: !mainWindow.fullWidth
                highlight: !mainWindow.fullWidth

                angular: true
                flushTop: !mainWindow.atBottom
                flushBottom: mainWindow.atBottom
                flushRight: true

                RowLayout {
                    anchors.centerIn: parent
                    spacing: mainWindow.widgetSpacing

                    Repeater {
                        model: mainWindow.rightWidgets
                        delegate: BarWidget {
                            required property var modelData
                            widgetId: modelData
                        }
                    }

                }
            }
        }
    }
}