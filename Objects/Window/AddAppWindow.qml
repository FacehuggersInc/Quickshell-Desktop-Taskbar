import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

import qs.Objects.Design
import qs.Objects.Widgets

// Shared base — opened by AppBar's add button
// mode: "existing" or "custom"
Window {
    id: addAppWindow
    title: mode === "existing" ? "Add App — Choose Application" : "Add App — Custom"
    width: 600
    height: mode === "existing" ? 500 : 680
    minimumWidth: 500
    minimumHeight: 300
    color: root.settings.theme.background

    flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowCloseButtonHint

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
                // After writing to cache, trigger icon refresh in AppBar
                if (addAppWindow.onSaved) addAppWindow.onSaved()
            }
        }
    }

    function openExisting() { mode = "existing"; visible = true }
    function openCustom()   { mode = "custom";   visible = true; customView.reset() }

    // ── Shared header ─────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Text {
            text: mode === "existing" ? "Choose an Application" : "Custom App"
            color: root.settings.theme.text
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

    function saveApp(name, command, icon, className, options, lockOptions, ignoreOptions, masqueUnder) {
        // For installed apps (icon comes from .desktop file), try to resolve
        // the icon name to a full path and write it directly to the cache.
        // For custom apps with no icon, fall back to "*" for auto-lookup.
        var resolvedIcon = "*"
        if (icon && icon !== "" && icon !== "*") {
            // icon from .desktop is a name like "code" or a full path
            // Write it to cache so getappicons uses it directly
            writeIconCacheProc.className = className
            writeIconCacheProc.iconName  = icon
            writeIconCacheProc.command   = root.newUtill(["--setappicon", className, icon])
            writeIconCacheProc.running   = true
            resolvedIcon = icon
        }

        var entry = {
            name:     className,
            nickname: name,
            icon:     resolvedIcon,
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

        // If no icon to write, notify AppBar to rebuild immediately
        // (if writing icon, onSaved is called from writeIconCacheProc.onStreamFinished)
        if (resolvedIcon === "*") {
            if (onSaved) onSaved()
        }

        addAppWindow.visible = false
    }
}