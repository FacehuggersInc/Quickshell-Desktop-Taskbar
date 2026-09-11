import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme

// Installed applications, read live from DesktopEntries
Item {
    id: existingView

    signal appSelected(string name, string exec, string icon, string className)

    property string query: ""

    // ## Source
    // DesktopEntries tracks .desktop files as they appear and disappear, so
    // installing or removing an application updates this without a rescan. The
    // old path shelled out to python and only refreshed when the window opened.

    readonly property var pinned: {
        var out = []
        var list = root.settings.launchers || []
        for (var i = 0; i < list.length; i++)
            out.push(list[i].name)
        return out
    }

    readonly property var allApps: {
        var out = []
        var entries = DesktopEntries.applications
            ? DesktopEntries.applications.values : []

        for (var i = 0; i < entries.length; i++) {
            var e = entries[i]
            if (e.noDisplay)
                continue

            var className = e.startupClass && e.startupClass !== ""
                ? e.startupClass : e.id

            out.push({
                name: e.name || e.id,
                exec: e.execString || "",
                icon: e.icon || "",
                className: className,
                comment: e.comment || e.genericName || "",
                isPinned: existingView.pinned.indexOf(className) !== -1
            })
        }

        out.sort(function(a, b) { return a.name.localeCompare(b.name) })
        return out
    }

    readonly property var filteredApps: {
        var q = existingView.query.trim().toLowerCase()
        if (!q)
            return existingView.allApps

        var out = []
        for (var i = 0; i < existingView.allApps.length; i++) {
            var a = existingView.allApps[i]
            if (a.name.toLowerCase().indexOf(q) !== -1
                    || a.className.toLowerCase().indexOf(q) !== -1
                    || a.comment.toLowerCase().indexOf(q) !== -1) {
                out.push(a)
            }
        }
        return out
    }

    function refresh() {
        existingView.query = ""
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.gap

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap

            InputField {
                id: search
                Layout.fillWidth: true
                placeholder: "Search installed applications"
                onTextChanged: existingView.query = text
            }

            Text {
                text: existingView.filteredApps.length + " apps"
                color: Theme.textMute
                font.family: Theme.fontFamily
                font.pixelSize: Theme.descSize
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 3
            model: existingView.filteredApps

            delegate: Rectangle {
                required property var modelData

                width: ListView.view.width
                height: 52
                radius: Theme.radiusSmall
                color: rowArea.containsMouse ? Theme.alpha(Theme.accent, 0.18)
                                             : Theme.alpha(Theme.scrimBase, 0.35)
                border.width: Theme.borderWidth
                border.color: Theme.alpha(Theme.textBase, 0.08)
                opacity: modelData.isPinned ? 0.45 : 1.0

                Behavior on color { ColorAnimation { duration: Theme.durFast } }

                // Fixed box, aspect preserved — icons come in every size and
                // the old list let each one set its own
                Rectangle {
                    id: iconBox
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    radius: Theme.radiusSmall
                    color: Theme.alpha(Theme.textBase, 0.06)

                    Image {
                        anchors.fill: parent
                        anchors.margins: 5
                        source: modelData.icon !== "" ? Quickshell.iconPath(modelData.icon, true) : ""
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: 64
                        sourceSize.height: 64
                        smooth: true
                        asynchronous: true
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: modelData.icon === ""
                        text: modelData.name.charAt(0).toUpperCase()
                        color: Theme.textMute
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        font.weight: 700
                    }
                }

                Column {
                    anchors.left: iconBox.right
                    anchors.leftMargin: 10
                    anchors.right: pinnedTag.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: modelData.name
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.labelSize
                        font.weight: 600
                    }

                    Text {
                        width: parent.width
                        text: modelData.comment !== "" ? modelData.comment : modelData.className
                        elide: Text.ElideRight
                        color: Theme.textMute
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.descSize
                    }
                }

                Text {
                    id: pinnedTag
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: modelData.isPinned
                    text: "PINNED"
                    color: Theme.accentText
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: 700
                    font.letterSpacing: 1.2
                }

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !modelData.isPinned
                    cursorShape: Qt.PointingHandCursor
                    onClicked: existingView.appSelected(
                        modelData.name, modelData.exec,
                        modelData.icon, modelData.className)
                }
            }
        }
    }
}
