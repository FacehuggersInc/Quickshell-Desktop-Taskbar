import QtQuick
import Quickshell
import QtQuick.Controls
import Quickshell.Widgets
import QtQuick.Controls.Material

RoundButton {
    id: button
    required property string iconName
    required property real iconSize
    property string color: "#ffffff";
    property string backgroundColor: "transparent"
    property string borderColor: 'transparent'
    property int borderWidth: 0
    property string tooltipText: ""
    signal hoveredEvent(point: var)

    Material.foreground: color
    background: Rectangle {
        radius: button.radius
        color: backgroundColor
        border.color: borderColor
        border.width: borderWidth
    }

    Tooltip {
        id: tooltip
        text: button.tooltipText
    }

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: {
            if (hovered) {
                tooltip.showAt(hoverHandler.point)
            } else {
                tooltip.hide()
            }
            button.hoveredEvent(hoverHandler.point)
        }
    }

    padding: 0
    spacing: 2

    implicitHeight: iconSize
    width: iconSize
    
    font.family: root.settings.fontFamily

    // ## Content
    // Goes through Icon rather than the button's own icon.source, so the font
    // path and the bundled fallback are decided in one place. An explicit
    // source still wins, which is what the app bar uses for desktop icons.

    property string iconSourceOverride: ""

    // A bare Row fills the button and left aligns its children, so the icon has
    // to sit in a centred Row inside a wrapper
    contentItem: Item {
        implicitWidth: inner.implicitWidth
        implicitHeight: inner.implicitHeight

        Row {
        id: inner
        anchors.centerIn: parent
        spacing: button.text !== "" ? 5 : 0

        readonly property real glyph: Math.min(button.iconSize,
            Math.max(8, Math.min(button.width, button.height)))

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: button.iconSourceOverride === ""
            iconName: button.iconName
            iconSize: inner.glyph
            color: button.color
        }

        Image {
            anchors.verticalCenter: parent.verticalCenter
            visible: button.iconSourceOverride !== ""
            width: inner.glyph
            height: inner.glyph
            source: button.iconSourceOverride
            fillMode: Image.PreserveAspectFit
            sourceSize.width: Math.round(button.iconSize * 2)
            sourceSize.height: Math.round(button.iconSize * 2)
            smooth: true
            cache: false
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: button.text !== ""
            text: button.text
            color: button.color
            font.family: button.font.family
            font.pixelSize: Math.max(10, inner.glyph * 0.62)
            font.weight: 600
        }
        }
    }

    function setIcon(name){
        button.iconName = name
        button.iconSourceOverride = ""
        return name
    }

    function setIconSource(source){
        button.iconSourceOverride = source
    }

    function setColor(color){
        button.color = color
        Material.foreground = color
    }
}