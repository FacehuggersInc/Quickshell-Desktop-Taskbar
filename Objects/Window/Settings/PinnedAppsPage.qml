import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme
import qs.Objects.Systems
import qs.Objects.Window

ColumnLayout {
    id: page
    spacing: 0

    property int revision: 0
    property string expanded: ""

    readonly property var launchers: {
        var bump = page.revision + root.settingsRevision
        return (root.settings.launchers || []).slice()
    }

    readonly property var gamingApps: {
        var bump = page.revision + root.settingsRevision
        var gaming = root.settings.gaming || ({})
        return gaming.apps || []
    }

    // An entry's icon may be an absolute path, a theme name, or "*" meaning
    // resolve from the window class
    function iconFor(entry) {
        if (!entry)
            return ""

        var name = entry.icon ? String(entry.icon) : ""
        if (name !== "" && name !== "*")
            return name.charAt(0) === "/" ? "file://" + name
                                          : Quickshell.iconPath(name, true)

        var cls = entry.className ? String(entry.className) : ""
        return cls !== "" ? Quickshell.iconPath(cls, true) : ""
    }

    function commit(list) {
        root.settings.launchers = list
        root.saveSettings()
        page.revision++

        // The app bar builds its model from this list, so it has to be told
        if (root.appBar && root.appBar.syncLaunchers)
            root.appBar.syncLaunchers()
    }

    function update(index, field, value) {
        var list = page.launchers
        if (index < 0 || index >= list.length)
            return
        list[index][field] = value
        page.commit(list)
    }

    function move(index, delta) {
        var list = page.launchers
        var target = index + delta
        if (target < 0 || target >= list.length)
            return
        var item = list.splice(index, 1)[0]
        list.splice(target, 0, item)
        page.commit(list)
    }

    function unpin(index) {
        var list = page.launchers
        list.splice(index, 1)
        page.commit(list)
    }

    // These live as lists of launcher names under launcherflags, which is what
    // the app bar actually reads. Writing a boolean onto the launcher looked
    // right in config and did nothing.
    function flagged(list, name) {
        var bump = page.revision + root.settingsRevision
        var flags = root.settings.launcherflags || ({})
        var entries = flags[list] || []
        return entries.indexOf(name) !== -1
    }

    function toggleFlag(list, name) {
        if (!root.settings.launcherflags)
            root.settings.launcherflags = ({})
        if (!root.settings.launcherflags[list])
            root.settings.launcherflags[list] = []

        var entries = root.settings.launcherflags[list].slice()
        var at = entries.indexOf(name)
        if (at === -1)
            entries.push(name)
        else
            entries.splice(at, 1)

        root.settings.launcherflags[list] = entries
        root.saveSettings()
        page.revision++

        if (root.appBar && root.appBar.syncLaunchers)
            root.appBar.syncLaunchers()
    }

    function toggleGaming(className) {
        if (!root.settings.gaming)
            root.settings.gaming = ({ enabled: false, apps: [] })
        if (!root.settings.gaming.apps)
            root.settings.gaming.apps = []

        var apps = root.settings.gaming.apps.slice()
        var at = apps.indexOf(className)
        if (at >= 0)
            apps.splice(at, 1)
        else
            apps.push(className)

        root.settings.gaming.apps = apps
        root.saveSettings()
        page.revision++
    }

    // Other pinned apps, as masque targets
    function masqueOptions(current) {
        var out = [{ label: "None", value: "" }]
        var list = page.launchers
        for (var i = 0; i < list.length; i++) {
            if (list[i].name === current)
                continue
            out.push({ label: list[i].name, value: list[i].name })
        }
        return out
    }

    SectionLabel {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        text: "Pinned Applications"
    }

    SettingRow {
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        iconName: "apps"
        label: "Add Application"
        description: "Pick an installed app, or create a custom launcher"

        Row {
            spacing: 6

            ActionButton {
                label: "Installed"
                tone: "accent"
                enabled: root.addAppWindow !== null
                onActivated: {
                    if (root.addAppWindow) root.addAppWindow.openExisting()
                }
            }

            ActionButton {
                label: "Custom"
                enabled: root.addAppWindow !== null
                onActivated: {
                    if (root.addAppWindow) root.addAppWindow.openCustom()
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 8
        visible: page.launchers.length === 0
        text: "Nothing pinned yet."
        color: Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: Theme.descSize
    }

    Repeater {
        model: page.launchers

        delegate: Rectangle {
            id: appRow
            required property var modelData
            required property int index

            readonly property bool open: page.expanded === modelData.name
            readonly property bool isGaming:
                page.gamingApps.indexOf(modelData.className) !== -1

            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.preferredHeight: appRow.open ? 318 : 56
            radius: Theme.radiusSmall
            color: appRow.open ? Theme.alpha(Theme.accent, 0.10)
                               : Theme.alpha(Theme.scrimBase, 0.35)
            border.width: Theme.borderWidth
            border.color: appRow.open ? Theme.accentLine
                                      : Theme.alpha(Theme.textBase, 0.08)
            clip: true

            Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.durFast } }

            // ## Summary row
            RowLayout {
                id: summary
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                height: 40
                spacing: Theme.gap

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: Theme.radiusSmall
                    color: Theme.alpha(Theme.textBase, 0.06)

                    Image {
                        anchors.fill: parent
                        anchors.margins: 5
                        source: page.iconFor(appRow.modelData)
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: 64
                        sourceSize.height: 64
                        smooth: true
                        asynchronous: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: appRow.modelData.name
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.labelSize
                        font.weight: 600
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            var bits = [appRow.modelData.command]
                            if (appRow.isGaming) bits.push("gaming")
                            if (page.flagged("lockOptions", appRow.modelData.name))
                                bits.push("locked")
                            if (page.flagged("ignoreOptions", appRow.modelData.name))
                                bits.push("ignores args")
                            if (appRow.modelData.masqueUnder)
                                bits.push("under " + appRow.modelData.masqueUnder)
                            return bits.join("  ·  ")
                        }
                        elide: Text.ElideRight
                        color: Theme.textMute
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.descSize
                    }
                }

                ActionButton {
                    label: "\u2191"
                    enabled: appRow.index > 0
                    onActivated: page.move(appRow.index, -1)
                }

                ActionButton {
                    label: "\u2193"
                    enabled: appRow.index < page.launchers.length - 1
                    onActivated: page.move(appRow.index, 1)
                }

                ActionButton {
                    label: appRow.open ? "Done" : "Edit"
                    tone: appRow.open ? "accent" : "neutral"
                    onActivated: page.expanded = appRow.open ? "" : appRow.modelData.name
                }

                ActionButton {
                    label: "Unpin"
                    tone: "danger"
                    onActivated: page.unpin(appRow.index)
                }
            }

            // ## Editor
            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: summary.bottom
                anchors.topMargin: 4
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 0
                visible: appRow.open

                SettingRow {
                    Layout.fillWidth: true
                    label: "Name"
                    description: "Shown in the bar and its tooltip"

                    InputField {
                        width: 250
                        text: appRow.modelData.name
                        onAccepted: (v) => page.update(appRow.index, "name", v)
                    }
                }

                SettingRow {
                    Layout.fillWidth: true
                    label: "Icon"
                    description: "An icon name or an absolute path. * resolves automatically."

                    InputField {
                        width: 250
                        text: appRow.modelData.icon ? appRow.modelData.icon : ""
                        onAccepted: (v) => page.update(appRow.index, "icon", v)
                    }
                }

                SettingRow {
                    Layout.fillWidth: true
                    label: "Window Class"
                    description: "Used to match running windows to this launcher"

                    InputField {
                        width: 250
                        text: appRow.modelData.className ? appRow.modelData.className : ""
                        onAccepted: (v) => page.update(appRow.index, "className", v)
                    }
                }

                SettingRow {
                    Layout.fillWidth: true
                    label: "Gaming Trigger"
                    description: "Turn on gaming mode while this app is running"

                    ToggleSwitch {
                        checked: appRow.isGaming
                        onToggled: (v) => page.toggleGaming(appRow.modelData.className)
                    }
                }

                SettingRow {
                    Layout.fillWidth: true
                    label: "Lock Jump List"
                    description: "Stop the shell adding entries it discovers itself"

                    ToggleSwitch {
                        checked: page.flagged("lockOptions", appRow.modelData.name)
                        onToggled: (v) => page.toggleFlag("lockOptions",
                            appRow.modelData.name)
                    }
                }

                SettingRow {
                    Layout.fillWidth: true
                    label: "Ignore Arguments"
                    description: "Clicking the icon launches the bare command, "
                        + "without any jump list arguments"

                    ToggleSwitch {
                        checked: page.flagged("ignoreOptions", appRow.modelData.name)
                        onToggled: (v) => page.toggleFlag("ignoreOptions",
                            appRow.modelData.name)
                    }
                }

                SettingRow {
                    Layout.fillWidth: true
                    label: "Masque Under"
                    description: "Fold this app's windows into another pinned icon"

                    SelectBox {
                        width: 200
                        placeholder: "None"
                        options: page.masqueOptions(appRow.modelData.name)
                        value: appRow.modelData.masqueUnder
                            ? appRow.modelData.masqueUnder : ""
                        onPicked: (v) => page.update(appRow.index, "masqueUnder", v)
                    }
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 10
        text: "Text fields apply when you press Enter. Renaming a launcher does not affect windows already matched to it — that follows the window class."
        wrapMode: Text.WordWrap
        color: Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: Theme.descSize
    }
}
