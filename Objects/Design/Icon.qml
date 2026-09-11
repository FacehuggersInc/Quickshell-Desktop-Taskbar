import QtQuick
import QtQuick.Effects

Item {
    id: icon

    required property string iconName
    property real iconSize: 18
    property color color: "#ffffff"
    property bool tinted: true

    implicitWidth: iconSize
    implicitHeight: iconSize
    width: iconSize
    height: iconSize

    // ## Font
    // Material Symbols draws the icon from a ligature of its own name, so
    // there is nothing to resolve on disk and nothing to cache.

    Text {
        anchors.centerIn: parent
        visible: IconMap.useFont
        text: IconMap.glyph(icon.iconName)
        color: icon.color
        font.family: IconMap.family
        font.pixelSize: icon.iconSize
        font.hintingPreference: Font.PreferNoHinting
        renderType: Text.NativeRendering
    }

    // ## Fallback
    // The bundled folder, for machines without the font installed

    Image {
        id: bitmap
        anchors.fill: parent
        visible: !IconMap.useFont && !icon.tinted
        source: (!IconMap.useFont && icon.iconName) ? root.iconSource(icon.iconName) : ""
        sourceSize.width: Math.round(icon.iconSize * 2)
        sourceSize.height: Math.round(icon.iconSize * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
        cache: true
    }

    MultiEffect {
        anchors.fill: parent
        source: bitmap
        visible: !IconMap.useFont && icon.tinted && bitmap.status === Image.Ready
        colorization: 1.0
        colorizationColor: icon.color
    }

    function setIcon(name) {
        icon.iconName = name
        return name
    }

    function setColor(value) {
        icon.color = value
    }
}
