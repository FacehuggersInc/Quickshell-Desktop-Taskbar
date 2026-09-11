import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme
import qs.Objects.Widgets
import qs.Objects.Window

// Run a command. Rebuilt on the shared controls, with history and matching
// applications offered as you type rather than a bare text field.
PopupPanel {
    id: runPopup

    implicitWidth: 760
    implicitHeight: body.implicitHeight + tbPadding * 2
    sidePadding: 12
    tbPadding: 12
    fadingEffectMax: 1.0
    scrollingEffect: false
    requireFocusGrab: true

    signal launched(string command)

    property string query: ""
    property var history: []
    readonly property int maxSuggestions: 6

    readonly property var suggestions: {
        var q = runPopup.query.trim().toLowerCase()
        var out = []

        // Recent commands first — they are what you usually want again
        for (var h = 0; h < runPopup.history.length; h++) {
            var past = runPopup.history[h]
            if (q === "" || past.toLowerCase().indexOf(q) !== -1)
                out.push({ label: past, detail: "recent", command: past })
            if (out.length >= runPopup.maxSuggestions)
                return out
        }

        if (q === "")
            return out

        var apps = DesktopEntries.applications
            ? DesktopEntries.applications.values : []
        for (var i = 0; i < apps.length; i++) {
            var entry = apps[i]
            if (!entry.id || entry.noDisplay)
                continue

            var name = entry.name || entry.id
            var exec = entry.execString || ""
            if (name.toLowerCase().indexOf(q) === -1
                    && exec.toLowerCase().indexOf(q) === -1)
                continue

            var already = false
            for (var j = 0; j < out.length; j++) {
                if (out[j].command === exec) already = true
            }
            if (already)
                continue

            out.push({ label: name, detail: exec, command: exec, entry: entry })
            if (out.length >= runPopup.maxSuggestions)
                break
        }
        return out
    }

    function remember(command) {
        var next = []
        next.push(command)
        for (var i = 0; i < runPopup.history.length && next.length < 12; i++) {
            if (runPopup.history[i] !== command)
                next.push(runPopup.history[i])
        }
        runPopup.history = next
    }

    function runCommand(command, inTerminal) {
        var text = String(command).trim()
        if (text === "")
            return

        runPopup.remember(text)

        if (inTerminal) {
            var custom = (root.settings.commands || ({})).terminal_run || ""
            if (custom.indexOf("{command}") !== -1)
                root.execute(root.cmd("terminal_run", { "command": text }))
            else
                root.execute(root.cmd("terminal_run").concat([text]))
        } else {
            root.execute(text.split(" "))
        }

        runPopup.launched(text)
        runPopup.forceClose()
        runField.text = ""
        runPopup.query = ""
    }

    onOpen: {
        runField.text = ""
        runPopup.query = ""
        runField.focusInput()
    }

    content: ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        Keys.onEscapePressed: runPopup.forceClose()

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Icon {
                iconName: "terminal"
                iconSize: 20
                color: Theme.accentIcon
            }

            InputField {
                id: runField
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                placeholder: "Run a command or search applications"
                onTextChanged: runPopup.query = text

                // Only on Enter. committed() also fires when focus leaves,
                // which would run the command on dismissal.
                onAccepted: (v) => runPopup.runCommand(v, false)
            }

            ActionButton {
                label: "Run"
                tone: "accent"
                enabled: runField.text.trim() !== ""
                onActivated: runPopup.runCommand(runField.text, false)
            }

            ActionButton {
                label: "Terminal"
                enabled: runField.text.trim() !== ""
                onActivated: runPopup.runCommand(runField.text, true)
            }

            ActionButton {
                label: "Close"
                onActivated: runPopup.forceClose()
            }
        }

        Repeater {
            model: runPopup.suggestions

            delegate: Rectangle {
                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: Theme.radiusSmall
                color: suggestArea.containsMouse ? Theme.alpha(Theme.accent, 0.18)
                                                 : Theme.alpha(Theme.scrimBase, 0.30)
                border.width: Theme.borderWidth
                border.color: Theme.alpha(Theme.textBase, 0.08)

                Icon {
                    id: suggestIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: modelData.detail === "recent" ? "history" : "open_app"
                    iconSize: 14
                    color: Theme.textMute
                }

                Column {
                    anchors.left: suggestIcon.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                        width: parent.width
                        text: modelData.label
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.valueSize
                        font.weight: 600
                    }

                    Text {
                        width: parent.width
                        text: modelData.detail
                        elide: Text.ElideRight
                        color: Theme.textMute
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.descSize
                    }
                }

                MouseArea {
                    id: suggestArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: runPopup.runCommand(modelData.command, false)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: runPopup.suggestions.length === 0
            text: "Enter runs directly, Terminal runs it in a shell window. Escape or clicking away closes this."
            color: Theme.textMute
            font.family: Theme.fontFamily
            font.pixelSize: Theme.descSize
        }
    }
}
