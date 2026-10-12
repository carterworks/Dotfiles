// Isolated preview entry point for iterating on the audio panel.
//
// Run with:
//   quickshell -p ~/.config/quickshell/dev.qml
//
// Quickshell's config discovery only treats `shell.qml` (and named
// subdirectories) as configurations, so this file is inert during normal
// sessions. It is a separate Quickshell process, which means it can be killed,
// relaunched and screenshotted without disturbing the live sidebar service.
// Living beside the other components lets it resolve Theme, DesktopColors and
// the cards through the same implicit directory import `shell.qml` uses.
//
// The one-pixel anchor surface is development scaffolding: Quickshell does not
// map a config whose only surface is the fullscreen audio overlay, so this
// keeps a second overlay present. It is transparent and does not cover
// anything.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    PanelWindow {
        anchors { top: true; left: true }
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "miasma-audio-dev-anchor"
    }

    AudioPanel { id: audio }

    // Mimic the real user toggle rather than mapping the overlay at startup.
    Timer {
        interval: 800
        running: true
        onTriggered: audio.open = true
    }
}
