import QtQuick
import QtQuick.Layouts

Rectangle {
    id: card
    required property var notification
    implicitHeight: content.implicitHeight + 24
    radius: 12
    color: Theme.surface

    ColumnLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: card.notification.appName
                color: Theme.muted
                font.pixelSize: 11
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            ShellButton {
                label: "×"
                iconName: "x"
                iconOnly: true
                implicitWidth: 28
                implicitHeight: 26
                Accessible.name: "Dismiss notification"
                onClicked: card.notification.dismiss()
            }
        }
        Text {
            text: card.notification.summary
            textFormat: Text.PlainText
            color: Theme.text
            font.pixelSize: 13
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Text {
            text: card.notification.body
            textFormat: Text.PlainText
            visible: text !== ""
            color: Theme.muted
            font.pixelSize: 12
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Flow {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: card.notification.actions
                ShellButton {
                    required property var modelData
                    label: modelData.text
                    onClicked: modelData.invoke()
                }
            }
        }
    }
}
