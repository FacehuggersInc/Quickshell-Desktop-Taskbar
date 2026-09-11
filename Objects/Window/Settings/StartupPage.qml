import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme
import qs.Objects.Systems

ColumnLayout {
    id: page
    spacing: 0

    property int editingLine: -1

    SectionLabel {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        text: "Add a Startup Command"
    }

    SettingRow {
        Layout.fillWidth: true
        Layout.preferredHeight: 76
        label: "New Entry"
        description: "Appended inside your hyprland.start block"
        stacked: true

        RowLayout {
            width: parent.width
            spacing: Theme.gap

            InputField {
                id: newCommand
                Layout.fillWidth: true
                placeholder: "solaar -w hide"
            }

            ActionButton {
                label: "Add"
                tone: "accent"
                enabled: newCommand.text.trim() !== ""
                onActivated: {
                    StartupSystem.add(newCommand.text)
                    newCommand.text = ""
                }
            }
        }
    }

    SectionLabel {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        text: StartupSystem.entries.length + " Startup Commands"
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 8
        visible: StartupSystem.scanned && StartupSystem.entries.length === 0
        text: "No hyprland.start block found in ~/.config/hypr. Adding an entry needs one to exist already, since the shell will not invent a startup hook in your config."
        wrapMode: Text.WordWrap
        color: Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: Theme.descSize
    }

    Repeater {
        model: StartupSystem.entries

        delegate: Rectangle {
            id: entryRow
            required property var modelData
            required property int index

            readonly property bool editing: page.editingLine === modelData.line

            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.preferredHeight: 50
            radius: Theme.radiusSmall
            color: editing ? Theme.alpha(Theme.accent, 0.14)
                           : Theme.alpha(Theme.scrimBase, 0.35)
            border.width: Theme.borderWidth
            border.color: editing ? Theme.accentLine : Theme.alpha(Theme.textBase, 0.08)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: Theme.gap

                Text {
                    Layout.preferredWidth: 20
                    text: entryRow.index + 1
                    color: Theme.textMute
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.descSize
                    font.weight: 700
                }

                Text {
                    Layout.fillWidth: true
                    visible: !entryRow.editing
                    text: entryRow.modelData.command
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.valueSize
                }

                InputField {
                    id: editField
                    Layout.fillWidth: true
                    visible: entryRow.editing
                    text: entryRow.modelData.command
                }

                ActionButton {
                    label: entryRow.editing ? "Save" : "Edit"
                    tone: entryRow.editing ? "accent" : "neutral"
                    onActivated: {
                        if (entryRow.editing) {
                            StartupSystem.update(entryRow.modelData.file,
                                                 entryRow.modelData.line,
                                                 editField.text)
                            page.editingLine = -1
                        } else {
                            page.editingLine = entryRow.modelData.line
                        }
                    }
                }

                ActionButton {
                    label: entryRow.editing ? "Cancel" : "Remove"
                    tone: entryRow.editing ? "neutral" : "danger"
                    onActivated: {
                        if (entryRow.editing)
                            page.editingLine = -1
                        else
                            StartupSystem.remove(entryRow.modelData.file,
                                                 entryRow.modelData.line)
                    }
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 10
        text: "These run once when Hyprland starts. Order is preserved as written. Every change takes a timestamped backup of the file."
        wrapMode: Text.WordWrap
        color: Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: Theme.descSize
    }
}
