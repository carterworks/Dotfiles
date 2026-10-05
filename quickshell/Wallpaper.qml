import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "miasma-wallpaper"
    color: Theme.background

    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("wallpaper.jpg")
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
}
