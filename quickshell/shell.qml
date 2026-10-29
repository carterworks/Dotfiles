//@ pragma UseQApplication
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

    // A single popup stack avoids duplicating notifications on every monitor.
    NotificationPopups {
        id: notificationPopups
        notificationServer: notifications
    }

    Variants {
        model: notifications.trackedNotifications.values
        delegate: Component {
            QtObject {
                id: lifetime
                required property var modelData
                readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                readonly property bool timed: modelData.expireTimeout > 0 || (modelData.transient && modelData.expireTimeout !== 0)
                // Quickshell reports the freedesktop timeout in milliseconds despite documenting seconds.
                readonly property double baseInterval: modelData.expireTimeout > 0 ? modelData.expireTimeout : 6000
                readonly property bool hovered: notificationPopups ? notificationPopups.isHovered(lifetime.modelData.id) : false
                property double remainingMs: baseInterval
                property double resumedAt: 0

                function startCountdown() {
                    if (!lifetime.timed || lifetime.critical) return;
                    if (lifetime.remainingMs <= 0) {
                        lifetime.modelData.expire();
                        return;
                    }
                    expiry.interval = lifetime.remainingMs;
                    expiry.restart();
                    lifetime.resumedAt = Date.now();
                }

                function pauseCountdown() {
                    if (!expiry.running) return;
                    expiry.stop();
                    lifetime.remainingMs = Math.max(0, lifetime.remainingMs - (Date.now() - lifetime.resumedAt));
                }

                function resetCountdown() {
                    lifetime.remainingMs = lifetime.baseInterval;
                    expiry.stop();
                    if (lifetime.timed && !lifetime.critical && !lifetime.hovered) lifetime.startCountdown();
                }

                onHoveredChanged: {
                    if (lifetime.hovered) lifetime.pauseCountdown();
                    else lifetime.startCountdown();
                }
                Component.onCompleted: lifetime.startCountdown()

                property Timer expiry: Timer {
                    running: false
                    onTriggered: lifetime.modelData.expire()
                }
                property Connections updates: Connections {
                    target: lifetime.modelData
                    function onSummaryChanged() { lifetime.resetCountdown(); }
                    function onBodyChanged() { lifetime.resetCountdown(); }
                    function onExpireTimeoutChanged() { lifetime.resetCountdown(); }
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
                audioPanel: audio
            }
        }
    }

    AudioPanel { id: audio }
}
