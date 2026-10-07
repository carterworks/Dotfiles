pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland

PanelWindow {
    id: popover
    property bool open: false
    readonly property var sinks: Pipewire.nodes.values.filter(n => !n.isStream && n.isSink && n.audio)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isStream && !n.isSink && n.audio)
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.audio)

    visible: open
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "miasma-audio"
    WlrLayershell.layer: WlrLayer.Overlay
    color: "transparent"

    function makeDefault(node) {
        if (node.type === PwNodeType.AudioSink) {
            Pipewire.preferredDefaultAudioSink = node;
        } else {
            Pipewire.preferredDefaultAudioSource = node;
        }
    }

    PwObjectTracker { objects: [...popover.sinks, ...popover.sources, ...popover.streams] }

    MouseArea {
        anchors.fill: parent
        onClicked: popover.open = false
    }

    Rectangle {
        id: card
        anchors { left: parent.left; top: parent.top; margins: { left: Theme.sidebarWidth + 12; top: 52 } }
        width: 300
        height: Math.min(scroller.contentHeight, 460)
        radius: 12
        color: Theme.surface
        border { width: 1; color: Theme.border }

        MouseArea { anchors.fill: parent }

        ScrollView {
            id: scroller
            anchors { fill: parent; margins: 12 }
            contentWidth: availableWidth
            contentHeight: content.implicitHeight
            clip: true

            ColumnLayout {
                id: content
                width: scroller.availableWidth
                spacing: 2

                Text {
                    text: "Output"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 11
                    Layout.bottomMargin: 2
                }

                Repeater {
                    model: popover.sinks
                    AudioRow {
                        required property var modelData
                        node: modelData
                        audioCard: popover
                        selected: modelData.id === Pipewire.defaultAudioSink?.id
                    }
                }

                Text {
                    text: "Input"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 11
                    Layout.topMargin: 10
                    Layout.bottomMargin: 2
                }

                Repeater {
                    model: popover.sources
                    AudioRow {
                        required property var modelData
                        node: modelData
                        audioCard: popover
                        selected: modelData.id === Pipewire.defaultAudioSource?.id
                    }
                }

                Text {
                    text: "Applications"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 11
                    visible: popover.streams.length > 0
                    Layout.topMargin: 10
                    Layout.bottomMargin: 2
                }

                Repeater {
                    model: popover.streams
                    AudioRow {
                        required property var modelData
                        node: modelData
                        audioCard: popover
                    }
                }
            }
        }
    }
}
