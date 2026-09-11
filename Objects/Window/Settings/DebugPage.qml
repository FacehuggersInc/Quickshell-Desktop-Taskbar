import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme
import qs.Objects.Systems

ColumnLayout {
    id: page
    spacing: 0

    component Fact: Rectangle {
        property string label: ""
        property string value: ""

        Layout.fillWidth: true
        Layout.topMargin: 4
        Layout.preferredHeight: 42
        radius: Theme.radiusSmall
        color: Theme.alpha(Theme.scrimBase, 0.30)
        border.width: Theme.borderWidth
        border.color: Theme.alpha(Theme.textBase, 0.08)

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 190
            text: parent.label
            elide: Text.ElideRight
            color: Theme.textMute
            font.family: Theme.fontFamily
            font.pixelSize: Theme.descSize
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 205
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: parent.value
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.valueSize
        }
    }

    SectionLabel {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        text: "Shell"
    }

    Fact { label: "Config valid"; value: root.configValid ? "yes" : "no" }
    Fact { label: "Config writes"; value: String(root.settingsRevision) }
    Fact { label: "Utility script"; value: root.utill.length > 1 ? root.utill[1] : "" }
    Fact { label: "Icon source"; value: IconMap.useFont ? IconMap.family : "bundled folder" }
    Fact { label: "Theme mode"; value: root.darkMode ? "dark" : "light" }
    Fact { label: "Blur mode"; value: Theme.glass ? Theme.blurMode : "glass off" }

    SectionLabel {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        text: "Compositor"
    }

    Fact { label: "Config provider"; value: HyprlandSystem.lua ? "lua" : "hyprlang" }
    Fact { label: "Monitors"; value: String(HyprlandSystem.monitors.length) }
    Fact { label: "Workspaces"; value: String(HyprlandSystem.workspaces.length) }
    Fact { label: "Windows"; value: String(HyprlandSystem.windows.length) }
    Fact {
        label: "Focused"
        value: HyprlandSystem.focusedMonitor + "  ·  ws "
            + HyprlandSystem.focusedWorkspaceId
    }

    SectionLabel {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        text: "Services"
    }

    Fact {
        label: "Brightness"
        value: BrightnessSystem.available
            ? BrightnessSystem.displays.length + " ddc displays"
            : (BrightnessSystem.ready ? "none found" : "reading")
    }
    Fact {
        label: "Packages"
        value: PackageSystem.scanned
            ? PackageSystem.packages.length + " listed, "
              + PackageSystem.updateCount + " updates"
            : "not read yet"
    }
    Fact {
        label: "AUR helper"
        value: PackageSystem.helper
    }
    Fact {
        label: "Mime types"
        value: MimeSystem.scanned ? String(MimeSystem.entries.length) : "not read yet"
    }
    Fact {
        label: "Hyprland binds"
        value: HotkeySystem.scanned ? String(HotkeySystem.binds.length) : "not read yet"
    }

    SectionLabel {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        text: "Actions"
    }

    SettingRow {
        Layout.fillWidth: true
        label: "Reload Everything"
        description: "Re-read monitors, binds, startup, mime and packages"

        ActionButton {
            label: "Reload"
            tone: "accent"
            onActivated: {
                HyprlandSystem.refresh()
                BrightnessSystem.read()
                HotkeySystem.refresh()
                StartupSystem.refresh()
                MimeSystem.refresh()
                PackageSystem.refresh()
            }
        }
    }
}
