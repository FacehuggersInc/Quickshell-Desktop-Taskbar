import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme
import qs.Objects.Systems

// Gaming mode triggers. These were only reachable from the app bar context
// menu, so an app you no longer have pinned could not be removed.
ColumnLayout {
    id: page
    spacing: 0

    property int revision: 0

    readonly property var triggers: {
        var bump = page.revision + root.settingsRevision
        var gaming = root.settings.gaming || ({})
        return (gaming.apps || []).slice()
    }

    // Anything currently running is a reasonable thing to offer
    readonly property var candidates: {
        var out = []
        var seen = []
        var windows = HyprlandSystem.windows
        for (var i = 0; i < windows.length; i++) {
            var name = windows[i].appClass
            if (!name || seen.indexOf(name) !== -1)
                continue
            if (page.triggers.indexOf(name) !== -1)
                continue
            seen.push(name)
            out.push(name)
        }
        out.sort()
        return out
    }

    function setTriggers(list) {
        if (!root.settings.gaming)
            root.settings.gaming = ({ enabled: false, apps: [] })
        root.settings.gaming.apps = list
        root.saveSettings()
        page.revision++
    }

    function add(name) {
        if (!name || name.trim() === "")
            return
        var list = page.triggers
        if (list.indexOf(name.trim()) !== -1)
            return
        list.push(name.trim())
        page.setTriggers(list)
    }

    function remove(index) {
        var list = page.triggers
        list.splice(index, 1)
        page.setTriggers(list)
    }

    SectionLabel {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        text: "Gaming Mode"
    }

    SettingRow {
        Layout.fillWidth: true
        iconName: "hide"
        label: "Gaming Mode"
        description: "Collapses the bar to a sliver until you hover the edge"

        ToggleSwitch {
            checked: root.settings.gaming ? root.settings.gaming.enabled === true : false
            onToggled: (v) => {
                if (!root.settings.gaming)
                    root.settings.gaming = ({ enabled: v, apps: [] })
                else
                    root.settings.gaming.enabled = v
                root.saveSettings()
                page.revision++
            }
        }
    }

    SectionLabel {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        text: "Triggers"
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 6
        text: "Gaming mode turns itself on while one of these is running."
        wrapMode: Text.WordWrap
        color: Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: Theme.descSize
    }

    SettingRow {
        Layout.fillWidth: true
        Layout.preferredHeight: 70
        label: "Add a Trigger"
        description: "A window class, or pick one that is running now"
        stacked: true

        RowLayout {
            width: parent.width
            spacing: Theme.gap

            InputField {
                id: manualField
                Layout.fillWidth: true
                placeholder: "steam_app_000000"
                onAccepted: (v) => {
                    page.add(v)
                    manualField.text = ""
                }
            }

            SelectBox {
                width: 200
                placeholder: "Running windows"
                options: {
                    var out = []
                    for (var i = 0; i < page.candidates.length; i++)
                        out.push({ label: page.candidates[i], value: page.candidates[i] })
                    return out
                }
                onPicked: (v) => page.add(v)
            }

            ActionButton {
                label: "Add"
                tone: "accent"
                enabled: manualField.text.trim() !== ""
                onActivated: {
                    page.add(manualField.text)
                    manualField.text = ""
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 8
        visible: page.triggers.length === 0
        text: "No triggers yet."
        color: Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: Theme.descSize
    }

    Repeater {
        model: page.triggers

        delegate: Rectangle {
            required property var modelData
            required property int index

            readonly property bool running:
                HyprlandSystem.windowsInClass(modelData).length > 0

            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.preferredHeight: 46
            radius: Theme.radiusSmall
            color: Theme.alpha(Theme.scrimBase, 0.35)
            border.width: Theme.borderWidth
            border.color: running ? Theme.accentLine : Theme.alpha(Theme.textBase, 0.08)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: Theme.gap

                Icon {
                    iconName: "open_app"
                    iconSize: 16
                    color: parent.parent.running ? Theme.accentIcon : Theme.textMute
                }

                Text {
                    Layout.fillWidth: true
                    text: modelData
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.valueSize
                    font.weight: 600
                }

                Text {
                    visible: parent.parent.running
                    text: "running"
                    color: Theme.accentText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.descSize
                    font.weight: 600
                }

                ActionButton {
                    label: "Remove"
                    tone: "danger"
                    onActivated: page.remove(index)
                }
            }
        }
    }
}
