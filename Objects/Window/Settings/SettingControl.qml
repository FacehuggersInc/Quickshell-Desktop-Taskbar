import QtQuick

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme
import qs.Objects.Systems

SettingRow {
    id: entry

    required property var item

    // Steppers can present a scaled unit — minutes over a value stored in ms
    // The schema field is still named scale; only this property was renamed,
    // because scale is an Item property and cannot be shadowed
    readonly property real scaleFactor: item.scale ? item.scale : 1

    label: item.label
    description: item.description || ""
    iconName: item.icon || ""
    stacked: item.type === "slider" || item.type === "field"

    // ## Config access
    // Lives here rather than in the schema singleton, because a singleton is
    // created outside the component tree and the ShellRoot id does not resolve
    // in it — every read there fell through to its fallback.

    property int revision: 0

    function value(fallback) {
        var undef = item.fallback !== undefined ? item.fallback : fallback
        if (!item.key)
            return undef

        var bump = entry.revision
        var parts = item.key.split(".")
        var node = root.settings
        for (var i = 0; i < parts.length; i++) {
            if (node === undefined || node === null)
                return undef
            node = node[parts[i]]
        }
        return node === undefined || node === null ? undef : node
    }

    function commit(v) {
        if (!item.key)
            return

        var parts = item.key.split(".")
        var node = root.settings
        for (var i = 0; i < parts.length - 1; i++) {
            if (node[parts[i]] === undefined || node[parts[i]] === null)
                node[parts[i]] = ({})
            node = node[parts[i]]
        }
        node[parts[parts.length - 1]] = v
        root.saveSettings()
        entry.revision++

        if (item.apply)
            entry.applySideEffect(item.apply, v)
    }

    // Options that depend on live state cannot be declared in a static schema
    readonly property var resolvedOptions: {
        if (item.optionsFrom === "monitors") {
            var out = []
            var mons = HyprlandSystem.monitors
            for (var i = 0; i < mons.length; i++)
                out.push({ label: mons[i].name, value: i })
            return out
        }
        return item.options ? item.options : []
    }

    // Some settings have a side effect beyond being written to config
    function applySideEffect(name, v) {
        // Through HyprlandSystem so these use the same hyprctl keyword path as
        // the display editor rather than a config command string
        if (name === "hyprAnimations") {
            HyprlandSystem.setOption("animations:enabled",
                                     v ? "1" : "0", v ? "true" : "false")
        } else if (name === "hyprBlur") {
            HyprlandSystem.setOption("decoration:blur:enabled",
                                     v ? "true" : "false", v ? "true" : "false")
        }
    }

    function runAction(name) {
        if (name === "brightnessRefresh") BrightnessSystem.refresh()
        else if (name === "hyprReload") root.cmdExec("hypr_reload")
        else if (name === "restartShell") root.cmdExec("restart_shell")
        else if (name === "editConfig") root.cmdExec("config_json")
        else if (name === "editShell") root.cmdExec("config_quickshell")
    }

    Loader {
        sourceComponent: {
            if (entry.item.type === "switch") return switchControl
            if (entry.item.type === "segmented") return segmentedControl
            if (entry.item.type === "select") return selectControl
            if (entry.item.type === "stepper") return stepperControl
            if (entry.item.type === "field") return fieldControl
            if (entry.item.type === "slider") return sliderControl
            if (entry.item.type === "brightness") return brightnessControl
            if (entry.item.type === "action") return actionControl
            return null
        }
    }

    Component {
        id: switchControl
        ToggleSwitch {
            checked: entry.value(false)
            onToggled: (v) => entry.commit(v)
        }
    }

    Component {
        id: segmentedControl
        SegmentedControl {
            options: entry.resolvedOptions
            value: entry.value(null)
            onPicked: (v) => entry.commit(v)
        }
    }

    Component {
        id: selectControl
        SelectBox {
            width: Math.min(240, Math.max(Theme.controlMinWidth + 40, entry.width * 0.4))
            options: entry.resolvedOptions
            value: entry.value(null)
            onPicked: (v) => entry.commit(v)
        }
    }

    Component {
        id: stepperControl
        NumberStepper {
            from: entry.item.from
            to: entry.item.to
            step: entry.item.step || 1
            suffix: entry.item.suffix || ""
            value: Math.round(entry.value(entry.item.from) / entry.scaleFactor)
            onChanged: (v) => entry.commit(Math.round(v * entry.scaleFactor))
        }
    }

    Component {
        id: fieldControl
        InputField {
            id: field
            width: entry.width - (entry.iconName !== "" ? 28 : 0)
            text: String(entry.value(""))
            onCommitted: (v) => entry.commit(v)

            // config.json is a plain object, so a nested read registers no
            // dependency — the revision counter is what re-evaluates this.
            // Suspended while focused, otherwise it overwrites what is typed.
            Binding {
                target: field
                property: "text"
                value: String(entry.value(""))
                when: !field.hasFocus
            }
        }
    }

    Component {
        id: sliderControl
        Item {
            width: entry.width - (entry.iconName !== "" ? 28 : 0)
            height: Theme.controlHeight

            CustomSlider {
                id: slider
                anchors.left: parent.left
                anchors.right: readout.left
                anchors.rightMargin: Theme.gap
                anchors.verticalCenter: parent.verticalCenter
                from: entry.item.from
                to: entry.item.to
                stepSize: entry.item.step || 1
                value: entry.value(entry.item.from)
                onMoved: entry.commit(Math.round(this.value * 100) / 100)
            }

            Text {
                id: readout
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                horizontalAlignment: Text.AlignRight
                text: Math.round(slider.value * 100) / 100
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.valueSize
            }
        }
    }

    Component {
        id: brightnessControl
        Item {
            width: entry.width - (entry.iconName !== "" ? 28 : 0)
            height: Theme.controlHeight

            CustomSlider {
                id: brightSlider
                anchors.left: parent.left
                anchors.right: brightReadout.left
                anchors.rightMargin: Theme.gap
                anchors.verticalCenter: parent.verticalCenter
                from: 0
                to: 100
                stepSize: 1
                enabled: BrightnessSystem.available
                opacity: enabled ? 1.0 : 0.4
                onMoved: BrightnessSystem.set(this.value)

                Binding {
                    target: brightSlider
                    property: "value"
                    value: BrightnessSystem.value
                    when: !brightSlider.pressed
                }
            }

            Text {
                id: brightReadout
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                horizontalAlignment: Text.AlignRight
                text: BrightnessSystem.available ? BrightnessSystem.value + "%" : "--"
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.valueSize
            }
        }
    }

    Component {
        id: actionControl
        Rectangle {
            width: 96
            height: Theme.controlHeight
            radius: Theme.radiusSmall
            color: actionArea.containsMouse ? Theme.alpha(Theme.accent, 0.22)
                                            : Theme.alpha(Theme.textBase, 0.10)
            border.width: Theme.borderWidth
            border.color: Theme.border

            Behavior on color { ColorAnimation { duration: Theme.durFast } }

            Text {
                anchors.centerIn: parent
                text: "Run"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.valueSize
                font.weight: 600
            }

            MouseArea {
                id: actionArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: entry.runAction(entry.item.action)
            }
        }
    }
}
