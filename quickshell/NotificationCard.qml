pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

Rectangle {
    id: card
    required property var notification

    property string appName: ""
    property string summary: ""
    property string body: ""
    property string image: ""
    property string appIcon: ""
    property real expireTimeout: 0
    property bool critical: false
    property real progress: -1
    property var buttonActions: []
    property var defaultAction: null
    readonly property bool hovered: hover.hovered

    function refresh() {
        const n = card.notification;
        if (!n) return;
        card.appName = n.appName;
        card.summary = n.summary;
        card.body = n.body;
        card.image = n.image;
        card.expireTimeout = n.expireTimeout;
        card.critical = n.urgency === NotificationUrgency.Critical;

        const icon = n.appIcon;
        if (icon === "") card.appIcon = "";
        else if (icon.startsWith("/") || icon.startsWith("file:")) card.appIcon = icon;
        else card.appIcon = Quickshell.iconPath(icon, "");

        const value = n.hints ? n.hints.value : undefined;
        card.progress = typeof value === "number" ? Math.max(0, Math.min(1, value / 100)) : -1;

        const buttons = [];
        let def = null;
        const actions = n.actions || [];
        for (let i = 0; i < actions.length; i++) {
            if (actions[i].identifier === "default") def = actions[i];
            else buttons.push(actions[i]);
        }
        card.defaultAction = def;
        card.buttonActions = buttons;
    }

    function dismiss() {
        if (card.notification) card.notification.dismiss();
    }

    function invokeAction(action) {
        if (card.notification && action) action.invoke();
    }

    implicitHeight: content.implicitHeight + 24
    radius: 12
    color: Theme.surface

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        enabled: card.defaultAction !== null
        cursorShape: card.defaultAction !== null ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: card.invokeAction(card.defaultAction)
    }

    Component.onCompleted: card.refresh()

    Connections {
        target: card.notification
        function onAppNameChanged() { card.refresh(); }
        function onSummaryChanged() { card.refresh(); }
        function onBodyChanged() { card.refresh(); }
        function onImageChanged() { card.refresh(); }
        function onAppIconChanged() { card.refresh(); }
        function onExpireTimeoutChanged() { card.refresh(); }
        function onUrgencyChanged() { card.refresh(); }
        function onActionsChanged() { card.refresh(); }
        function onHintsChanged() { card.refresh(); }
    }

    ColumnLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
                implicitWidth: 24
                implicitHeight: 24
                radius: 6
                color: card.appIcon !== "" ? "transparent" : Theme.hover
                Image {
                    anchors.fill: parent
                    visible: card.appIcon !== ""
                    source: card.appIcon
                    fillMode: Image.PreserveAspectFit
                }
                Text {
                    anchors.centerIn: parent
                    visible: card.appIcon === ""
                    text: card.appName !== "" ? card.appName.charAt(0).toUpperCase() : "?"
                    color: Theme.muted
                    font.pixelSize: 12
                    font.family: Theme.font
                    font.weight: Font.DemiBold
                }
            }
            Text {
                text: card.appName
                color: Theme.muted
                font.pixelSize: 11
                font.family: Theme.font
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
                onClicked: card.dismiss()
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: card.summary
                    textFormat: Text.PlainText
                    color: Theme.text
                    font.pixelSize: 13
                    font.family: Theme.font
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: card.body
                    textFormat: Text.PlainText
                    visible: text !== ""
                    color: Theme.muted
                    font.pixelSize: 12
                    font.family: Theme.font
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Rectangle {
                    visible: card.progress >= 0
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    implicitHeight: 4
                    radius: 2
                    color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.16)
                    Rectangle {
                        width: parent.width * Math.max(0, card.progress)
                        height: parent.height
                        radius: parent.radius
                        color: Theme.accent
                        Behavior on width {
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
            Rectangle {
                visible: card.image !== ""
                Layout.alignment: Qt.AlignTop
                implicitWidth: 44
                implicitHeight: 44
                radius: 8
                clip: true
                color: Theme.hover
                Image {
                    anchors.fill: parent
                    source: card.image
                    fillMode: Image.PreserveAspectCrop
                }
            }
        }
        Flow {
            visible: actionRepeater.count > 0
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                id: actionRepeater
                model: card.buttonActions
                ShellButton {
                    required property var modelData
                    label: modelData.text
                    onClicked: card.invokeAction(modelData)
                }
            }
        }
    }
}
