import Quickshell
import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme
import qs.Objects.Widgets
import qs.Objects.Window

// Launch a pinned app with extra arguments. Rebuilt on the shared controls,
// showing the command being extended and offering the arguments already saved
// for this app rather than a bare text box.
PopupPanel {
    id: argPopup

    implicitWidth: 640
    implicitHeight: body.implicitHeight + tbPadding * 2
    sidePadding: 14
    tbPadding: 12
    fadingEffectMax: 1.0
    scrollingEffect: false
    requireFocusGrab: true

    property var contextTarget: null
    property var contextIcon: null
    signal launched()

    readonly property string baseCommand:
        argPopup.contextTarget ? (argPopup.contextTarget.command || "") : ""

    readonly property var savedArgs: {
        if (!argPopup.contextTarget || !argPopup.contextTarget.options)
            return []
        var out = []
        var list = argPopup.contextTarget.options
        for (var i = 0; i < list.length; i++) {
            var value = list[i]
            if (typeof value === "string" && value.trim() !== "")
                out.push(value)
        }
        return out
    }

    function launchWith(args) {
        if (!argPopup.contextTarget)
            return
        var extra = String(args).trim()
        root.execute(extra === ""
            ? argPopup.baseCommand.split(" ")
            : root.combine(argPopup.baseCommand.split(" "), extra.split(" ")))

        argPopup.forceClose()
        inputField.text = ""
        argPopup.launched()
    }

    onOpen: {
        inputField.text = ""
        inputField.focusInput()
    }

    content: ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        Keys.onEscapePressed: argPopup.forceClose()

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: Theme.radiusSmall
                color: Theme.alpha(Theme.textBase, 0.08)

                Image {
                    anchors.fill: parent
                    anchors.margins: 5
                    source: argPopup.contextIcon ? argPopup.contextIcon : ""
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 64
                    sourceSize.height: 64
                    smooth: true
                    asynchronous: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: argPopup.contextTarget ? argPopup.contextTarget.name : ""
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.labelSize
                    font.weight: 600
                }

                Text {
                    Layout.fillWidth: true
                    text: argPopup.baseCommand
                    elide: Text.ElideMiddle
                    color: Theme.textMute
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.descSize
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap

            InputField {
                id: inputField
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                placeholder: "Extra arguments"
                onAccepted: (v) => argPopup.launchWith(v)
            }

            ActionButton {
                label: "Launch"
                tone: "accent"
                onActivated: argPopup.launchWith(inputField.text)
            }

            ActionButton {
                label: "Close"
                onActivated: argPopup.forceClose()
            }
        }

        Text {
            Layout.fillWidth: true
            visible: argPopup.savedArgs.length > 0
            text: "Saved for this app"
            color: Theme.textMute
            font.family: Theme.fontFamily
            font.pixelSize: Theme.descSize
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6
            visible: argPopup.savedArgs.length > 0

            Repeater {
                model: argPopup.savedArgs

                delegate: Rectangle {
                    required property var modelData

                    width: argText.implicitWidth + 22
                    height: 26
                    radius: Theme.radiusSmall
                    color: argArea.containsMouse ? Theme.alpha(Theme.accent, 0.22)
                                                 : Theme.alpha(Theme.textBase, 0.10)
                    border.width: Theme.borderWidth
                    border.color: Theme.border

                    Text {
                        id: argText
                        anchors.centerIn: parent
                        text: modelData
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.valueSize
                    }

                    MouseArea {
                        id: argArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: argPopup.launchWith(modelData)
                    }
                }
            }
        }
    }
}
