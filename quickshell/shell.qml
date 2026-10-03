pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

ShellRoot {
    id: root

    NotificationServer {
        id: notifications
        bodySupported: true
        actionsSupported: true
        persistenceSupported: true
        onNotification: notification => notification.tracked = true
    }

    Variants {
        model: notifications.trackedNotifications.values
        delegate: Component {
            QtObject {
                id: lifetime
                required property var modelData
                readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                property Timer expiry: Timer {
                    interval: lifetime.modelData.expireTimeout > 0 ? lifetime.modelData.expireTimeout * 1000 : 6000
                    running: lifetime.modelData.expireTimeout > 0 || (lifetime.modelData.transient && lifetime.modelData.expireTimeout !== 0 && !lifetime.critical)
                    onTriggered: lifetime.modelData.expire()
                }
                property Connections updates: Connections {
                    target: lifetime.modelData
                    function onSummaryChanged() { if (lifetime.expiry.running) lifetime.expiry.restart(); }
                    function onBodyChanged() { if (lifetime.expiry.running) lifetime.expiry.restart(); }
                    function onExpireTimeoutChanged() { if (lifetime.expiry.running) lifetime.expiry.restart(); }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Wallpaper {
                required property var modelData
                screen: modelData
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Sidebar {
                required property var modelData
                screen: modelData
                notificationServer: notifications
            }
        }
    }

    // A single popup stack avoids duplicating notifications on every monitor.
    NotificationPopups { notificationServer: notifications }
}
