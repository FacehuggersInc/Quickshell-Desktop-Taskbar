import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme
import qs.Objects.Systems

ColumnLayout {
    id: page
    spacing: 0

    property string joining: ""
    property string secret: ""

    SectionLabel {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        text: "Interfaces"
    }

    Repeater {
        model: NetworkSystem.devices

        delegate: Rectangle {
            required property var modelData

            readonly property bool up: modelData.state.indexOf("connected") === 0

            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.preferredHeight: 52
            radius: Theme.radiusSmall
            color: Theme.alpha(Theme.scrimBase, 0.35)
            border.width: Theme.borderWidth
            border.color: up ? Theme.accentLine : Theme.alpha(Theme.textBase, 0.08)

            Icon {
                id: deviceIcon
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                iconName: modelData.type === "wifi" ? "wifi_max" : "wired"
                iconSize: 18
                color: parent.up ? Theme.accentIcon : Theme.textMute
            }

            Column {
                anchors.left: deviceIcon.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: modelData.device + "  ·  " + modelData.type
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.labelSize
                    font.weight: 600
                }

                Text {
                    text: modelData.connection !== "" && modelData.connection !== "--"
                        ? modelData.state + " to " + modelData.connection
                        : modelData.state
                    color: Theme.textMute
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.descSize
                }
            }
        }
    }

    SectionLabel {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        text: "Wi-Fi"
    }

    SettingRow {
        Layout.fillWidth: true
        iconName: "wifi_max"
        label: "Wi-Fi Radio"
        description: NetworkSystem.wifiEnabled ? "On" : "Off"

        Row {
            spacing: 6

            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: NetworkSystem.wifiEnabled
                onToggled: (v) => NetworkSystem.setWifi(v)
            }

            ActionButton {
                label: "Scan"
                busy: NetworkSystem.busy
                enabled: NetworkSystem.wifiEnabled
                onActivated: NetworkSystem.scan()
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 8
        visible: NetworkSystem.lastError !== ""
        text: NetworkSystem.lastError
        wrapMode: Text.WordWrap
        color: Theme.danger
        font.family: Theme.fontFamily
        font.pixelSize: Theme.descSize
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 8
        visible: NetworkSystem.wifiEnabled && NetworkSystem.networks.length === 0
        text: NetworkSystem.scanned ? "No networks found." : "Scanning…"
        color: Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: Theme.descSize
    }

    Repeater {
        model: NetworkSystem.wifiEnabled ? NetworkSystem.networks : []

        delegate: Rectangle {
            id: netRow
            required property var modelData

            readonly property var saved: NetworkSystem.savedFor(modelData.ssid)
            readonly property bool joining: page.joining === modelData.ssid
            readonly property bool secured: modelData.security !== ""
                && modelData.security !== "--"

            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.preferredHeight: netRow.joining ? 92 : 54
            radius: Theme.radiusSmall
            color: modelData.active ? Theme.alpha(Theme.accent, 0.14)
                                    : Theme.alpha(Theme.scrimBase, 0.35)
            border.width: Theme.borderWidth
            border.color: modelData.active ? Theme.accentLine
                                           : Theme.alpha(Theme.textBase, 0.08)

            Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.durFast } }

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                height: 38
                spacing: Theme.gap

                Icon {
                    iconName: netRow.secured ? "lock" : "wifi_max"
                    iconSize: 18
                    color: netRow.modelData.active ? Theme.accentIcon : Theme.textMute
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: netRow.modelData.ssid
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.labelSize
                        font.weight: 600
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            var bits = [netRow.modelData.signal + "%"]
                            if (netRow.secured) bits.push(netRow.modelData.security)
                            if (netRow.saved) bits.push("saved")
                            if (netRow.modelData.active) bits.push("connected")
                            return bits.join("  ·  ")
                        }
                        elide: Text.ElideRight
                        color: netRow.modelData.active ? Theme.accentText : Theme.textMute
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.descSize
                    }
                }

                ActionButton {
                    visible: !netRow.modelData.active
                    label: netRow.saved ? "Connect" : "Join"
                    tone: "accent"
                    onActivated: {
                        NetworkSystem.lastError = ""
                        if (netRow.saved) {
                            NetworkSystem.connectSaved(netRow.saved.uuid)
                        } else if (netRow.secured) {
                            page.secret = ""
                            page.joining = netRow.modelData.ssid
                        } else {
                            NetworkSystem.connectWifi(netRow.modelData.ssid, "")
                        }
                    }
                }

                ActionButton {
                    visible: netRow.modelData.active && netRow.saved !== null
                    label: "Disconnect"
                    onActivated: NetworkSystem.disconnect(netRow.saved.uuid)
                }

                ActionButton {
                    visible: netRow.saved !== null
                    label: "Forget"
                    tone: "danger"
                    onActivated: NetworkSystem.forget(netRow.saved.uuid)
                }
            }

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 8
                height: 30
                spacing: Theme.gap
                visible: netRow.joining

                InputField {
                    id: secretField
                    Layout.fillWidth: true
                    placeholder: "Password for " + netRow.modelData.ssid
                }

                ActionButton {
                    label: "Join"
                    tone: "accent"
                    onActivated: {
                        NetworkSystem.connectWifi(netRow.modelData.ssid, secretField.text)
                        page.joining = ""
                    }
                }

                ActionButton {
                    label: "Cancel"
                    onActivated: page.joining = ""
                }
            }
        }
    }

    SectionLabel {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        text: "Saved Connections"
    }

    Repeater {
        model: NetworkSystem.connections

        delegate: Rectangle {
            required property var modelData

            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.preferredHeight: 50
            radius: Theme.radiusSmall
            color: Theme.alpha(Theme.scrimBase, 0.28)
            border.width: Theme.borderWidth
            border.color: modelData.active ? Theme.accentLine
                                           : Theme.alpha(Theme.textBase, 0.08)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: Theme.gap

                Icon {
                    iconName: modelData.type.indexOf("wireless") !== -1
                        || modelData.type === "wifi" ? "wifi_max"
                        : (modelData.type.indexOf("vpn") !== -1 ? "vpn" : "wired")
                    iconSize: 16
                    color: modelData.active ? Theme.accentIcon : Theme.textMute
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: modelData.name
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.valueSize
                        font.weight: 600
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.type
                            + (modelData.active ? "  ·  active on " + modelData.device : "")
                        elide: Text.ElideRight
                        color: Theme.textMute
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.descSize
                    }
                }

                ActionButton {
                    label: modelData.active ? "Disconnect" : "Connect"
                    tone: modelData.active ? "neutral" : "accent"
                    onActivated: {
                        NetworkSystem.lastError = ""
                        if (modelData.active)
                            NetworkSystem.disconnect(modelData.uuid)
                        else
                            NetworkSystem.connectSaved(modelData.uuid)
                    }
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 10
        text: "Managed through NetworkManager. Joining a secured network stores it as a saved connection, and Forget removes it."
        wrapMode: Text.WordWrap
        color: Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: Theme.descSize
    }
}
