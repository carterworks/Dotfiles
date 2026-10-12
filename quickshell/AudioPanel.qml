pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland

// Sidebar audio popover.
//
// A plain fullscreen overlay closes on any outside click; the card inside sits
// just to the right of the sidebar. It covers the common cases: choosing the
// default output/input, per-device and per-application volume and mute. Port
// and profile selection are deliberately out of scope because Quickshell's
// PipeWire service does not expose them; use wpctl for those.
PanelWindow {
    id: panel
    property bool open: false
    readonly property var sinks: Pipewire.nodes.values.filter(n => !n.isStream && n.isSink && n.audio)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isStream && !n.isSink && n.audio)
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.audio)

    visible: open
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "miasma-audio"
    WlrLayershell.layer: WlrLayer.Overlay
    // Only grabs the keyboard while the user is interacting with the panel,
    // which lets Escape close it without stealing focus otherwise.
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: "transparent"

    function toggle() {
        open = !open;
    }

    function makeDefault(node) {
        if (node.isStream) return;
        if (node.isSink) Pipewire.preferredDefaultAudioSink = node;
        else Pipewire.preferredDefaultAudioSource = node;
    }

    // Keep properties flowing for every node on screen.
    PwObjectTracker { objects: [...panel.sinks, ...panel.sources, ...panel.streams] }

    Shortcut {
        sequence: "Escape"
        enabled: panel.open
        onActivated: panel.open = false
    }

    MouseArea {
        anchors.fill: parent
        onClicked: panel.open = false
    }

    Rectangle {
        id: card
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: Theme.sidebarWidth + 12
        anchors.topMargin: 52
        width: 320
        height: Math.min(content.implicitHeight + 24, 460)
        radius: 12
        color: Theme.surface
        border { width: 1; color: Theme.border }
        clip: true

        // Swallow clicks so hitting the card does not dismiss the popover.
        MouseArea { anchors.fill: parent }

        ScrollView {
            id: scroller
            anchors { fill: parent; margins: 12 }
            contentWidth: availableWidth
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                id: content
                width: scroller.availableWidth
                spacing: 2

                component SectionLabel: Text {
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    Layout.bottomMargin: 2
                }

                Text {
                    visible: panel.sinks.length + panel.sources.length + panel.streams.length === 0
                    text: "No audio devices found."
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                }

                SectionLabel { visible: panel.sinks.length > 0; text: "Output" }
                Repeater {
                    model: panel.sinks
                    AudioRow {
                        required property var modelData
                        Layout.fillWidth: true
                        node: modelData
                        selectable: true
                        selected: modelData.id === Pipewire.defaultAudioSink?.id
                        onActivated: panel.makeDefault(modelData)
                    }
                }

                SectionLabel { visible: panel.sources.length > 0; text: "Input" }
                Repeater {
                    model: panel.sources
                    AudioRow {
                        required property var modelData
                        Layout.fillWidth: true
                        node: modelData
                        selectable: true
                        selected: modelData.id === Pipewire.defaultAudioSource?.id
                        onActivated: panel.makeDefault(modelData)
                    }
                }

                SectionLabel { visible: panel.streams.length > 0; text: "Applications" }
                Repeater {
                    model: panel.streams
                    AudioRow {
                        required property var modelData
                        Layout.fillWidth: true
                        node: modelData
                    }
                }
            }
        }
    }
}
