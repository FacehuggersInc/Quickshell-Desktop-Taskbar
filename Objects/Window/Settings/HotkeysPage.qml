import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme
import qs.Objects.Systems

ColumnLayout {
    id: page
    spacing: 0

    property string query: ""
    property int editingLine: -1
    property string draftKey: ""
    property string draftCommand: ""

    readonly property var binds: HotkeySystem.binds

    readonly property var filtered: {
        var q = page.query.trim().toLowerCase()
        if (!q)
            return page.binds

        var out = []
        for (var i = 0; i < page.binds.length; i++) {
            var b = page.binds[i]
            if (b.key.toLowerCase().indexOf(q) !== -1
                    || b.detail.toLowerCase().indexOf(q) !== -1
                    || b.kind.toLowerCase().indexOf(q) !== -1) {
                out.push(b)
            }
        }
        return out
    }

    SectionLabel {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        text: "Add a Binding"
    }

    SettingRow {
        Layout.fillWidth: true
        Layout.preferredHeight: 76
        label: "New Shortcut"
        description: "Written into your Hyprland lua config, grouped with the others"
        stacked: true

        RowLayout {
            width: parent.width
            spacing: Theme.gap

            InputField {
                id: newKey
                Layout.preferredWidth: 200
                placeholder: "SUPER + K"
            }

            InputField {
                id: newCommand
                Layout.fillWidth: true
                placeholder: "Command to run"
            }

            ActionButton {
                label: "Add"
                tone: "accent"
                enabled: newKey.text.trim() !== "" && newCommand.text.trim() !== ""
                onActivated: {
                    HotkeySystem.add(newKey.text.trim(), newCommand.text.trim())
                    newKey.text = ""
                    newCommand.text = ""
                }
            }
        }
    }

    SectionLabel {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        text: page.binds.length + " Bindings"
    }

    SettingRow {
        Layout.fillWidth: true
        label: "Filter"
        stacked: true

        InputField {
            width: parent.width
            placeholder: "Search by key, command or action"
            onTextChanged: page.query = text
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 8
        visible: HotkeySystem.scanned && page.binds.length === 0
        text: "No hl.bind calls found in ~/.config/hypr."
        color: Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: Theme.descSize
    }

    Repeater {
        model: page.filtered

        delegate: Rectangle {
            id: bindRow
            required property var modelData

            readonly property bool editing: page.editingLine === modelData.line
            readonly property bool editable: modelData.kind === "exec"

            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.preferredHeight: editing ? 96 : 54
            radius: Theme.radiusSmall
            color: editing ? Theme.alpha(Theme.accent, 0.14)
                           : Theme.alpha(Theme.scrimBase, 0.35)
            border.width: Theme.borderWidth
            border.color: editing ? Theme.accentLine : Theme.alpha(Theme.textBase, 0.08)

            Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.durFast } }

            // ## Summary

            Item {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                height: 38
                visible: !bindRow.editing

                Rectangle {
                    id: keyChip
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: keyText.implicitWidth + 18
                    height: 26
                    radius: Theme.radiusSmall
                    color: Theme.alpha(Theme.textBase, 0.10)
                    border.width: Theme.borderWidth
                    border.color: Theme.border

                    Text {
                        id: keyText
                        anchors.centerIn: parent
                        text: bindRow.modelData.key
                        color: Theme.accentText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.valueSize
                        font.weight: 700
                    }
                }

                Column {
                    anchors.left: keyChip.right
                    anchors.leftMargin: 12
                    anchors.right: rowButtons.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: bindRow.modelData.kind === "exec"
                            ? bindRow.modelData.detail
                            : bindRow.modelData.kind
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.labelSize
                    }

                    Text {
                        width: parent.width
                        text: bindRow.modelData.options !== ""
                            ? bindRow.modelData.options
                            : (bindRow.modelData.kind === "exec" ? "run a command" : bindRow.modelData.action)
                        elide: Text.ElideRight
                        color: Theme.textMute
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.descSize
                    }
                }

                Row {
                    id: rowButtons
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    ActionButton {
                        label: bindRow.editable ? "Edit" : "Locked"
                        enabled: bindRow.editable
                        onActivated: {
                            page.draftKey = bindRow.modelData.key
                            page.draftCommand = bindRow.modelData.detail
                            page.editingLine = bindRow.modelData.line
                        }
                    }

                    ActionButton {
                        label: "Delete"
                        tone: "danger"
                        onActivated: HotkeySystem.remove(
                            bindRow.modelData.file, bindRow.modelData.line)
                    }
                }
            }

            // ## Editor

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 10
                spacing: Theme.gap
                visible: bindRow.editing

                InputField {
                    id: editKey
                    Layout.preferredWidth: 190
                    text: page.draftKey
                    placeholder: "SUPER + K"
                }

                InputField {
                    id: editCommand
                    Layout.fillWidth: true
                    text: page.draftCommand
                    placeholder: "Command to run"
                }

                ActionButton {
                    label: "Save"
                    tone: "accent"
                    onActivated: {
                        HotkeySystem.update(
                            bindRow.modelData.file, bindRow.modelData.line,
                            editKey.text.trim(), editCommand.text,
                            bindRow.modelData.options)
                        page.editingLine = -1
                    }
                }

                ActionButton {
                    label: "Cancel"
                    onActivated: page.editingLine = -1
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 10
        text: "Only command bindings can be edited here. Ones that call a dispatcher directly are shown but left alone, since rewriting their arguments needs more than a text field. Every write takes a timestamped backup."
        wrapMode: Text.WordWrap
        color: Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: Theme.descSize
    }
}
