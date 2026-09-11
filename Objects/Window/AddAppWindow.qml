import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import qs.Objects.Design
import qs.Objects.Theme
import qs.Objects.Systems
import qs.Objects.Widgets

// Shared base — opened by AppBar's add button
// mode: "existing" or "custom"
PanelWindow {
    id: addAppWindow

    visible: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:addapp"
    WlrLayershell.keyboardFocus: addAppWindow.visible ? WlrKeyboardFocus.Exclusive
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
        (addAppWindow.visible && Theme.glass && Theme.blurMode === "protocol")
            ? glassBlurRegion : null

    property string mode: "existing"   // "existing" or "custom"

    // Callback set by AppBar before opening
    property var onSaved: null

    // Writes a specific icon to the cache for a given class name
    Process {
        id: writeIconCacheProc
        property string className: ""
        property string iconName: ""
        stdout: StdioCollector {
            onStreamFinished: {
                var resolved = this.text.trim()
                // Update the launcher entry with the resolved icon path
                if (resolved && resolved !== "") {
                    for (var i = 0; i < root.settings.launchers.length; i++) {
                        if (root.settings.launchers[i].name === writeIconCacheProc.className) {
                            root.settings.launchers[i].icon = resolved
                            root.saveSettings()
                            break
                        }
                    }
                }
                if (addAppWindow.onSaved) addAppWindow.onSaved()
            }
        }
    }

    function openExisting() {
        mode = "existing"
        visible = true
        existingView.refresh()
        keyHandler.forceActiveFocus()
    }

    function openCustom() {
        mode = "custom"
        visible = true
        customView.reset()
        keyHandler.forceActiveFocus()
    }

    function close() { addAppWindow.visible = false }

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: addAppWindow.visible
        Keys.onEscapePressed: addAppWindow.close()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.overlayScrim

        MouseArea {
            anchors.fill: parent
            onClicked: addAppWindow.close()
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
        width: Math.min(parent.width - 140,
                        addAppWindow.mode === "existing" ? 680 : 760)
        // The custom form is a long column of fields; at 700 it was scrolling
        // in a stub of a window with every control squeezed
        height: addAppWindow.mode === "existing"
            ? Math.min(parent.height - 140, 620)
            : Math.min(parent.height - 80, 900)
        radius: Theme.radius
        color: Theme.panelScrim
        border.width: Theme.borderWidth
        border.color: Theme.borderStrong
        clip: true

    // ── Shared header ─────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        Text {
            text: mode === "existing" ? "Choose an Application" : "Custom App"
            color: root.theme.text
            font.family: root.settings.fontFamily
            font.weight: 700
            font.pixelSize: 20
        }

        // ── Existing app view ─────────────────────────────────────
        ExistingAppView {
            id: existingView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: mode === "existing"
            onAppSelected: function(name, exec, icon, className) {
                addAppWindow.saveApp(name, exec, icon, className, [], false, false)
            }
        }

        // ── Custom app view ───────────────────────────────────────
        CustomAppView {
            id: customView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: mode === "custom"
            onSaveRequested: function(data) {
                addAppWindow.saveApp(
                    data.name, data.command, data.icon,
                    data.className, data.options,
                    data.lockOptions, data.ignoreOptions,
                    data.masqueUnder
                )
            }
        }
    }

    }

    function saveApp(name, command, icon, className, options, lockOptions, ignoreOptions, masqueUnder) {
        // Always store "*" initially so QML shows the default icon
        // and the icon resolution queue picks it up.
        // If we have a .desktop icon name, run setappicon to resolve
        // the real path — its stdout handler updates the launcher entry.
        var hasDesktopIcon = icon && icon !== "" && icon !== "*"

        var entry = {
            name:     className,
            nickname: name,
            icon:     "*",
            command:  command,
            options:  options
        }

        // Push to settings
        root.settings.launchers.push(entry)

        // Handle flags
        if (lockOptions && !root.settings.launcherflags.lockOptions.includes(className)) {
            root.settings.launcherflags.lockOptions.push(className)
        }
        if (ignoreOptions && !root.settings.launcherflags.ignoreOptions.includes(className)) {
            root.settings.launcherflags.ignoreOptions.push(className)
        }

        // Handle masque — set classIncludes on the target pinned launcher
        if (masqueUnder && masqueUnder !== "") {
            for (var i = 0; i < root.settings.launchers.length; i++) {
                if (root.settings.launchers[i].name === masqueUnder) {
                    root.settings.launchers[i].masque = { classIncludes: className }
                    break
                }
            }
        }

        root.saveSettings()

        // Trigger AppBar rebuild immediately so the new icon (as "*") appears
        if (onSaved) onSaved()

        // If we have a .desktop icon name, resolve it asynchronously.
        // When setappicon returns, its stdout handler updates the launcher
        // entry with the real path and triggers another rebuild.
        if (hasDesktopIcon) {
            writeIconCacheProc.className = className
            writeIconCacheProc.iconName  = icon
            writeIconCacheProc.command   = root.newUtill(["--setappicon", className, icon])
            writeIconCacheProc.running   = true
        }

        addAppWindow.close()
    }
}
