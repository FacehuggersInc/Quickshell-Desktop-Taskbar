import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme

FloatingWindow {
    id: settingsWindow

    title: "Shell Settings"
    implicitWidth: 880
    implicitHeight: 620
    minimumSize.width: 620
    minimumSize.height: 420
    visible: false
    color: Theme.bg

    property string pageId: "appearance"
    property string query: ""

    readonly property var results: SettingsSchema.search(query)
    readonly property bool searching: query.trim() !== ""

    readonly property var page: {
        var list = SettingsSchema.pages
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === settingsWindow.pageId)
                return list[i]
        }
        return list[0]
    }

    function open() {
        settingsWindow.visible = true
    }

    function close() {
        settingsWindow.visible = false
    }

    function toggle() {
        settingsWindow.visible = !settingsWindow.visible
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ## Sidebar

        Rectangle {
            Layout.preferredWidth: 210
            Layout.fillHeight: true
            color: Theme.alpha(Theme.textBase, 0.04)

            Rectangle {
                anchors.right: parent.right
                width: Theme.borderWidth
                height: parent.height
                color: Theme.border
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                InputField {
                    Layout.fillWidth: true
                    placeholder: "Search settings"
                    onCommitted: (v) => settingsWindow.query = v
                }

                Repeater {
                    model: SettingsSchema.pages

                    delegate: Rectangle {
                        required property var modelData

                        readonly property bool current:
                            modelData.id === settingsWindow.pageId && !settingsWindow.searching

                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: Theme.radiusSmall
                        color: current ? Theme.alpha(Theme.accent, 0.24)
                            : (tabArea.containsMouse ? Theme.alpha(Theme.textBase, 0.09)
                                                     : "transparent")

                        Behavior on color { ColorAnimation { duration: Theme.durFast } }

                        Icon {
                            id: tabIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: modelData.icon
                            iconSize: 16
                            color: parent.current ? Theme.accentText : Theme.textDim
                        }

                        Text {
                            anchors.left: tabIcon.right
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.title
                            color: parent.current ? Theme.accentText : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.labelSize
                            font.weight: parent.current ? 700 : 500
                        }

                        MouseArea {
                            id: tabArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                settingsWindow.query = ""
                                settingsWindow.pageId = modelData.id
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Text {
                    Layout.fillWidth: true
                    text: "Values write straight to config.json"
                    wrapMode: Text.WordWrap
                    color: Theme.textMute
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.descSize
                }
            }
        }

        // ## Content

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                id: body
                width: settingsWindow.width - 210 - Theme.pagePadding * 2
                x: Theme.pagePadding
                y: Theme.pagePadding
                spacing: Theme.gap

                Text {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                    text: settingsWindow.searching
                        ? settingsWindow.results.length + " results"
                        : settingsWindow.page.title
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.weight: 700
                }

                // Search results across every page

                Repeater {
                    model: settingsWindow.searching ? settingsWindow.results : []

                    delegate: ColumnLayout {
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: modelData.pageTitle + "  ·  " + modelData.groupTitle
                            color: Theme.textMute
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.descSize
                        }

                        SettingControl {
                            Layout.fillWidth: true
                            item: modelData.item
                        }
                    }
                }

                // Pages backed by live data rather than schema items

                Loader {
                    Layout.fillWidth: true
                    active: !settingsWindow.searching
                        && settingsWindow.page.custom !== undefined
                    sourceComponent: {
                        if (settingsWindow.page.custom === "audio") return audioPage
                        if (settingsWindow.page.custom === "bluetooth") return bluetoothPage
                        return null
                    }
                }

                // The selected page

                Repeater {
                    model: settingsWindow.searching ? [] : settingsWindow.page.groups

                    delegate: ColumnLayout {
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.topMargin: Theme.sectionGap
                        spacing: 0

                        SectionLabel {
                            Layout.fillWidth: true
                            text: modelData.title
                        }

                        Repeater {
                            model: modelData.items

                            delegate: SettingControl {
                                required property var modelData

                                Layout.fillWidth: true
                                item: modelData
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: Theme.pagePadding }
            }
        }
    }

    Component {
        id: audioPage
        AudioSettingsPage {}
    }

    Component {
        id: bluetoothPage
        BluetoothSettingsPage {}
    }
}
