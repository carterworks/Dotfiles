import QtQuick
import QtQuick.Controls

ToolTip {
    id: tooltip
    delay: 500
    padding: 10
    implicitWidth: Math.min(implicitContentWidth + leftPadding + rightPadding, Theme.sidebarWidth - 28)

    contentItem: Text {
        text: tooltip.text
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 12
        wrapMode: Text.Wrap
    }

    background: Rectangle {
        color: Theme.surface
        radius: 9
        border.color: Theme.border
        border.width: 1
    }
}
