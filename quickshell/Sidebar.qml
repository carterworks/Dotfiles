pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Wayland

PanelWindow {
    id: sidebar
    required property var notificationServer
    property bool showNotifications: false
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property var workspace: monitor ? monitor.activeWorkspace : null
    readonly property var windows: Hyprland.toplevels.values.filter(w => w.workspace === workspace)
    readonly property var notifications: notificationServer.trackedNotifications.values.filter(n => !n.transient)

    anchors { top: true; bottom: true; left: true }
    implicitWidth: Theme.sidebarWidth
    exclusiveZone: Theme.sidebarWidth
    color: Theme.background
    WlrLayershell.namespace: "miasma-sidebar"

    SystemClock { id: clock; precision: SystemClock.Minutes }

    ColumnLayout {
        anchors { fill: parent; margins: 14 }
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 2
            ShellButton {
                label: "Audio controls"
                iconName: "volume-2"
                iconOnly: true
                flat: true
                implicitWidth: 28
                implicitHeight: 28
                onClicked: Quickshell.execDetached(["uwsm", "app", "--", "kcmshell6", "kcm_pulseaudio"])
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: Qt.formatDateTime(clock.date, "h:mm AP")
                    color: Theme.text
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
                Text {
                    text: Qt.formatDateTime(clock.date, "yyyy-MM-dd")
                    color: Theme.muted
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }
        }

        ShellButton {
            label: "Search anything"
            iconName: "search"
            Layout.fillWidth: true
            onClicked: Quickshell.execDetached(["vicinae", "toggle"])
        }

        RowLayout {
            Layout.fillWidth: true
            ShellButton {
                label: "Files"
                iconName: "folder"
                iconOnly: true
                Layout.fillWidth: true
                implicitHeight: 46
                onClicked: Quickshell.execDetached(["uwsm", "app", "--", "dolphin"])
            }
            ShellButton {
                label: "Terminal"
                iconName: "terminal"
                iconOnly: true
                Layout.fillWidth: true
                implicitHeight: 46
                onClicked: Quickshell.execDetached(["uwsm", "app", "--", "ghostty"])
            }
            ShellButton {
                label: "Browser"
                iconName: "globe"
                iconOnly: true
                Layout.fillWidth: true
                implicitHeight: 46
                onClicked: Quickshell.execDetached(["uwsm", "app", "--", "zen-beta"])
            }
            ShellButton {
                label: "Music"
                iconName: "music"
                iconOnly: true
                Layout.fillWidth: true
                implicitHeight: 46
                onClicked: Quickshell.execDetached(["uwsm", "app", "--", "spotify"])
            }
        }

        RowLayout {
            spacing: 8
            Image {
                source: Qt.resolvedUrl("icons/" + (sidebar.showNotifications ? "bell" : "lightbulb") + ".svg")
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
            }
            Text {
                text: sidebar.showNotifications ? "Notifications" : "Space " + (sidebar.workspace ? sidebar.workspace.name : "—")
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 12
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.surface
        }

        ScrollView {
            id: windowScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth

            ColumnLayout {
                width: windowScroll.availableWidth
                spacing: 3
                Repeater {
                    model: sidebar.showNotifications ? [] : sidebar.windows
                    ShellButton {
                        required property var modelData
                        readonly property string appId: modelData.wayland ? modelData.wayland.appId : modelData.lastIpcObject.class || ""
                        readonly property var desktopEntry: DesktopEntries.heuristicLookup(appId)
                        label: modelData.title || "Untitled window"
                        iconSource: desktopEntry && desktopEntry.icon ? Quickshell.iconPath(desktopEntry.icon, "application-x-executable") : Qt.resolvedUrl("icons/app-window.svg")
                        flat: true
                        selected: modelData.activated
                        Layout.fillWidth: true
                        implicitHeight: 36
                        onClicked: {
                            if (modelData.wayland) modelData.wayland.activate();
                        }
                    }
                }
                Repeater {
                    model: sidebar.showNotifications ? sidebar.notifications : []
                    NotificationCard {
                        required property var modelData
                        notification: modelData
                        Layout.fillWidth: true
                    }
                }
                Text {
                    visible: sidebar.showNotifications && sidebar.notifications.length === 0
                    text: "All caught up."
                    color: Theme.muted
                    font.pixelSize: 12
                    Layout.topMargin: 12
                }
            }
        }

        MediaCard { Layout.fillWidth: true }

        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: SystemTray.items
                Rectangle {
                    id: trayIcon
                    required property var modelData
                    width: 32
                    height: 32
                    radius: 8
                    color: trayMouse.containsMouse ? Theme.hover : "transparent"
                    Image {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        source: trayIcon.modelData.icon
                    }
                    MouseArea {
                        id: trayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.MiddleButton) {
                                trayIcon.modelData.secondaryActivate();
                            } else if (mouse.button === Qt.RightButton || trayIcon.modelData.onlyMenu) {
                                const point = trayIcon.mapToItem(sidebar.contentItem, trayIcon.width, trayIcon.height);
                                trayIcon.modelData.display(sidebar, point.x, point.y);
                            } else {
                                trayIcon.modelData.activate();
                            }
                        }
                        onWheel: wheel => trayIcon.modelData.scroll(wheel.angleDelta.y, false)
                    }
                    ToolTip.visible: trayMouse.containsMouse
                    ToolTip.text: modelData.tooltipTitle || modelData.title
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            ShellButton {
                label: "Notifications (" + sidebar.notifications.length + ")"
                iconName: "bell"
                iconOnly: true
                flat: true
                selected: sidebar.showNotifications
                implicitWidth: 28
                implicitHeight: 28
                onClicked: sidebar.showNotifications = !sidebar.showNotifications
            }
            Item {
                Layout.fillWidth: true
                implicitHeight: 28
                Row {
                    anchors.centerIn: parent
                    Repeater {
                        model: 10
                        AbstractButton {
                            id: spaceDot
                            required property int index
                            readonly property bool active: sidebar.workspace && sidebar.workspace.id === index + 1
                            width: 14
                            height: 28
                            hoverEnabled: true
                            Accessible.name: "Workspace " + (index + 1)
                            contentItem: Item {
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: spaceDot.active ? 7 : 6
                                    height: width
                                    radius: width / 2
                                    color: spaceDot.active ? Theme.accent : "transparent"
                                    border.width: spaceDot.active ? 0 : 1
                                    border.color: spaceDot.hovered ? Theme.text : Theme.muted
                                }
                            }
                            ToolTip.visible: hovered
                            ToolTip.text: Accessible.name
                            onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + (index + 1) + " })")
                        }
                    }
                }
            }
            Item {
                // Balance the bell so workspace dots stay centered in the sidebar.
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
            }
        }
    }
}
