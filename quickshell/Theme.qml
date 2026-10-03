pragma Singleton
import QtQuick

QtObject {
    readonly property int sidebarWidth: 250
    readonly property color background: DesktopColors.background
    readonly property color surface: DesktopColors.surface
    readonly property color hover: DesktopColors.hover
    readonly property color accent: DesktopColors.accent
    readonly property color text: DesktopColors.text
    readonly property color muted: DesktopColors.muted
    readonly property string font: "Inter"
}
