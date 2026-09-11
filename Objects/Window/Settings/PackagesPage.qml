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
    property string source: ""
    property bool updatesOnly: false
    readonly property int limit: 100

    readonly property var matches: {
        var q = page.query.trim().toLowerCase()
        var out = []

        for (var i = 0; i < PackageSystem.packages.length; i++) {
            var pkg = PackageSystem.packages[i]

            if (page.source !== "" && pkg.source !== page.source)
                continue
            if (page.updatesOnly && !PackageSystem.updateFor(pkg.name))
                continue
            if (q !== "" && pkg.name.toLowerCase().indexOf(q) === -1
                    && pkg.description.toLowerCase().indexOf(q) === -1)
                continue

            out.push(pkg)
        }
        return out
    }

    SectionLabel {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        text: "Installed Packages"
    }

    SettingRow {
        Layout.fillWidth: true
        Layout.preferredHeight: 70
        label: "Filter"
        description: PackageSystem.scanned
            ? PackageSystem.packages.length + " explicitly installed · "
              + PackageSystem.updateCount + " updates available"
            : "Reading package database…"
        stacked: true

        RowLayout {
            width: parent.width
            spacing: Theme.gap

            InputField {
                Layout.fillWidth: true
                placeholder: "Search by name or description"
                onTextChanged: page.query = text
            }

            SelectBox {
                width: 150
                options: [
                    { label: "All sources", value: "" },
                    { label: "Repository", value: "repo" },
                    { label: "AUR", value: "aur" },
                    { label: "Flatpak", value: "flatpak" }
                ]
                value: page.source
                onPicked: (v) => page.source = v
            }
        }
    }

    SettingRow {
        Layout.fillWidth: true
        label: "Updates Only"
        description: PackageSystem.helper !== "none"
            ? "AUR checks use " + PackageSystem.helper
            : "No AUR helper found — repository and flatpak only"

        Row {
            spacing: 6

            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: page.updatesOnly
                onToggled: (v) => page.updatesOnly = v
            }

            ActionButton {
                label: "Check"
                busy: PackageSystem.busy
                onActivated: PackageSystem.checkUpdates()
            }

            ActionButton {
                label: "Update All"
                tone: "accent"
                enabled: PackageSystem.updateCount > 0
                onActivated: PackageSystem.updateAll()
            }
        }
    }

    // ## Pending updates
    // Their own list rather than badges scattered through hundreds of rows

    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        Layout.preferredHeight: 54
        visible: PackageSystem.updateCount > 0
        radius: Theme.radiusSmall
        color: Theme.alpha(Theme.warn, 0.16)
        border.width: Theme.borderWidth
        border.color: Theme.warn

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: PackageSystem.updateCount + " updates available"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.labelSize
            font.weight: 700
        }

        ActionButton {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            label: "Update Everything"
            tone: "accent"
            onActivated: PackageSystem.updateAll()
        }
    }

    Repeater {
        model: PackageSystem.updates

        delegate: Rectangle {
            required property var modelData

            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.preferredHeight: 50
            radius: Theme.radiusSmall
            color: Theme.alpha(Theme.scrimBase, 0.35)
            border.width: Theme.borderWidth
            border.color: Theme.alpha(Theme.warn, 0.5)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: Theme.gap

                Rectangle {
                    Layout.preferredWidth: 66
                    Layout.preferredHeight: 22
                    radius: 4
                    color: {
                        if (modelData.source === "aur") return Theme.alpha(Theme.warn, 0.22)
                        if (modelData.source === "flatpak") return Theme.alpha(Theme.ok, 0.22)
                        return Theme.alpha(Theme.accent, 0.22)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.source.toUpperCase()
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: 700
                        font.letterSpacing: 0.6
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: modelData.name
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.labelSize
                        font.weight: 600
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.current !== ""
                            ? modelData.current + "  →  " + modelData.next
                            : "new version " + modelData.next
                        color: Theme.warn
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.descSize
                    }
                }

                ActionButton {
                    label: "Update"
                    tone: "accent"
                    onActivated: PackageSystem.updateOne(modelData)
                }
            }
        }
    }

    SectionLabel {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        text: "All Installed"
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 10
        text: {
            if (!PackageSystem.scanned)
                return "Reading…"
            if (page.matches.length === 0)
                return "Nothing matches that filter."
            if (page.matches.length > page.limit)
                return "Showing " + page.limit + " of " + page.matches.length
                    + ". Narrow the search to see the rest."
            return page.matches.length + " packages"
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

            readonly property var pending: PackageSystem.updateFor(modelData.name)
            readonly property bool expanded: page.expandedName === modelData.name

            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.preferredHeight: expanded ? 118 : 60
            radius: Theme.radiusSmall
            color: Theme.alpha(Theme.scrimBase, 0.35)
            border.width: Theme.borderWidth
            border.color: row.pending ? Theme.warn : Theme.alpha(Theme.textBase, 0.08)

            Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.durFast } }

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                height: 44
                spacing: Theme.gap

                Rectangle {
                    Layout.preferredWidth: 66
                    Layout.preferredHeight: 22
                    radius: 4
                    color: {
                        if (row.modelData.source === "aur") return Theme.alpha(Theme.warn, 0.22)
                        if (row.modelData.source === "flatpak") return Theme.alpha(Theme.ok, 0.22)
                        return Theme.alpha(Theme.accent, 0.22)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: row.modelData.source.toUpperCase()
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: 700
                        font.letterSpacing: 0.6
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: row.modelData.name
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.labelSize
                            font.weight: 600
                        }

                        Text {
                            text: row.modelData.version
                            color: Theme.textMute
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.descSize
                        }

                        Text {
                            visible: row.pending !== null
                            text: row.pending ? "→ " + row.pending.next : ""
                            color: Theme.warn
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.descSize
                            font.weight: 700
                        }

                        Item { Layout.fillWidth: true }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.description
                        elide: Text.ElideRight
                        color: Theme.textMute
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.descSize
                    }
                }

                ActionButton {
                    label: row.expanded ? "Less" : "Details"
                    onActivated: page.expandedName = row.expanded ? "" : row.modelData.name
                }

                ActionButton {
                    label: "Update"
                    tone: "accent"
                    enabled: row.pending !== null
                    onActivated: PackageSystem.updateOne(row.modelData)
                }

                ActionButton {
                    label: "Remove"
                    tone: "danger"
                    onActivated: PackageSystem.removeOne(row.modelData)
                }
            }

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 8
                spacing: 1
                visible: row.expanded

                Text {
                    Layout.fillWidth: true
                    text: row.modelData.installed !== ""
                        ? "Installed " + row.modelData.installed
                        : "Install date not recorded"
                    color: Theme.textMute
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.descSize
                }

                Text {
                    Layout.fillWidth: true
                    text: row.modelData.size !== "" ? "Size " + row.modelData.size : ""
                    visible: row.modelData.size !== ""
                    color: Theme.textMute
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.descSize
                }

                Text {
                    Layout.fillWidth: true
                    text: row.modelData.depends !== ""
                        ? "Depends on " + row.modelData.depends
                        : "No dependencies"
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: Theme.textMute
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.descSize
                }
            }
        }
    }

    property string expandedName: ""

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 10
        text: "Only packages you installed on purpose are listed — dependencies pulled in by them are not. Updates and removals open a terminal with the command ready, rather than running as root from the shell."
        wrapMode: Text.WordWrap
        color: Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: Theme.descSize
    }
}
