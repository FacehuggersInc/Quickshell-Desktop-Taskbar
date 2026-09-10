import QtQuick

import qs.Objects.Theme
import qs.Objects.Systems

Rectangle {
    id: bucket

    required property string name
    required property var owner

    readonly property var windows: HyprlandSystem.windowsOnSpecial(name)
    readonly property bool hovered: owner ? owner.dropTarget === ("bucket:" + name) : false

    implicitWidth: Math.max(190, chips.implicitWidth + 24)
    implicitHeight: 128

    radius: Theme.radius
    color: Theme.alpha(Theme.scrimBase, 0.80)
    border.width: hovered ? 2 : Theme.borderWidth
    border.color: hovered ? Theme.accent : Theme.borderStrong

    Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
    Behavior on implicitWidth { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }

    Text {
        id: label
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 8
        text: bucket.owner ? bucket.owner.bucketLabel(bucket.name) : bucket.name
        color: Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.weight: 600
    }

    Text {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        text: bucket.windows.length
        color: bucket.windows.length > 0 ? Theme.accentText : Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.weight: 700
    }

    Flow {
        id: chips
        anchors.top: label.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 4

        Repeater {
            model: bucket.windows

            delegate: WindowTile {
                required property var modelData

                win: modelData
                owner: bucket.owner
                width: 44
                height: 34
            }
        }
    }

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 6
        text: "drop here"
        color: Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: 10
        visible: bucket.windows.length === 0
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onEntered: bucket.owner.showBucketPreview(bucket.name, bucket)
        onExited: bucket.owner.hideBucketPreview(bucket.name)
        onDoubleClicked: bucket.owner.peekBucket(bucket.name)
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton)
                bucket.owner.removeBucket(bucket.name)
            else if (mouse.button === Qt.MiddleButton)
                bucket.owner.emptyBucket(bucket.name)
        }
    }
}
