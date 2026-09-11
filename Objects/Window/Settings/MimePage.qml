import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Window
import qs.Objects.Design.Controls
import qs.Objects.Theme
import qs.Objects.Systems

ColumnLayout {
    id: page
    spacing: 0

    property string query: ""
    property string category: ""
    property string state: "all"

    // The type being reassigned through the chooser
    property string pendingMime: ""

    readonly property string chooseValue: "__choose__"

    readonly property int limit: 120

    readonly property var matches: {
        var q = page.query.trim().toLowerCase()
        var out = []

        for (var i = 0; i < MimeSystem.entries.length; i++) {
            var entry = MimeSystem.entries[i]

            if (page.category !== "" && entry.mime.split("/")[0] !== page.category)
                continue

            if (page.state === "assigned" && entry.current === "")
                continue
            if (page.state === "unhandled" && entry.candidates.length > 0)
                continue
            if (page.state === "available"
                    && (entry.candidates.length === 0 || entry.current !== ""))
                continue

            if (q !== "") {
                var name = MimeSystem.appName(entry.current).toLowerCase()
                if (entry.mime.toLowerCase().indexOf(q) === -1
                        && name.indexOf(q) === -1)
                    continue
            }

            out.push(entry)
        }
        return out
    }

    SectionLabel {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        text: "File Associations"
    }

    SettingRow {
        Layout.fillWidth: true
        Layout.preferredHeight: 70
        label: "Filter"
        description: MimeSystem.entries.length + " types known to your system"
        stacked: true

        RowLayout {
            width: parent.width
            spacing: Theme.gap

            InputField {
                Layout.fillWidth: true
                placeholder: "Search a type or an application"
                onTextChanged: page.query = text
            }

            SelectBox {
                width: 180
                options: MimeSystem.categories
                value: page.category
                placeholder: "All categories"
                onPicked: (v) => page.category = v
            }
        }
    }

    SettingRow {
        Layout.fillWidth: true
        label: "Show"
        description: "Nothing is hidden — this only narrows what is listed"

        SegmentedControl {
            options: [
                { label: "All", value: "all" },
                { label: "Assigned", value: "assigned" },
                { label: "Unclaimed", value: "available" },
                { label: "No app", value: "unhandled" }
            ]
            value: page.state
            onPicked: (v) => page.state = v
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 10
        text: {
            if (!MimeSystem.scanned)
                return "Reading the mime database…"
            if (page.matches.length === 0)
                return "Nothing matches that filter."
            if (page.matches.length > page.limit)
                return "Showing " + page.limit + " of " + page.matches.length
                    + " matches. Narrow the search to see the rest."
            return page.matches.length + " matches"
        }
        color: Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: Theme.descSize
    }

    Repeater {
        model: page.matches.slice(0, page.limit)

        delegate: Rectangle {
            id: row
            required property var modelData

            readonly property bool assigned: modelData.current !== ""
            readonly property bool orphan: modelData.candidates.length === 0
            readonly property bool claimed:
                modelData.added !== undefined && modelData.added.length > 0

            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.preferredHeight: 62
            radius: Theme.radiusSmall
            color: Theme.alpha(Theme.scrimBase, 0.35)
            border.width: Theme.borderWidth
            border.color: row.assigned ? Theme.accentLine
                                       : Theme.alpha(Theme.textBase, 0.08)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: Theme.gap

                // ## Category
                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: Theme.radiusSmall
                    color: row.orphan ? Theme.alpha(Theme.textBase, 0.06)
                                      : Theme.alpha(Theme.accent, 0.14)

                    Icon {
                        anchors.centerIn: parent
                        iconName: MimeSystem.categoryIcon(row.modelData.mime)
                        iconSize: 20
                        color: row.orphan ? Theme.textMute : Theme.accentIcon
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: row.modelData.mime
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.labelSize
                            font.weight: 600
                        }

                        Repeater {
                            model: row.modelData.extensions !== ""
                                ? row.modelData.extensions.split(" ") : []

                            delegate: Rectangle {
                                required property var modelData

                                width: extText.implicitWidth + 12
                                height: 16
                                radius: 3
                                color: Theme.alpha(Theme.textBase, 0.10)

                                Text {
                                    id: extText
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: 600
                                }
                            }
                        }

                        Rectangle {
                            visible: row.claimed
                            width: claimText.implicitWidth + 12
                            height: 16
                            radius: 3
                            color: Theme.alpha(Theme.warn, 0.22)

                            Text {
                                id: claimText
                                anchors.centerIn: parent
                                text: "claimed"
                                color: Theme.warn
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: 700
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Image {
                            visible: row.assigned && source !== ""
                            source: MimeSystem.appIcon(row.modelData.current)
                            sourceSize.width: 32
                            sourceSize.height: 32
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (row.orphan)
                                    return "nothing claims this — choose another application"
                                if (!row.assigned)
                                    return row.modelData.candidates.length
                                        + " available · using the system default"
                                return MimeSystem.appName(row.modelData.current)
                            }
                            elide: Text.ElideRight
                            color: row.assigned ? Theme.accentText : Theme.textMute
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.descSize
                        }
                    }
                }

                // Declared handlers first, then an escape hatch into the full
                // application list — a dropdown of every installed app was
                // unusable and buried the handlers that actually apply.
                SelectBox {
                    width: 230
                    placeholder: "System default"
                    value: row.modelData.current
                    options: {
                        var out = []
                        for (var i = 0; i < row.modelData.candidates.length; i++) {
                            out.push({
                                label: MimeSystem.appName(row.modelData.candidates[i]),
                                value: row.modelData.candidates[i]
                            })
                        }
                        out.push({ label: "Choose another application…",
                                   value: page.chooseValue })
                        return out
                    }
                    onPicked: (v) => {
                        if (v === page.chooseValue) {
                            page.pendingMime = row.modelData.mime
                            appChooser.open("Choose an Application",
                                            "Will open " + row.modelData.mime)
                            return
                        }
                        MimeSystem.assign(row.modelData.mime, v, false)
                    }
                }

                ActionButton {
                    label: "Reset"
                    enabled: row.assigned || row.claimed
                    tone: row.claimed ? "danger" : "neutral"
                    onActivated: MimeSystem.clear(row.modelData.mime, row.claimed)
                }
            }
        }
    }

    AppChooser {
        id: appChooser
        onChosen: (desktopId) => {
            if (page.pendingMime === "")
                return
            MimeSystem.assign(page.pendingMime, desktopId, true)
            page.pendingMime = ""
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 10
        text: "Choices are written to mimeapps.list. Assigning an application that never declared a type also adds it under [Added Associations], which is what makes the default take — those rows are tagged claimed, and Reset removes both. The file is backed up before every change."
        wrapMode: Text.WordWrap
        color: Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: Theme.descSize
    }
}
