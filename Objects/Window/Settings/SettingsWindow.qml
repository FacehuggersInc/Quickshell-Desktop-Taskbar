import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme
import qs.Objects.Systems

PanelWindow {
    id: settingsWindow

    visible: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:settings"
    WlrLayershell.keyboardFocus: settingsWindow.visible ? WlrKeyboardFocus.Exclusive
                                                        : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: 0

    screen: {
        var target = HyprlandSystem.focusedMonitor
        var list = Quickshell.screens
        for (var i = 0; i < list.length; i++) {
            if (list[i].name === target)
                return list[i]
        }
        return list.length > 0 ? list[0] : null
    }

    property Region glassBlurRegion: Region { item: card }

    // ## Blur re-commit
    // The compositor drops this surface's background effect when focus moves to
    // another window, and only restores it when the surface is recreated.
    // Clearing the region and setting it again forces a fresh commit, which is
    // a workaround rather than a fix — the cause is on the compositor side of
    // ext-background-effect-v1. blurMode "compositor" is unaffected.

    property bool blurArmed: true

    BackgroundEffect.blurRegion:
        (settingsWindow.visible && settingsWindow.blurArmed
         && Theme.glass && Theme.blurMode === "protocol")
            ? glassBlurRegion : null

    function recommitBlur() {
        if (!settingsWindow.visible || Theme.blurMode !== "protocol")
            return
        settingsWindow.blurArmed = false
        blurRearm.restart()
    }

    Timer {
        id: blurRearm
        interval: 32
        repeat: false
        onTriggered: settingsWindow.blurArmed = true
    }

    Connections {
        target: HyprlandSystem
        enabled: settingsWindow.visible
        function onChanged() { settingsWindow.recommitBlur() }
    }

    property string pageId: "appearance"
    property string query: ""

    readonly property var results: SettingsSchema.search(query)
    readonly property bool searching: query.trim() !== ""

    property bool debugPages: false

    onPageIdChanged: {
        pageScroll.toTop()

        // Only scanned when the page is actually opened
        if (settingsWindow.pageId === "network")
            NetworkSystem.refresh()

        // Reading the package database is slow, so only on demand
        if (settingsWindow.pageId === "packages" && !PackageSystem.scanned)
            PackageSystem.refresh()

        if (!debugPages)
            return
        var groups = settingsWindow.page ? settingsWindow.page.groups : null
        var items = 0
        if (groups) {
            for (var i = 0; i < groups.length; i++)
                items += groups[i].items ? groups[i].items.length : 0
        }
        // page is a binding and has not re-evaluated yet when this fires, so
        // the numbers below describe the page being left, not the one entered
        console.log("settings page " + settingsWindow.pageId
                    + " groups=" + (groups ? groups.length : "null")
                    + " items=" + items
                    + " schemaPages=" + (SettingsSchema.pages ? SettingsSchema.pages.length : "null")
                    + " configValid=" + root.configValid
                    + " settingsKeys=" + (root.settings ? Object.keys(root.settings).length : "null"))
    }

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
        keyHandler.forceActiveFocus()
        pageScroll.toTop()
    }

    function close() {
        searchField.text = ""
        settingsWindow.query = ""
        settingsWindow.visible = false
    }

    function toggle() {
        if (settingsWindow.visible) close()
        else open()
    }

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: settingsWindow.visible
        Keys.onEscapePressed: settingsWindow.close()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.overlayScrim

        MouseArea {
            anchors.fill: parent
            onClicked: settingsWindow.close()
        }
    }

    Rectangle {
        id: card

        // Swallows clicks so empty space inside the card does not reach the
        // dismiss area behind it
        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.AllButtons
            onClicked: {}
            onPressed: {}
        }
        anchors.centerIn: parent
        // Sized to the screen rather than a fixed guess — the display
        // arrangement in particular needs real room
        // The bar editor lays three zones side by side, so width matters more
        // here than anywhere else in the window
        width: Math.min(parent.width - 60, 1560)
        height: Math.min(parent.height - 60, 940)
        radius: Theme.radius
        color: Theme.panelScrim
        border.width: Theme.borderWidth
        border.color: Theme.borderStrong
        clip: true

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
                    id: searchField
                    Layout.fillWidth: true
                    placeholder: "Search settings"
                    onTextChanged: {
                        settingsWindow.query = text
                        pageScroll.toTop()
                    }
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
            id: pageScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // Pages differ enormously in height. Without this, scrolling down in
            // a tall page and switching to a short one leaves the view parked
            // past the end of the content, which looks like an empty page.
            function toTop() {
                if (pageScroll.contentItem)
                    pageScroll.contentItem.contentY = 0
            }

            ColumnLayout {
                id: body
                width: card.width - 210 - Theme.pagePadding * 2
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
                    id: customPage
                    Layout.fillWidth: true

                    // An inactive Loader does not reliably collapse inside a
                    // ColumnLayout when the item it held was itself a layout, so
                    // the height is pinned explicitly. Otherwise leaving a custom
                    // page leaves a page sized gap behind on every schema page.
                    Layout.preferredHeight: (active && item) ? item.implicitHeight : 0
                    Layout.maximumHeight: Layout.preferredHeight
                    visible: active && item

                    active: !settingsWindow.searching
                        && settingsWindow.page.custom !== undefined
                    sourceComponent: {
                        if (settingsWindow.page.custom === "audio") return audioPage
                        if (settingsWindow.page.custom === "bluetooth") return bluetoothPage
                        if (settingsWindow.page.custom === "pinned") return pinnedPage
                        if (settingsWindow.page.custom === "displays") return displaysPage
                        if (settingsWindow.page.custom === "hotkeys") return hotkeysPage
                        if (settingsWindow.page.custom === "startup") return startupPage
                        if (settingsWindow.page.custom === "bar") return barPage
                        if (settingsWindow.page.custom === "mime") return mimePage
                        if (settingsWindow.page.custom === "network") return networkPage
                        if (settingsWindow.page.custom === "packages") return packagesPage
                        if (settingsWindow.page.custom === "gaming") return gamingPage
                        if (settingsWindow.page.custom === "debug") return debugPage
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
                        Layout.preferredHeight: implicitHeight
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

    }

    Component {
        id: audioPage
        AudioSettingsPage {}
    }

    Component {
        id: bluetoothPage
        BluetoothSettingsPage {}
    }

    Component {
        id: pinnedPage
        PinnedAppsPage {}
    }

    Component {
        id: displaysPage
        DisplaysPage {}
    }

    Component {
        id: hotkeysPage
        HotkeysPage {}
    }

    Component {
        id: startupPage
        StartupPage {}
    }

    Component {
        id: barPage
        BarPage {}
    }

    Component {
        id: mimePage
        MimePage {}
    }

    Component {
        id: networkPage
        NetworkPage {}
    }

    Component {
        id: packagesPage
        PackagesPage {}
    }

    Component {
        id: gamingPage
        GamingPage {}
    }

    Component {
        id: debugPage
        DebugPage {}
    }
}
