import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io

import qs.Objects.Design
import qs.Objects.Widgets

// Searchable list of installed apps from .desktop files
Item {
    id: existingView

    signal appSelected(string name, string exec, string icon, string className)

    property var allApps: []
    property var filteredApps: []
    property bool loading: true

    Process {
        id: desktopAppsProc
        command: root.newUtill(["--getdesktopapps"])
        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text.trim()
                if (text === "none" || text === "") {
                    existingView.loading = false
                    return
                }
                var apps = []
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|")
                    if (parts.length < 4) continue
                    apps.push({
                        name:      parts[0],
                        exec:      parts[1],
                        icon:      parts[2],
                        className: parts[3],
                        comment:   parts.length > 4 ? parts[4] : ""
                    })
                }
                // Filter out already pinned apps
                var pinned = root.settings.launchers.map(function(l) { return l.name })
                apps = apps.filter(function(a) {
                    return !pinned.includes(a.className)
                })
                existingView.allApps      = apps
                existingView.filteredApps = apps
                existingView.loading      = false
            }
        }
    }

    // Re-fetch the full app list every time this view becomes visible
    // so that recently pinned/unpinned apps are correctly shown/hidden.
    onVisibleChanged: {
        if (visible) {
            loading = true
            allApps = []
            filteredApps = []
            desktopAppsProc.running = true
        }
    }

    function filterApps(query) {
        if (query.trim() === "") {
            filteredApps = allApps
            return
        }
        var q = query.toLowerCase()
        filteredApps = allApps.filter(function(a) {
            return a.name.toLowerCase().includes(q)
                || a.className.toLowerCase().includes(q)
                || a.comment.toLowerCase().includes(q)
        })
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // Search bar
        Rectangle {
            Layout.fillWidth: true
            height: 38
            radius: 8
            color: root.settings.theme.surface

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Image {
                    source: root.iconSource("search")
                    width: 18; height: 18
                    fillMode: Image.PreserveAspectFit
                    opacity: 0.5
                }

                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: "Search applications..."
                    color: root.settings.theme.text
                    font.family: root.settings.fontFamily
                    font.pixelSize: 14
                    background: Item {}
                    onTextChanged: existingView.filterApps(text)
                }
            }
        }

        // Loading indicator
        Text {
            visible: existingView.loading
            text: "Loading applications..."
            color: root.settings.theme.text
            opacity: 0.5
            font.family: root.settings.fontFamily
            font.pixelSize: 14
            Layout.alignment: Qt.AlignHCenter
        }

        // App list
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            visible: !existingView.loading
            clip: true
            contentHeight: appColumn.implicitHeight

            ColumnLayout {
                id: appColumn
                width: existingView.width
                spacing: 2

                Repeater {
                    model: existingView.filteredApps
                    delegate: ItemDelegate {
                        required property var modelData
                        Layout.fillWidth: true
                        height: 52
                        padding: 0

                        background: Rectangle {
                            radius: 6
                            color: hov.hovered
                                ? root.settings.theme.primary
                                : "transparent"
                            opacity: hov.hovered ? 0.15 : 1
                        }

                        HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }

                        contentItem: RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10

                            // App icon — try system icon then fallback
                            Image {
                                source: modelData.icon !== ""
                                    ? "image://icon/" + modelData.icon
                                    : root.iconSource("open_app")
                                width: 28
                                height: 28
                                sourceSize.width: 28
                                sourceSize.height: 28
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: modelData.name
                                    color: root.settings.theme.text
                                    font.family: root.settings.fontFamily
                                    font.weight: 600
                                    font.pixelSize: 14
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: modelData.comment !== ""
                                        ? modelData.comment
                                        : modelData.exec
                                    color: root.settings.theme.text
                                    opacity: 0.45
                                    font.family: root.settings.fontFamily
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            // Add button
                            RoundButton {
                                text: "Add"
                                font.family: root.settings.fontFamily
                                font.pixelSize: 13
                                padding: 4
                                horizontalPadding: 14
                                contentItem: Text {
                                    text: parent.text
                                    font: parent.font
                                    color: root.settings.theme.text
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                background: Rectangle {
                                    radius: 6
                                    color: root.settings.theme.primary
                                    opacity: 0.7
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                onClicked: {
                                    existingView.appSelected(
                                        modelData.name,
                                        modelData.exec,
                                        modelData.icon,
                                        modelData.className
                                    )
                                }
                            }
                        }

                        onClicked: {
                            existingView.appSelected(
                                modelData.name,
                                modelData.exec,
                                modelData.icon,
                                modelData.className
                            )
                        }
                    }
                }
            }
        }
    }
}