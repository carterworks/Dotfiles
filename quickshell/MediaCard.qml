import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

Rectangle {
    id: card
    readonly property var player: {
        const players = Mpris.players.values;
        return players.find(p => p.playbackState === MprisPlaybackState.Playing) || players[0] || null;
    }
    visible: player !== null
    implicitHeight: visible ? content.implicitHeight + 24 : 0
    radius: 12
    color: Theme.surface

    ColumnLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 6
        Text {
            text: card.player ? card.player.trackTitle || "Nothing playing" : ""
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Text {
            text: card.player ? card.player.trackArtist || card.player.identity : ""
            color: Theme.muted
            font.pixelSize: 11
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        RowLayout {
            Layout.fillWidth: true
            ShellButton {
                label: "Previous"
                iconName: "skip-back"
                iconOnly: true
                enabled: card.player && card.player.canGoPrevious
                Layout.fillWidth: true
                onClicked: card.player.previous()
            }
            ShellButton {
                label: card.player && card.player.playbackState === MprisPlaybackState.Playing ? "Pause" : "Play"
                iconName: card.player && card.player.playbackState === MprisPlaybackState.Playing ? "pause" : "play"
                iconOnly: true
                enabled: card.player && card.player.canTogglePlaying
                Layout.fillWidth: true
                onClicked: card.player.togglePlaying()
            }
            ShellButton {
                label: "Next"
                iconName: "skip-forward"
                iconOnly: true
                enabled: card.player && card.player.canGoNext
                Layout.fillWidth: true
                onClicked: card.player.next()
            }
        }
    }
}
