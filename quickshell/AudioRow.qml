import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire

Rectangle {
    id: row
    required property var node
    required property var audioCard
    property bool selected: false
    readonly property bool device: !node.isStream
    readonly property string displayName: node.nickname || node.properties["application.name"] || node.description || node.name
    implicitHeight: content.implicitHeight + 12
    radius: 9
    color: selected ? Theme.selection : rowHover.hovered && device ? Theme.hover : "transparent"
    Accessible.name: displayName

    MouseArea {
        id: rowHover
        anchors.fill: parent
        hoverEnabled: true
        enabled: row.device
        onClicked: row.audioCard.makeDefault(row.node)
    }

    
    ColumnLayout {
        id: content
        anchors { fill: parent; margins: 6 }
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ShellButton {
                iconName: row.node.audio.muted ? "volume-x" : "volume-2"
                iconOnly: true
                flat: true
                implicitWidth: 24
                implicitHeight: 24
                showToolTip: false
                Accessible.name: (row.node.audio.muted ? "Unmute " : "Mute ") + row.displayName
                onClicked: row.node.audio.muted = !row.node.audio.muted
            }

            Text {
                text: row.displayName
                color: row.selected ? Theme.selectedText : row.node.audio.muted ? Theme.muted : Theme.text
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: row.selected ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: row.device
                    onClicked: row.audioCard.makeDefault(row.node)
                }
            }

            Text {
                text: Math.round(row.node.audio.volume * 100) + "%"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 11
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
            implicitHeight: 14
            leftPadding: 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0
            enabled: row.node.ready
            Accessible.name: "Volume for " + row.displayName
            onMoved: row.node.audio.volume = slider.value

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
                    color: Theme.accent
                }
            }

            handle: Rectangle {
                x: slider.visualPosition * (slider.width - width)
                y: (slider.height - height) / 2
                width: 12
                height: 12
                radius: 6
                color: Theme.accent
            }
        }
    }
}
