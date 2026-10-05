pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland

PanelWindow {
    id: popups
    required property var notificationServer
    property var shownIds: []
    readonly property var shown: notificationServer.trackedNotifications.values.filter(n => shownIds.includes(n.id))
    visible: shown.length > 0
    anchors { top: true; right: true }
    margins { top: 16; right: 16 }
    implicitWidth: 340
    implicitHeight: stack.implicitHeight
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "miasma-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    color: "transparent"

    function show(notification) {
        shownIds = [...shownIds.filter(id => id !== notification.id), notification.id].slice(-3);
    }

    Connections {
        target: popups.notificationServer
        function onNotification(notification) {
            if (!notification.lastGeneration) popups.show(notification);
        }
    }

    Variants {
        model: popups.notificationServer.trackedNotifications.values
        delegate: Component {
            QtObject {
                id: watcher
                required property var modelData
                property Connections updates: Connections {
                    target: watcher.modelData
                    function onSummaryChanged() { popups.show(watcher.modelData); }
                    function onBodyChanged() { popups.show(watcher.modelData); }
                    function onExpireTimeoutChanged() { popups.show(watcher.modelData); }
                }
            }
        }
    }

    Column {
        id: stack
        width: parent.width
        spacing: 8
        Repeater {
            model: popups.shown
            NotificationCard {
                id: toast
                required property var modelData
                width: stack.width
                notification: modelData
                Timer {
                    interval: toast.notification.expireTimeout > 0 ? toast.notification.expireTimeout * 1000 : 6000
                    running: toast.notification.expireTimeout !== 0 && toast.notification.urgency !== NotificationUrgency.Critical
                    onTriggered: popups.shownIds = popups.shownIds.filter(id => id !== toast.notification.id)
                }
            }
        }
    }
}
