pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: popups
    required property var notificationServer
    property var shownIds: []
    readonly property var shown: notificationServer.trackedNotifications.values.filter(n => shownIds.includes(n.id))
    property var hoveredIds: ({})
    property bool active: false
    property int previousCount: 0
    property real heldHeight: 0

    visible: active
    anchors { top: true; right: true }
    margins { top: 16; right: 16 }
    implicitWidth: 340
    implicitHeight: holdTimer.running ? Math.max(heldHeight, stack.contentHeight) : stack.contentHeight
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "miasma-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    color: "transparent"

    function show(notification) {
        if (shownIds.includes(notification.id)) return;
        shownIds = [...shownIds, notification.id].slice(-3);
    }

    function setHovered(id, value) {
        const next = Object.assign({}, hoveredIds);
        if (value) next[id] = true;
        else delete next[id];
        hoveredIds = next;
    }

    function isHovered(id) {
        return hoveredIds[id] === true;
    }

    function syncStack() {
        if (!popupModel) return;
        const wanted = popups.shown;
        for (let i = popupModel.count - 1; i >= 0; i--) {
            const row = popupModel.get(i);
            if (!row || !row.entry) {
                popupModel.remove(i);
                continue;
            }
            if (!wanted.some(n => n.id === row.entry.id)) popupModel.remove(i);
        }
        for (let i = 0; i < wanted.length; i++) {
            const n = wanted[i];
            let found = false;
            for (let j = 0; j < popupModel.count; j++) {
                const row = popupModel.get(j);
                if (row && row.entry && row.entry.id === n.id) {
                    found = true;
                    break;
                }
            }
            if (!found) popupModel.append({ entry: n });
        }
    }

    onShownChanged: {
        if (!popupModel || !holdTimer) return;
        syncStack();
        if (popupModel.count > previousCount) {
            active = true;
            holdTimer.stop();
            heldHeight = Math.max(heldHeight, stack.contentHeight);
        } else if (popupModel.count < previousCount) {
            holdTimer.restart();
        }
        previousCount = popupModel.count;
    }

    ListModel { id: popupModel }

    Timer {
        id: holdTimer
        interval: 170
        onTriggered: {
            popups.active = popups.shown.length > 0;
            popups.heldHeight = stack.contentHeight;
        }
    }

    Connections {
        target: popups.notificationServer
        function onNotification(notification) {
            if (!notification.lastGeneration) popups.show(notification);
        }
    }

    Variants {
        model: popups.notificationServer.trackedNotifications.values
        delegate: Component {
            QtObject {
                id: watcher
                required property var modelData
                property Connections updates: Connections {
                    target: watcher.modelData
                    function onSummaryChanged() { popups.show(watcher.modelData); }
                    function onBodyChanged() { popups.show(watcher.modelData); }
                    function onExpireTimeoutChanged() { popups.show(watcher.modelData); }
                }
            }
        }
    }

    ListView {
        id: stack
        width: parent.width
        height: Math.max(parent.height, contentHeight)
        interactive: false
        spacing: 8
        clip: false
        model: popupModel
        onContentHeightChanged: if (stack.contentHeight > popups.heldHeight) popups.heldHeight = stack.contentHeight

        delegate: NotificationCard {
            id: toast
            required property var entry
            notification: entry
            readonly property int notificationId: toast.notification ? toast.notification.id : -1
            width: stack.width
            opacity: 0
            scale: 0.98

            // Quickshell reports the freedesktop timeout in milliseconds despite documenting seconds.
            property double remainingMs: toast.expireTimeout > 0 ? toast.expireTimeout : 6000
            property double resumedAt: 0
            readonly property bool counting: toast.expireTimeout !== 0 && !toast.critical

            function startCountdown() {
                if (!toast.counting) return;
                if (toast.remainingMs <= 0) {
                    popups.shownIds = popups.shownIds.filter(id => id !== toast.notificationId);
                    return;
                }
                expiry.interval = toast.remainingMs;
                expiry.restart();
                toast.resumedAt = Date.now();
            }

            function pauseCountdown() {
                if (!expiry.running) return;
                expiry.stop();
                toast.remainingMs = Math.max(0, toast.remainingMs - (Date.now() - toast.resumedAt));
            }

            function resetCountdown() {
                toast.remainingMs = toast.expireTimeout > 0 ? toast.expireTimeout : 6000;
                expiry.stop();
                if (toast.counting && !toast.hovered) toast.startCountdown();
            }

            NumberAnimation {
                id: enterOpacity
                target: toast
                property: "opacity"
                to: 1
                duration: 180
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                id: enterScale
                target: toast
                property: "scale"
                to: 1
                duration: 280
                easing.type: Easing.OutQuint
            }

            onHoveredChanged: {
                if (!popups) return;
                popups.setHovered(toast.notificationId, toast.hovered);
                if (toast.hovered) toast.pauseCountdown();
                else toast.startCountdown();
            }
            Component.onCompleted: {
                toast.refresh();
                toast.startCountdown();
                enterOpacity.start();
                enterScale.start();
            }
            Component.onDestruction: if (popups) popups.setHovered(toast.notificationId, false)

            Connections {
                target: toast.notification
                function onSummaryChanged() { toast.resetCountdown(); }
                function onBodyChanged() { toast.resetCountdown(); }
                function onExpireTimeoutChanged() { toast.resetCountdown(); }
            }

            Timer {
                id: expiry
                running: false
                onTriggered: popups.shownIds = popups.shownIds.filter(id => id !== toast.notificationId)
            }
        }

        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: 140; easing.type: Easing.OutQuad }
            NumberAnimation { property: "scale"; to: 0.98; duration: 140; easing.type: Easing.OutQuad }
        }
        displaced: Transition {
            NumberAnimation { property: "y"; duration: 220; easing.type: Easing.OutCubic }
        }
    }
}
