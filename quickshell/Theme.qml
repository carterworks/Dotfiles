pragma Singleton
import QtQuick

QtObject {
    readonly property int sidebarWidth: 250
    readonly property color background: DesktopColors.background
    readonly property color surface: DesktopColors.surface
    readonly property color hover: DesktopColors.hover
    readonly property color hoverText: DesktopColors.hoverText
    readonly property color selection: DesktopColors.selection
    readonly property color selectedText: DesktopColors.selectedText
    readonly property color pressed: DesktopColors.pressed
    readonly property color focus: DesktopColors.focus
    readonly property color accent: DesktopColors.accent
    readonly property color text: DesktopColors.text
    readonly property color muted: DesktopColors.muted
    readonly property color border: DesktopColors.border
    readonly property string font: "Inter"
}
