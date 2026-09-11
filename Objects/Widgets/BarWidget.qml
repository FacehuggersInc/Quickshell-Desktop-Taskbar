import QtQuick

import qs.Objects.Design
import qs.Objects.Theme
import qs.Objects.Widgets

// Resolves a widget id from config into the component that draws it, so the bar
// layout can be data rather than hardcoded markup.
Loader {
    id: slot

    required property string widgetId

    active: widgetId !== ""

    sourceComponent: {
        if (widgetId === "workspaces") return workspacesComponent
        if (widgetId === "appbar") return appbarComponent
        if (widgetId === "clock") return clockComponent
        if (widgetId === "date") return dateComponent
        if (widgetId === "volume") return volumeComponent
        if (widgetId === "network") return networkComponent
        if (widgetId === "bluetooth") return bluetoothComponent
        if (widgetId === "tray") return trayComponent
        if (widgetId === "notifications") return notificationsComponent
        if (widgetId === "separator") return separatorComponent
        return null
    }

    Component { id: workspacesComponent; WorkspaceSwitcherWidget {} }
    Component { id: appbarComponent; AppBarWidget {} }
    Component { id: clockComponent; ClockWidget {} }
    Component { id: dateComponent; DateWidget {} }
    Component { id: volumeComponent; VolumeWidget {} }
    Component { id: networkComponent; NetworkWidget {} }
    Component { id: bluetoothComponent; BluetoothWidget {} }
    // SystemTray is a RoundedBlock in its own right. Inside a zone it has to
    // stop drawing its own surface, or it paints a block within a block.
    Component {
        id: trayComponent
        SystemTray {
            color: "transparent"
            border: false
            highlight: false
            elevated: false
            sidePadding: 0
            tbPadding: 0
        }
    }
    Component { id: notificationsComponent; NotificationsWidget {} }

    Component {
        id: separatorComponent
        Rectangle {
            width: 1
            height: 18
            color: Theme.border
        }
    }
}
