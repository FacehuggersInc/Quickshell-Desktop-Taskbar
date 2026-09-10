import QtQuick

import qs.Objects.Theme
import qs.Objects.Systems

Rectangle {
    id: tile

    required property var monitor
    required property var owner
    property real tileHeight: 200

    // Select mode turns the tile into a target rather than a live workspace —
    // window tiles stop reacting and the background reports a pick
    property bool selectMode: false
    signal selected()

    // Windows are inset from the tile edge so the monitor frame stays readable
    // as a frame rather than as a border drawn tight against the content
    property real inset: 10

    readonly property real aspect: monitor.h > 0 ? (monitor.w / monitor.h) : 1.6
    readonly property real scaleFactor: monitor.w > 0 ? (surface.width / monitor.w) : 1
    property bool pointerOver: false

    readonly property bool hovered:
        (tile.selectMode && tile.pointerOver)
        || (tile.owner ? tile.owner.dropTarget === ("mon:" + monitor.name) : false)

    implicitHeight: tileHeight + inset * 2
    implicitWidth: Math.round(tileHeight * aspect) + inset * 2

    radius: Theme.radius
    color: hovered ? Theme.alpha(Theme.accent, 0.16)
                   : Theme.alpha(Theme.scrimBase, 0.80)

    Behavior on color { ColorAnimation { duration: Theme.durFast } }
    border.width: hovered ? 2 : Theme.borderWidth
    border.color: hovered ? Theme.accent
                          : (monitor.focused ? Theme.accentLine : Theme.border)

    Behavior on border.color { ColorAnimation { duration: Theme.durFast } }

    // ## Windows
    // Positioned from real Hyprland geometry, so the tile is a scaled picture of
    // the monitor rather than an abstract arrangement.

    readonly property var windows: HyprlandSystem.windowsOnWorkspace(monitor.activeWorkspaceId)

    Item {
        id: surface
        anchors.fill: parent
        anchors.margins: tile.inset

    Repeater {
        model: tile.windows

        delegate: WindowTile {
            required property var modelData

            win: modelData
            owner: tile.owner
            interactive: !tile.selectMode

            x: Math.round((modelData.x - tile.monitor.x) * tile.scaleFactor)
            y: Math.round((modelData.y - tile.monitor.y) * tile.scaleFactor)
            width: Math.max(10, Math.round(modelData.w * tile.scaleFactor))
            height: Math.max(10, Math.round(modelData.h * tile.scaleFactor))

            Behavior on x { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }
        }
    }

    }

    Text {
        anchors.centerIn: parent
        text: "empty"
        color: Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: 12
        visible: tile.windows.length === 0
    }

    // ## Caption

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: 6
        spacing: 6

        Text {
            text: tile.monitor.name
            color: tile.monitor.focused ? Theme.accentText : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: 600
        }

        Text {
            text: "ws " + tile.monitor.activeWorkspaceId
            color: Theme.textMute
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }

    MouseArea {
        id: tileArea
        anchors.fill: parent
        z: tile.selectMode ? 5 : -1
        hoverEnabled: tile.selectMode
        cursorShape: tile.selectMode ? Qt.PointingHandCursor : Qt.ArrowCursor
        onEntered: tile.pointerOver = true
        onExited: tile.pointerOver = false
        onClicked: {
            if (tile.selectMode) tile.selected()
            else HyprlandSystem.switchWorkspace(tile.monitor.activeWorkspaceId)
        }
    }
}
