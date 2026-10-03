import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

AbstractButton {
    id: button
    property string label: ""
    property string iconName: ""
    property url iconSource: iconName ? Qt.resolvedUrl("icons/" + iconName + ".svg") : ""
    property bool selected: false
    property bool flat: false
    property bool iconOnly: false
    implicitWidth: contentItem.implicitWidth + 20
    implicitHeight: 38
    hoverEnabled: true
    Accessible.name: label

    background: Rectangle {
        radius: 9
        color: button.selected ? Theme.hover : button.hovered ? Theme.hover : button.flat ? "transparent" : Theme.surface
        opacity: button.enabled ? 1 : 0.4
    }

    contentItem: RowLayout {
        spacing: 8
        Image {
            visible: button.iconSource.toString() !== ""
            source: button.iconSource
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: button.iconOnly
            fillMode: Image.PreserveAspectFit
        }
        Text {
            visible: !button.iconOnly
            text: button.label
            color: button.selected ? Theme.accent : Theme.text
            font.family: Theme.font
            font.pixelSize: 12
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
    leftPadding: iconOnly ? 5 : 10
    rightPadding: iconOnly ? 5 : 10
    ToolTip.visible: hovered && iconOnly
    ToolTip.text: label
}
