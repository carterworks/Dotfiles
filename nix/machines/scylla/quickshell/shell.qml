import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.SystemTray

ShellRoot {
    id: root

    readonly property color background: "#e612121a"
    readonly property color surface: "#332b2f45"
    readonly property color surfaceHover: "#554a5275"
    readonly property color accent: "#8ab4ff"
    readonly property color textPrimary: "#f4f4fb"
    readonly property color textSecondary: "#b8bdd6"

    property int currentDesktop: 1
    property int desktopCount: 3
    property string networkState: "offline"
    property int volumePercent: 0
    property bool volumeMuted: false

    function refreshDesktopState() {
        currentDesktopProcess.running = true
        desktopCountProcess.running = true
    }

    function refreshNetworkState() {
        networkProcess.running = true
    }

    function refreshVolumeState() {
        volumeProcess.running = true
    }

    Process {
        id: currentDesktopProcess
        command: ["qdbus", "org.kde.KWin", "/KWin", "currentDesktop"]
        stdout: StdioCollector {
            onStreamFinished: {
                var value = Number(this.text.trim())
                if (!isNaN(value) && value > 0)
                    root.currentDesktop = value
            }
        }
    }

    Process {
        id: desktopCountProcess
        command: ["qdbus", "org.kde.KWin", "/VirtualDesktopManager", "count"]
        stdout: StdioCollector {
            onStreamFinished: {
                var value = Number(this.text.trim())
                if (!isNaN(value) && value > 0)
                    root.desktopCount = value
            }
        }
    }

    Process {
        id: networkProcess
        command: ["nmcli", "-t", "-f", "STATE,CONNECTIVITY", "general"]
        stdout: StdioCollector {
            onStreamFinished: {
                var value = this.text.trim()
                root.networkState = value.indexOf("connected:") === 0 ? "connected" : "offline"
            }
        }
    }

    Process {
        id: volumeProcess
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                var value = this.text.trim()
                var match = /Volume:\s+([0-9.]+)/.exec(value)
                if (match)
                    root.volumePercent = Math.round(Number(match[1]) * 100)
                root.volumeMuted = value.indexOf("[MUTED]") !== -1
            }
        }
    }

    Process {
        id: muteProcess
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        onExited: root.refreshVolumeState()
    }

    Process { id: launcherProcess; command: ["vicinae", "toggle"] }
    Process { id: nextDesktopProcess; command: ["qdbus", "org.kde.KWin", "/KWin", "nextDesktop"] }
    Process { id: previousDesktopProcess; command: ["qdbus", "org.kde.KWin", "/KWin", "previousDesktop"] }
    Process { id: logoutProcess; command: ["qdbus", "org.kde.Shutdown", "/Shutdown", "logout"] }
    Process { id: rebootProcess; command: ["qdbus", "org.kde.Shutdown", "/Shutdown", "logoutAndReboot"] }
    Process { id: shutdownProcess; command: ["qdbus", "org.kde.Shutdown", "/Shutdown", "logoutAndShutdown"] }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.refreshDesktopState()
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: {
            root.refreshNetworkState()
            root.refreshVolumeState()
        }
    }

    Component.onCompleted: {
        root.refreshDesktopState()
        root.refreshNetworkState()
        root.refreshVolumeState()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData

            implicitWidth: 72
            anchors {
                left: true
                top: true
                bottom: true
            }
            margins {
                left: 8
                top: 8
                bottom: 8
            }
            exclusiveZone: 72
            exclusionMode: ExclusionMode.Auto
            color: "transparent"

            WlrLayershell.namespace: "scylla-arc-nav"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                anchors.fill: parent
                radius: 18
                color: root.background
                border.width: 1
                border.color: "#1affffff"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.topMargin: 8
                    anchors.bottomMargin: 8
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        radius: 13
                        color: launcherMouse.containsMouse ? root.surfaceHover : root.surface

                        Text {
                            anchors.centerIn: parent
                            text: "✦"
                            color: root.accent
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: 22
                        }

                        MouseArea {
                            id: launcherMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: launcherProcess.running = true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        Repeater {
                            model: root.desktopCount

                            Rectangle {
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredHeight: 22
                                radius: 7
                                color: index + 1 === root.currentDesktop ? root.accent : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: index + 1 === root.currentDesktop ? "●" : "○"
                                    color: index + 1 === root.currentDesktop ? "#151722" : root.textSecondary
                                    font.pixelSize: 11
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        if (index + 1 > root.currentDesktop)
                                            nextDesktopProcess.running = true
                                        else if (index + 1 < root.currentDesktop)
                                            previousDesktopProcess.running = true
                                        root.refreshDesktopState()
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: "#24ffffff"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 4

                        Repeater {
                            model: ToplevelManager.toplevels

                            Rectangle {
                                required property var modelData
                                readonly property var toplevel: modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38
                                radius: 12
                                color: toplevel.activated ? "#3d8ab4ff" : (taskMouse.containsMouse ? root.surfaceHover : "transparent")
                                visible: toplevel.appId !== "org.quickshell" && toplevel.title !== ""

                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        var name = toplevel.appId !== "" ? toplevel.appId : toplevel.title
                                        return name.length > 0 ? name.charAt(0).toUpperCase() : "?"
                                    }
                                    color: toplevel.activated ? root.textPrimary : root.textSecondary
                                    font.family: "Inter"
                                    font.bold: true
                                    font.pixelSize: 15
                                }

                                MouseArea {
                                    id: taskMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                    onClicked: function(mouse) {
                                        if (mouse.button === Qt.MiddleButton)
                                            toplevel.close()
                                        else
                                            toplevel.activate()
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: "#24ffffff"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: root.networkState === "connected" ? "⌁" : "×"
                            color: root.networkState === "connected" ? "#a6e3a1" : "#f38ba8"
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: 16
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.volumeMuted ? "×" : root.volumePercent + "%"
                            color: root.textSecondary
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: 10

                            MouseArea {
                                anchors.fill: parent
                                onClicked: muteProcess.running = true
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        text: Qt.formatDateTime(clock.date, "hh\nmm")
                        color: root.textPrimary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: "Inter"
                        font.bold: true
                        font.pixelSize: 13

                        SystemClock {
                            id: clock
                            precision: SystemClock.Minutes
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: 10
                        color: powerMouse.containsMouse ? "#4df38ba8" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "⏻"
                            color: "#f38ba8"
                            font.pixelSize: 17
                        }

                        MouseArea {
                            id: powerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.MiddleButton)
                                    shutdownProcess.running = true
                                else if (mouse.button === Qt.RightButton)
                                    rebootProcess.running = true
                                else
                                    logoutProcess.running = true
                            }
                        }
                    }
                }
            }
        }
    }
}
