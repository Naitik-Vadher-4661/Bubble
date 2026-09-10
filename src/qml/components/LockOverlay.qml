import QtQuick
import Bubble
import "../icons"

Item {
    id: root
    property bool isLocked: false
    property bool isSessionUnlocked: false
    property real badgeSize: 18

    width: badgeSize
    height: badgeSize
    visible: isLocked

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.isSessionUnlocked ? Theme.success : Theme.warning
        opacity: 0.95
        border.color: Theme.crust
        border.width: 1

        IconLock {
            anchors.centerIn: parent
            size: Math.round(root.badgeSize * 0.65)
            color: Theme.crust
            visible: !root.isSessionUnlocked
        }

        IconLockOpen {
            anchors.centerIn: parent
            size: Math.round(root.badgeSize * 0.65)
            color: Theme.crust
            visible: root.isSessionUnlocked
        }
    }
}
