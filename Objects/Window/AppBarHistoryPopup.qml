import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme
import qs.Objects.Systems
import qs.Objects.Window

// Two sources in one list: what this shell launched, and what the user typed in
// a terminal. Rebuilt on the shared controls, searchable, with the source of
// each entry stated rather than mixed silently.
PopupPanel {
    id: historyPopup

    implicitWidth: 720

    // Capped, then the list scrolls. Forty rows at 44px ran off the screen.
    readonly property int maxHeight:
        Math.min(560, Screen.height - mainWindow.height - 40)
    implicitHeight: Math.min(body.implicitHeight + tbPadding * 2, historyPopup.maxHeight)
    sidePadding: 14
    tbPadding: 12
    fadingEffectMax: 1.0
    scrollingEffect: false
    requireFocusGrab: true

    // Kept from the previous version: the app bar listens for this to show its
    // launch confirmation
    signal commandSelected(string command)

    property var shellHistory: []
    property string query: ""
    property string source: "all"

    readonly property var entries: {
        var q = historyPopup.query.trim().toLowerCase()
        var out = []

        if (historyPopup.source !== "shell") {
            var recents = RecentSystem.combined
            for (var i = 0; i < recents.length; i++) {
                if (q === "" || recents[i].label.toLowerCase().indexOf(q) !== -1)
                    out.push({
                        text: recents[i].payload,
                        label: recents[i].label,
                        origin: RecentSystem.relative(recents[i].at),
                        fromShell: false
                    })
            }
        }

        if (historyPopup.source !== "launched") {
            for (var j = 0; j < historyPopup.shellHistory.length; j++) {
                var line = historyPopup.shellHistory[j]
                if (q !== "" && line.toLowerCase().indexOf(q) === -1)
                    continue
                out.push({
                    text: line,
                    label: line,
                    origin: "terminal",
                    fromShell: true
                })
            }
        }

        return out.slice(0, 60)
    }

    Process {
        id: historyProc
        command: root.newUtill(["--getcommandhistory"])
        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text.trim()
                historyPopup.shellHistory = text === "" ? [] : text.split("\n")
            }
        }
    }

    function refresh() {
        if (!historyProc.running) historyProc.running = true
    }

    onOpen: {
        historyPopup.query = ""
        searchField.text = ""
        historyPopup.refresh()
        searchField.focusInput()
    }

    function run(entry, inTerminal) {
        historyPopup.forceClose()

        if (inTerminal) {
            root.runInTerminal(entry.text, entry.text)
            return
        }

        // The owner runs it and reports, so the confirmation still appears
        historyPopup.commandSelected(entry.text)
    }

    content: ColumnLayout {
        id: body
        spacing: 8

        Keys.onEscapePressed: historyPopup.forceClose()

        RowLayout {
            id: headerRow
            Layout.fillWidth: true
            spacing: Theme.gap

            Icon {
                iconName: "history"
                iconSize: 19
                color: Theme.accentIcon
            }

            InputField {
                id: searchField
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                placeholder: "Search history"
                onTextChanged: historyPopup.query = text
            }

            SegmentedControl {
                width: 230
                options: [
                    { label: "All", value: "all" },
                    { label: "Launched", value: "launched" },
                    { label: "Terminal", value: "shell" }
                ]
                value: historyPopup.source
                onPicked: (v) => historyPopup.source = v
            }

            ActionButton {
                label: "Close"
                onActivated: historyPopup.forceClose()
            }
        }

        Text {
            Layout.fillWidth: true
            visible: historyPopup.entries.length === 0
            text: "Nothing here yet."
            color: Theme.textMute
            font.family: Theme.fontFamily
            font.pixelSize: Theme.descSize
        }

        ScrollView {
            id: historyScroll
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(listColumn.implicitHeight,
                historyPopup.maxHeight - headerRow.height - 40)
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                id: listColumn
                width: historyScroll.availableWidth
                spacing: 4

        Repeater {
            model: historyPopup.entries

            delegate: Rectangle {
                id: entryRow
                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: Theme.radiusSmall
                color: entryArea.containsMouse ? Theme.alpha(Theme.accent, 0.18)
                                               : Theme.alpha(Theme.scrimBase, 0.30)
                border.width: Theme.borderWidth
                border.color: Theme.alpha(Theme.textBase, 0.08)

                Icon {
                    id: entryIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: entryRow.modelData.fromShell ? "terminal" : "open_app"
                    iconSize: 15
                    color: Theme.textMute
                }

                Column {
                    anchors.left: entryIcon.right
                    anchors.leftMargin: 10
                    anchors.right: entryActions.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                        width: parent.width
                        text: entryRow.modelData.label
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.valueSize
                        font.weight: 600
                    }

                    Text {
                        width: parent.width
                        text: entryRow.modelData.origin
                        elide: Text.ElideRight
                        color: Theme.textMute
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.descSize
                    }
                }

                Row {
                    id: entryActions
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    ActionButton {
                        label: "Run"
                        tone: "accent"
                        onActivated: historyPopup.run(entryRow.modelData, false)
                    }

                    ActionButton {
                        label: "Terminal"
                        onActivated: historyPopup.run(entryRow.modelData, true)
                    }
                }

                MouseArea {
                    id: entryArea
                    anchors.fill: parent
                    z: -1
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: historyPopup.run(entryRow.modelData, false)
                }
            }
        }
            }
        }
    }
}
