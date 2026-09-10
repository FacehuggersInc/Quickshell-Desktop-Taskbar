import QtQuick
import QtQuick.Effects

Item {
    id: icon

    required property string iconName
    property real iconSize: 18
    property color color: "#ffffff"

    // Tint has to be done here. Material.foreground only colours icons on
    // Material controls, so it silently did nothing on a bare image.
    property bool tinted: true

    implicitWidth: iconSize
    implicitHeight: iconSize
    width: iconSize
    height: iconSize

    Image {
        id: source
        anchors.fill: parent
        source: icon.iconName ? root.iconSource(icon.iconName) : ""
        sourceSize.width: Math.round(icon.iconSize * 2)
        sourceSize.height: Math.round(icon.iconSize * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
        cache: true
        visible: !icon.tinted
    }

    MultiEffect {
        anchors.fill: parent
        source: source
        visible: icon.tinted && source.status === Image.Ready
        colorization: 1.0
        colorizationColor: icon.color
    }

    function setIcon(name) {
        icon.iconName = name
        return root.iconSource(name)
    }

    function setColor(value) {
        icon.color = value
    }
}
