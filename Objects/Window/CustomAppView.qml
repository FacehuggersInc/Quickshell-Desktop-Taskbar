import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme

// Custom launcher form. Rebuilt on the shared controls so its rows match the
// rest of the shell instead of carrying the original hand-rolled fields.
Item {
    id: customView

    signal saveRequested(var data)

    property string appName: ""
    property string appCommand: ""
    property string appClass: ""
    property string appIcon: ""
    property bool lockOptions: false
    property bool ignoreOptions: false
    property string masqueUnder: ""
    property var options: []

    readonly property bool valid: appName.trim() !== "" && appCommand.trim() !== ""

    function reset() {
        customView.appName = ""
        customView.appCommand = ""
        customView.appClass = ""
        customView.appIcon = ""
        customView.lockOptions = false
        customView.ignoreOptions = false
        customView.masqueUnder = ""
        customView.options = []
    }

    function addOption(text) {
        if (!text || text.trim() === "")
            return
        var next = customView.options.slice()
        next.push(text.trim())
        customView.options = next
    }

    function removeOption(index) {
        var next = customView.options.slice()
        next.splice(index, 1)
        customView.options = next
    }

    // The class defaults to the command's first word, which is right often
    // enough that asking for it up front is noise
    function resolvedClass() {
        if (customView.appClass.trim() !== "")
            return customView.appClass.trim()
        var first = customView.appCommand.trim().split(" ")[0]
        return first.split("/").pop()
    }

    readonly property var pinnedNames: {
        var out = []
        var list = root.settings.launchers || []
        for (var i = 0; i < list.length; i++)
            out.push({ label: list[i].name, value: list[i].name })
        return out
    }

    ScrollView {
        anchors.fill: parent
        clip: true

        ColumnLayout {
            width: customView.width - 4
            spacing: 0

            SectionLabel {
                Layout.fillWidth: true
                text: "Application"
            }

            SettingRow {
                Layout.fillWidth: true
                label: "Name"
                description: "Shown in the bar and in tooltips"
                stacked: true

                InputField {
                    width: parent.width
                    text: customView.appName
                    placeholder: "Ghostty"
                    onTextChanged: customView.appName = text
                }
            }

            SettingRow {
                Layout.fillWidth: true
                label: "Command"
                description: "What runs when the icon is clicked"
                stacked: true

                InputField {
                    width: parent.width
                    text: customView.appCommand
                    placeholder: "ghostty"
                    onTextChanged: customView.appCommand = text
                }
            }

            SettingRow {
                Layout.fillWidth: true
                label: "Window Class"
                description: "Used to match running windows. Defaults to "
                    + (customView.resolvedClass() !== "" ? customView.resolvedClass() : "the command")
                stacked: true

                InputField {
                    width: parent.width
                    text: customView.appClass
                    placeholder: customView.resolvedClass()
                    onTextChanged: customView.appClass = text
                }
            }

            SettingRow {
                Layout.fillWidth: true
                label: "Icon"
                description: "A .desktop icon name or an absolute path. Leave empty for the default."
                stacked: true

                InputField {
                    width: parent.width
                    text: customView.appIcon
                    placeholder: "terminal"
                    onTextChanged: customView.appIcon = text
                }
            }

            SectionLabel {
                Layout.fillWidth: true
                Layout.topMargin: Theme.sectionGap
                text: "Jump List"
            }

            SettingRow {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                label: "Add an Entry"
                description: "Extra arguments offered on right click"
                stacked: true

                RowLayout {
                    width: parent.width
                    spacing: Theme.gap

                    InputField {
                        id: optionField
                        Layout.fillWidth: true
                        placeholder: "--new-window"
                    }

                    ActionButton {
                        label: "Add"
                        tone: "accent"
                        enabled: optionField.text.trim() !== ""
                        onActivated: {
                            customView.addOption(optionField.text)
                            optionField.text = ""
                        }
                    }
                }
            }

            Repeater {
                model: customView.options

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Layout.preferredHeight: 36
                    radius: Theme.radiusSmall
                    color: Theme.alpha(Theme.scrimBase, 0.35)
                    border.width: Theme.borderWidth
                    border.color: Theme.alpha(Theme.textBase, 0.08)

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: dropButton.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.valueSize
                    }

                    ActionButton {
                        id: dropButton
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Remove"
                        tone: "danger"
                        onActivated: customView.removeOption(index)
                    }
                }
            }

            SectionLabel {
                Layout.fillWidth: true
                Layout.topMargin: Theme.sectionGap
                text: "Behaviour"
            }

            SettingRow {
                Layout.fillWidth: true
                label: "Lock Jump List"
                description: "Stop the shell adding entries it discovers on its own"

                ToggleSwitch {
                    checked: customView.lockOptions
                    onToggled: (v) => customView.lockOptions = v
                }
            }

            SettingRow {
                Layout.fillWidth: true
                label: "Ignore Arguments"
                description: "Treat every window of this app as the same launcher"

                ToggleSwitch {
                    checked: customView.ignoreOptions
                    onToggled: (v) => customView.ignoreOptions = v
                }
            }

            SettingRow {
                Layout.fillWidth: true
                label: "Masque Under"
                description: "Fold this app's windows into an existing pinned icon"

                SelectBox {
                    width: 220
                    placeholder: "None"
                    options: customView.pinnedNames
                    value: customView.masqueUnder
                    onPicked: (v) => customView.masqueUnder = v
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.sectionGap
                spacing: Theme.gap

                ActionButton {
                    label: "Clear"
                    onActivated: customView.reset()
                }

                Item { Layout.fillWidth: true }

                Text {
                    visible: !customView.valid
                    text: "A name and a command are required"
                    color: Theme.textMute
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.descSize
                }

                ActionButton {
                    label: "Add to Bar"
                    tone: "accent"
                    enabled: customView.valid
                    onActivated: {
                        customView.saveRequested({
                            name: customView.appName.trim(),
                            command: customView.appCommand.trim(),
                            icon: customView.appIcon.trim(),
                            className: customView.resolvedClass(),
                            options: customView.options,
                            lockOptions: customView.lockOptions,
                            ignoreOptions: customView.ignoreOptions,
                            masqueUnder: customView.masqueUnder
                        })
                    }
                }
            }

            Item { Layout.preferredHeight: Theme.pagePadding }
        }
    }
}
