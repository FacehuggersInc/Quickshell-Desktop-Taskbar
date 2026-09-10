import Quickshell
import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Theme
import qs.Objects.Systems

Item {
    id: workspaceSwitcher
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // ## Monitor summary
    // One cell per monitor at that monitor's aspect ratio, holding a miniature
    // of its window layout and the window count. Screen capture is deliberately
    // not used here — three live output feeds behind a 20px cell is a lot of
    // GPU for something this small, and a capture of the output would contain
    // the bar itself.

    property int cellHeight: 20

    RowLayout {
        id: row
        spacing: 6

        Repeater {
            model: HyprlandSystem.monitors

            delegate: Rectangle {
                id: cell
                required property var modelData

                readonly property var windows:
                    HyprlandSystem.windowsOnWorkspace(modelData.activeWorkspaceId)
                readonly property real aspect:
                    modelData.h > 0 ? (modelData.w / modelData.h) : 1.6
                readonly property real scaleFactor:
                    modelData.w > 0 ? (width / modelData.w) : 1

                implicitHeight: workspaceSwitcher.cellHeight
                implicitWidth: Math.max(24, Math.round(workspaceSwitcher.cellHeight * aspect))

                radius: 4
                // Recessed rather than raised — a light fill over a dark bar is
                // how these ended up reading as grey blocks
                color: modelData.focused ? Theme.alpha(Theme.accent, 0.18)
                                         : Theme.alpha(Theme.scrimBase, 0.40)
                border.width: 1
                border.color: modelData.focused ? Theme.accentLine
                                                : Theme.alpha(Theme.textBase, 0.10)
                clip: true

                Behavior on color { ColorAnimation { duration: Theme.durFast } }

                Repeater {
                    model: cell.windows

                    delegate: Rectangle {
                        required property var modelData

                        x: Math.round((modelData.x - cell.modelData.x) * cell.scaleFactor)
                        y: Math.round((modelData.y - cell.modelData.y) * cell.scaleFactor)
                        width: Math.max(2, Math.round(modelData.w * cell.scaleFactor))
                        height: Math.max(2, Math.round(modelData.h * cell.scaleFactor))

                        radius: 1
                        color: modelData.activated
                            ? Theme.alpha(Theme.accent, 0.85)
                            : Theme.alpha(Theme.textBase, 0.16)

                        Behavior on x { NumberAnimation { duration: Theme.durNormal } }
                        Behavior on y { NumberAnimation { duration: Theme.durNormal } }
                        Behavior on width { NumberAnimation { duration: Theme.durNormal } }
                        Behavior on height { NumberAnimation { duration: Theme.durNormal } }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: cell.windows.length
                    color: cell.modelData.focused ? Theme.accentText : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: 700
                    style: Text.Outline
                    styleColor: Theme.alpha(Theme.scrimBase, 0.85)
                }

                Tooltip {
                    id: cellTooltip
                    text: cell.modelData.name + "  ·  workspace " + cell.modelData.activeWorkspaceId
                        + "  ·  " + cell.windows.length + " windows"
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) cellTooltip.showAt(point)
                        else cellTooltip.hide()
                    }
                }
            }
        }

        // Bucket indicator — only present when something is stashed
        Rectangle {
            readonly property int stashed: {
                var total = 0
                var special = HyprlandSystem.specialWorkspaces()
                for (var i = 0; i < special.length; i++) {
                    total += HyprlandSystem.windowsOnSpecial(
                        special[i].name.replace("special:", "")).length
                }
                return total
            }

            visible: stashed > 0
            implicitHeight: workspaceSwitcher.cellHeight
            implicitWidth: 18
            radius: 4
            color: Theme.alpha(Theme.scrimBase, 0.40)
            border.width: 1
            border.color: Theme.alpha(Theme.textBase, 0.10)

            Text {
                anchors.centerIn: parent
                text: parent.stashed
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: 700
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.overview.toggle()
    }
}
