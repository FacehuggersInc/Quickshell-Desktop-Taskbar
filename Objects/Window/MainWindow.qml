import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Window
import QtQuick.Controls

import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Widgets



PanelWindow {
    id: mainWindow

    // Shared tooltip window — all Tooltip items delegate here
    TooltipWindow {
        id: tooltipWindow
    }
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 60
    color: '#00ffffff'

    property int padding: 8
    property int spacing: 5

    Pane{
        anchors.fill: parent

        background : Rectangle {
            color: '#00000000'
            radius: 0
        }
        topPadding: mainWindow.padding

        // LEFT MODULES
        Row {
            anchors.left: parent.left
            anchors.leftMargin: mainWindow.padding
            anchors.verticalCenter: parent.verticalCenter
            spacing: mainWindow.spacing

            RoundedBlock {
                id: leftModules
                anchors.verticalCenter: parent.verticalCenter
                sidePadding: 15
                tbPadding: 0
                // Match implicit height to rightModules so they look the same
                implicitHeight: rightModules.implicitHeight

                WorkspaceSwitcherWidget {
                    anchors.centerIn: parent
                }
            }
        }
        
        // CENTER MODULES
        Row{
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: mainWindow.spacing

            AppBarWidget{
                id: appbar
                implicitHeight: rightModules.height 
            }
        }
        
        // RIGHT MODULES
        Row{
            anchors.right: parent.right
            anchors.rightMargin: mainWindow.padding
            anchors.verticalCenter: parent.verticalCenter
            spacing: mainWindow.spacing

            SystemTray {
                implicitHeight: rightModules.height
            }

            RoundedBlock{ 
                id: rightModules
                
                RowLayout {
                    spacing: 8

                    ColorPickerWidget {}
                    VolumeWidget {}
                    DatetimeWidget { 
                        format: root.settings.timeDateFormat
                        textColor: '#7be376'
                    }
                    InterfaceWidget {}
                    BluetoothWidget {}
                    IconButton{
                        id: settingsIconButton
                        iconName: "settings"
                        iconSize: 22
                        color: root.settings.theme.primary
                        tooltipText: "Open Settings"
                        onClicked: {
                            settingsPopupWin.toggle(settingsIconButton) 
                        }

                        SettingsManagementPopup{
                            id: settingsPopupWin
                        }
                        
                    }
                    NotificationsWidget {}
                }
            }
        }
    }
}