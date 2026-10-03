import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire

Rectangle {
    id: card
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null
    implicitHeight: controls.implicitHeight + 20
    color: Theme.surface
    radius: 12

    PwObjectTracker { objects: card.sink ? [card.sink] : [] }

    ColumnLayout {
        id: controls
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
        spacing: 4
        RowLayout {
            ShellButton {
                label: card.audio && card.audio.muted ? "Muted" : "Volume"
                iconName: card.audio && card.audio.muted ? "volume-x" : "volume-2"
                enabled: card.audio !== null
                Layout.fillWidth: true
                onClicked: card.audio.muted = !card.audio.muted
            }
            Text {
                text: card.audio ? Math.round(card.audio.volume * 100) + "%" : "—"
                color: Theme.muted
                font.pixelSize: 12
            }
        }
        Slider {
            Layout.fillWidth: true
            from: 0
            to: 1
            enabled: card.audio !== null
            value: card.audio ? card.audio.volume : 0
            onMoved: card.audio.volume = value
            Accessible.name: "Output volume"
        }
    }
}
