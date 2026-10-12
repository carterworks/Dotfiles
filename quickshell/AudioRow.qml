pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire

// One controllable audio node: a physical sink/source or an application stream.
//
// Devices are selectable (clicking the row makes them the default); streams are
// not. The whole row responds to the scroll wheel, which adjusts volume and
// unmutes on an upward scroll so a muted row cannot trap the user at 0%.
Rectangle {
    id: row
    // Emitted when a selectable device row is clicked.
    signal activated()
    required property var node
    // Devices can be made the default; application streams cannot.
    property bool selectable: false
    property bool selected: false
    readonly property string title: row.node.nickname
        || row.node.properties["application.name"]
        || row.node.description
        || row.node.name
        || "Unknown"
    readonly property string subtitle: row.node.isStream
        ? (row.node.properties["media.name"] || "")
        : ""
    readonly property bool muted: row.node.audio.muted
    readonly property bool interactive: row.node.ready

    implicitHeight: content.implicitHeight + 12
    radius: 9
    color: row.selected ? Theme.selection
        : hover.hovered ? Theme.hover
        : "transparent"
    Accessible.name: (row.muted ? "Unmute " : "Mute ") + row.title
    Accessible.role: Accessible.ListItem

    function nudge(delta) {
        if (!row.interactive) return;
        if (row.muted && delta > 0) row.node.audio.muted = false;
        row.node.audio.volume = Math.max(0, Math.min(1, row.node.audio.volume + delta));
    }

    // Under the content so controls receive clicks first.
    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        enabled: row.selectable
        cursorShape: row.selectable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: row.activated()
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            row.nudge(event.angleDelta.y > 0 ? 0.05 : -0.05);
            event.accepted = true;
        }
    }

    ColumnLayout {
        id: content
        anchors { fill: parent; margins: 6 }
        spacing: 1

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ShellButton {
                iconName: row.muted ? "volume-x" : "volume-2"
                iconOnly: true
                flat: true
                implicitWidth: 22
                implicitHeight: 22
                showToolTip: false
                enabled: row.interactive
                Accessible.name: (row.muted ? "Unmute " : "Mute ") + row.title
                onClicked: row.node.audio.muted = !row.node.audio.muted
            }

            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true

                Text {
                    text: row.title
                    color: row.selected ? Theme.selectedText
                        : row.muted ? Theme.muted
                        : Theme.text
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.weight: row.selected ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                }

                Text {
                    visible: row.subtitle !== ""
                    text: row.subtitle
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                }
            }

            Text {
                text: Math.round(row.node.audio.volume * 100) + "%"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 11
                Layout.alignment: Qt.AlignTop
            }
        }

        Slider {
            id: slider
            Layout.fillWidth: true
            from: 0
            to: 1
            stepSize: 0.01
            // Zero padding plus the custom background/handle leaves the Basic
            // style implicit height at 0, which collapses the row.
            implicitHeight: 16
            leftPadding: 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0
            enabled: row.interactive
            Accessible.name: "Volume for " + row.title
            onMoved: row.node.audio.volume = slider.value

            // Mirror PipeWire while idle; step aside while the user drags.
            Binding {
                target: slider
                property: "value"
                value: row.node.audio.volume
                when: !slider.pressed && row.node.ready
            }

            background: Rectangle {
                x: 0
                y: (slider.height - height) / 2
                width: slider.width
                height: 4
                radius: 2
                color: Theme.border

                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: row.muted || !row.interactive ? Theme.muted : Theme.accent
                }
            }

            handle: Rectangle {
                x: slider.visualPosition * (slider.width - width)
                y: (slider.height - height) / 2
                width: 12
                height: 12
                radius: 6
                color: row.muted || !row.interactive ? Theme.muted : Theme.accent
            }
        }
    }
}
