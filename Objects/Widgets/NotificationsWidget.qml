import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Window

IconButton {
    id: notifyWidget
    iconName: "notify"
    iconSize: 25
    tooltipText: "0 Unread"
    color: '#252525'

    Component.onCompleted: {
        root.notifyServer.notification.connect(notifyWidget.onNewNotification)
        notifyWidget.updateBadge()
    }

    NotificationPopup {
        id: notificationPopup
    }

    function onNewNotification(notif) {
        if (!notif || notif.lastGeneration) return

        notif.tracked = true

        // Pass the full notification object so the popup card
        // can render action buttons (e.g. "Open in Files" for USB)
        notificationPopup.notification = notif
        notificationPopup.setPopupIcon(root.notifyServer.iconName)
        notificationPopup.toggle()

        // Update badge immediately on new notification
        updateBadge()
    }

    function updateBadge() {
        var count = root.notifyServer.trackedNotifications.values.length
        tooltipText = count + " Unread"
        if (count > 0) {
            notifyWidget.setIcon("notify_unread")
            notifyWidget.setColor("#ffffff")
        } else {
            notifyWidget.setIcon("notify")
            notifyWidget.setColor("#252525")
        }
    }

    // ## Badge
    // The model's length is a bindable property, so the count updates itself.
    // The old handlers named signals the target does not have — they warned on
    // every start and never fired, leaving a 500ms poll doing the real work.

    readonly property int notificationCount: root.notifyServer
        ? root.notifyServer.trackedNotifications.values.length : 0

    onNotificationCountChanged: notifyWidget.updateBadge()

    onClicked: {
        if (root.notificationsPanel)
            root.notificationsPanel.toggle(notifyWidget)
    }
}