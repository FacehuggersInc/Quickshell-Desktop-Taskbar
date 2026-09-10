import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Qt5Compat.GraphicalEffects
import qs.Objects.Design
import qs.Objects.Widgets

// Custom app entry form
Item {
    id: customView

    signal saveRequested(var data)

    function reset() {
        nameField.text      = ""
        commandField.text   = ""
        classNameField.text = ""
        iconField.text      = ""
        optionsModel.clear()
        lockOptionsCheck.checked   = false
        ignoreOptionsCheck.checked = false
        masqueField.text           = ""
    }

    // Options model — each item has a single string that becomes one option set
    // On save, each string is split by spaces into a list of args
    ListModel { id: optionsModel }

    ScrollView {
        anchors.fill: parent
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        contentHeight: formColumn.implicitHeight
        clip: true

        ColumnLayout {
            id: formColumn
            width: customView.width
            spacing: 14

            // ── Name ─────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: "Nickname"
                    color: root.theme.text
                    opacity: 0.6
                    font.family: root.settings.fontFamily
                    font.pixelSize: 12
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: 6
                    color: root.theme.surface
                    TextField {
                        id: nameField
                        anchors.fill: parent
                        anchors.margins: 8
                        placeholderText: "e.g. VS Code"
                        color: root.theme.text
                        font.family: root.settings.fontFamily
                        font.pixelSize: 14
                        background: Item {}
                    }
                }
            }

            // ── Class name ────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: "Class Name  (used for window matching & icon lookup)"
                    color: root.theme.text
                    opacity: 0.6
                    font.family: root.settings.fontFamily
                    font.pixelSize: 12
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: 6
                    color: root.theme.surface
                    TextField {
                        id: classNameField
                        anchors.fill: parent
                        anchors.margins: 8
                        placeholderText: "e.g. code  or  org.gnome.Nautilus"
                        color: root.theme.text
                        font.family: root.settings.fontFamily
                        font.pixelSize: 14
                        background: Item {}
                    }
                }
            }

            // ── Command ───────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: "Launch Command"
                    color: root.theme.text
                    opacity: 0.6
                    font.family: root.settings.fontFamily
                    font.pixelSize: 12
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: 6
                    color: root.theme.surface
                    TextField {
                        id: commandField
                        anchors.fill: parent
                        anchors.margins: 8
                        placeholderText: "e.g. code  or  /usr/bin/code"
                        color: root.theme.text
                        font.family: root.settings.fontFamily
                        font.pixelSize: 14
                        background: Item {}
                    }
                }
            }

            // ── Icon path (optional) ──────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: "Icon Path  (optional — leave blank to auto-detect from class name)"
                    color: root.theme.text
                    opacity: 0.6
                    font.family: root.settings.fontFamily
                    font.pixelSize: 12
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: 6
                    color: root.theme.surface
                    TextField {
                        id: iconField
                        anchors.fill: parent
                        anchors.margins: 8
                        placeholderText: "e.g. /usr/share/icons/... or leave blank"
                        color: root.theme.text
                        font.family: root.settings.fontFamily
                        font.pixelSize: 14
                        background: Item {}
                    }
                }
            }

            // ── Options ───────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Option Sets"
                        color: root.theme.text
                        font.family: root.settings.fontFamily
                        font.weight: 600
                        font.pixelSize: 14
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "The Custom Sets of args that will allow quick launching of the Launch Command + Args in the context menu of a pinned app. \nEach set is a string split by spaces, this becomes the Args to launch with"
                        color: root.theme.text
                        opacity: 0.45
                        font.family: root.settings.fontFamily
                        font.pixelSize: 11
                    }
                    RoundButton {
                        text: "+ Add Option Set"
                        font.family: root.settings.fontFamily
                        font.pixelSize: 12
                        padding: 4
                        horizontalPadding: 10
                        contentItem: Text {
                            text: parent.text
                            font: parent.font
                            color: root.theme.text
                            horizontalAlignment: Text.AlignHCenter
                        }
                        background: Rectangle {
                            radius: 6
                            color: root.theme.primary
                            opacity: 0.5
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        onClicked: optionsModel.append({ "value": "" })
                    }
                }

                // One row per option set
                Repeater {
                    model: optionsModel
                    delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            height: 34
                            radius: 6
                            color: root.theme.surface

                            TextField {
                                anchors.fill: parent
                                anchors.margins: 6
                                text: model.value
                                placeholderText: "e.g. --new-window /home/{user}/project"
                                color: root.theme.text
                                font.family: root.settings.fontFamily
                                font.pixelSize: 13
                                background: Item {}
                                onTextChanged: optionsModel.setProperty(model.index, "value", text)
                            }
                        }

                        // Remove button
                        IconButton {
                            iconName: "close"
                            iconSize: 16
                            color: "#e05555"
                            tooltipText: "Remove"
                            onClicked: optionsModel.remove(model.index)
                        }
                    }
                }

                Text {
                    visible: optionsModel.count === 0
                    text: "No option sets — app will always launch with no args"
                    color: root.theme.text
                    opacity: 0.35
                    font.family: root.settings.fontFamily
                    font.pixelSize: 12
                    font.italic: true
                }
            }

            // ── Masque ───────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "Masque Under  (optional — class name of pinned app to merge into)"
                    color: root.theme.text
                    opacity: 0.6
                    font.family: root.settings.fontFamily
                    font.pixelSize: 12
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        radius: 6
                        color: root.theme.surface
                        TextField {
                            id: masqueField
                            anchors.fill: parent
                            anchors.margins: 6
                            placeholderText: "e.g. code  — leave blank for none"
                            color: root.theme.text
                            font.family: root.settings.fontFamily
                            font.pixelSize: 13
                            background: Item {}
                        }
                    }

                    // Quick-pick from pinned apps — expands inline
                    RoundButton {
                        id: masquePickerBtn
                        text: masquePickerList.visible ? "Pick pinned ▴" : "Pick pinned ▾"
                        font.family: root.settings.fontFamily
                        font.pixelSize: 12
                        padding: 6
                        horizontalPadding: 14
                        contentItem: Text {
                            text: parent.text
                            font: parent.font
                            color: root.theme.text
                            horizontalAlignment: Text.AlignHCenter
                        }
                        background: Rectangle {
                            radius: 6
                            color: root.theme.surface
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        onClicked: masquePickerList.visible = !masquePickerList.visible
                    }
                }

                // Inline expandable list — no positioning issues
                ColumnLayout {
                    id: masquePickerList
                    visible: false
                    Layout.fillWidth: true
                    spacing: 2

                    Repeater {
                        model: root.settings.launchers
                        delegate: RoundButton {
                            required property var modelData
                            Layout.fillWidth: true
                            padding: 6
                            horizontalPadding: 10
                            contentItem: RowLayout {
                                spacing: 8
                                Image {
                                    source: modelData.icon && modelData.icon !== "*"
                                        ? modelData.icon
                                        : root.iconSource("open_app")
                                    width: 20; height: 20
                                    sourceSize.width: 20
                                    sourceSize.height: 20
                                    fillMode: Image.PreserveAspectFit
                                }
                                Text {
                                    text: modelData.nickname
                                        ? modelData.nickname + " (" + modelData.name + ")"
                                        : modelData.name
                                    font.family: root.settings.fontFamily
                                    font.pixelSize: 13
                                    color: root.theme.text
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                            background: Rectangle {
                                radius: 6
                                color: pickHov.hovered
                                    ? root.theme.primary
                                    : root.theme.surface
                                opacity: pickHov.hovered ? 0.4 : 0.6
                            }
                            HoverHandler { id: pickHov; cursorShape: Qt.PointingHandCursor }
                            onClicked: {
                                masqueField.text = modelData.name
                                masquePickerList.visible = false
                            }
                        }
                    }
                }
            }

            // ── Flags ─────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "Option Flags"
                    color: root.theme.text
                    font.family: root.settings.fontFamily
                    font.weight: 600
                    font.pixelSize: 14
                }

                CheckBox {
                    id: lockOptionsCheck
                    text: "Lock options — never update option sets from live process args"
                    font.family: root.settings.fontFamily
                    font.pixelSize: 13
                    contentItem: Text {
                        text: lockOptionsCheck.text
                        color: root.theme.text
                        font: lockOptionsCheck.font
                        leftPadding: lockOptionsCheck.indicator.width + 6
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                CheckBox {
                    id: ignoreOptionsCheck
                    text: "Ignore options — never save or show any option sets"
                    font.family: root.settings.fontFamily
                    font.pixelSize: 13
                    contentItem: Text {
                        text: ignoreOptionsCheck.text
                        color: root.theme.text
                        font: ignoreOptionsCheck.font
                        leftPadding: ignoreOptionsCheck.indicator.width + 6
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // ── Validation message ────────────────────────────────
            Text {
                id: validationMsg
                text: ""
                color: "#e05555"
                font.family: root.settings.fontFamily
                font.pixelSize: 13
                visible: text !== ""
            }

            // ── Save button ───────────────────────────────────────
            RoundButton {
                Layout.fillWidth: true
                text: "Pin App"
                font.family: root.settings.fontFamily
                font.pixelSize: 15
                font.weight: 600
                padding: 10

                contentItem: Text {
                    text: parent.text
                    font: parent.font
                    color: root.theme.text
                    horizontalAlignment: Text.AlignHCenter
                }
                background: Rectangle {
                    radius: 8
                    color: root.theme.primary
                    opacity: 0.8
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }

                onClicked: {
                    // Validate
                    if (classNameField.text.trim() === "") {
                        validationMsg.text = "Class name is required"
                        return
                    }
                    if (commandField.text.trim() === "") {
                        validationMsg.text = "Launch command is required"
                        return
                    }
                    validationMsg.text = ""

                    // Build options — each text field split by spaces
                    var opts = []
                    for (var i = 0; i < optionsModel.count; i++) {
                        var val = optionsModel.get(i).value.trim()
                        if (val !== "") {
                            opts.push(val.split(/\s+/))
                        }
                    }

                    customView.saveRequested({
                        name:          nameField.text.trim(),
                        command:       commandField.text.trim(),
                        icon:          iconField.text.trim(),
                        className:     classNameField.text.trim(),
                        options:       opts,
                        lockOptions:   lockOptionsCheck.checked,
                        ignoreOptions: ignoreOptionsCheck.checked,
                        masqueUnder:   masqueField.text.trim()
                    })
                }
            }

            // Bottom padding
            Item { implicitHeight: 8 }
        }
    }
}