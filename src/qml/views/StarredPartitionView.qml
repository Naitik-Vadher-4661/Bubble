import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Bubble
import Quill as Q

Rectangle {
    id: root
    clip: true
    color: Theme.containerColor(Theme.crust, 0.20)
    radius: Theme.radiusMedium

    signal fileActivated(string filePath, bool isDirectory)
    signal openFolderRequested(string folderPath)
    signal contextMenuRequested(string filePath, bool isDirectory, point position)

    readonly property color accentStarColor: "#e5c890" // Catppuccin warm gold / star accent

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: Theme.containerColor(Theme.mantle, 0.4)
            border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                IconStar {
                    size: 16
                    color: root.accentStarColor
                }

                Text {
                    text: "Starred"
                    font.bold: true
                    font.pointSize: Theme.fontNormal
                    color: Theme.text
                }

                Rectangle {
                    implicitWidth: countText.implicitWidth + 12
                    implicitHeight: 18
                    radius: 9
                    color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.10)

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: String(starredModel ? starredModel.count : 0)
                        font.pointSize: Theme.fontSmall - 1
                        font.bold: true
                        color: Theme.subtext
                    }
                }

                Item { Layout.fillWidth: true }

                // Clean missing button
                Rectangle {
                    visible: starredModel ? starredModel.hasMissing : false
                    implicitWidth: cleanMissingText.implicitWidth + 14
                    implicitHeight: 24
                    radius: Theme.radiusSmall
                    color: cleanMissingHover.containsMouse
                        ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.25)
                        : Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
                    border.color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.3)
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            id: cleanMissingText
                            text: "Clean Missing"
                            font.pointSize: Theme.fontSmall - 1
                            font.bold: true
                            color: Theme.error
                        }
                    }

                    MouseArea {
                        id: cleanMissingHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (starredModel)
                                starredModel.clearMissing()
                        }
                    }
                }
            }
        }

        // Main content area with drop zone
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Empty state placeholder
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12
                visible: starredModel ? starredModel.count === 0 : true
                width: Math.min(parent.width - 32, 280)

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 56
                    height: 56
                    radius: 28
                    color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.05)

                    IconStar {
                        anchors.centerIn: parent
                        size: 28
                        color: root.accentStarColor
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No starred items"
                    font.bold: true
                    font.pointSize: Theme.fontNormal
                    color: Theme.text
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: "Right-click any file or folder to Star it, or drag and drop items here for instant access."
                    font.pointSize: Theme.fontSmall
                    color: Theme.muted
                    lineHeight: 1.2
                }
            }

            // Grid of Starred cards
            GridView {
                id: starredGrid
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                visible: starredModel ? starredModel.count > 0 : false
                model: starredModel

                readonly property int minColWidth: 150
                readonly property int cols: Math.max(1, Math.floor(width / minColWidth))
                cellWidth: Math.floor(width / cols)
                cellHeight: 110

                delegate: Item {
                    id: cardItem
                    width: starredGrid.cellWidth
                    height: starredGrid.cellHeight

                    readonly property bool isMissing: !model.exists
                    readonly property bool isFolder: model.isDir

                    Rectangle {
                        id: cardBg
                        anchors.fill: parent
                        anchors.margins: 5
                        radius: Theme.radiusMedium
                        color: {
                            if (cardHover.containsMouse)
                                return Theme.containerColor(Theme.surface, 0.35)
                            return Theme.containerColor(Theme.surface, 0.16)
                        }
                        border.width: 1
                        border.color: {
                            if (cardHover.containsMouse)
                                return Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.4)
                            return Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
                        }
                        opacity: isMissing ? 0.5 : 1.0

                        Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.animDurationFast } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            // Icon or thumbnail
                            Item {
                                Layout.preferredWidth: 52
                                Layout.preferredHeight: 52
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.radiusSmall
                                    color: Qt.rgba(Theme.crust.r, Theme.crust.g, Theme.crust.b, 0.3)
                                }

                                Image {
                                    id: thumbImage
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    asynchronous: true
                                    fillMode: Image.PreserveAspectFit
                                    sourceSize: Qt.size(64, 64)
                                    visible: model.hasImagePreview && status === Image.Ready
                                    source: model.hasImagePreview ? ("image://thumbnail/" + model.filePath) : ""
                                }

                                Image {
                                    anchors.centerIn: parent
                                    width: 36
                                    height: 36
                                    sourceSize: Qt.size(36, 36)
                                    fillMode: Image.PreserveAspectFit
                                    visible: !thumbImage.visible
                                    source: "image://icon/" + (model.fileIconName || "text-x-generic") + "?theme=" + config.iconTheme
                                }
                            }

                            // Text metadata
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: model.fileName || ""
                                    font.bold: true
                                    font.pointSize: Theme.fontNormal
                                    color: isMissing ? Theme.error : Theme.text
                                    elide: Text.ElideMiddle
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: isMissing ? "File missing / deleted" : (model.fileSizeText || model.fileType || "")
                                    font.pointSize: Theme.fontSmall - 1
                                    color: isMissing ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.8) : Theme.muted
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: model.filePath || ""
                                    font.pointSize: Theme.fontSmall - 2
                                    color: Theme.subtext
                                    opacity: 0.6
                                    elide: Text.ElideMiddle
                                }
                            }

                            // Star / Unstar button
                            Rectangle {
                                id: starBtn
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                radius: 13
                                color: starBtnHover.containsMouse
                                    ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.2)
                                    : (cardHover.containsMouse ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08) : "transparent")

                                IconStar {
                                    anchors.centerIn: parent
                                    size: 15
                                    color: starBtnHover.containsMouse ? Theme.error : root.accentStarColor
                                }

                                MouseArea {
                                    id: starBtnHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    ToolTip.visible: containsMouse
                                    ToolTip.text: "Remove from Starred"
                                    ToolTip.delay: 300
                                    onClicked: {
                                        if (starredModel)
                                            starredModel.unstarPath(model.filePath)
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: cardHover
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            z: -1

                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    var pos = cardHover.mapToItem(root, mouse.x, mouse.y)
                                    root.contextMenuRequested(model.filePath, model.isDir, pos)
                                } else {
                                    if (model.isDir) {
                                        root.openFolderRequested(model.filePath)
                                    } else {
                                        root.fileActivated(model.filePath, false)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Drag and drop overlay
            DropArea {
                id: dropTarget
                anchors.fill: parent

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: Theme.radiusMedium
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
                    border.color: Theme.accent
                    border.width: 2
                    visible: dropTarget.containsDrag

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        IconStar {
                            Layout.alignment: Qt.AlignHCenter
                            size: 32
                            color: Theme.accent
                        }

                        Text {
                            text: "Drop to Star item"
                            font.bold: true
                            font.pointSize: Theme.fontNormal
                            color: Theme.accent
                        }
                    }
                }

                function decodedPath(urlStr) {
                    var s = String(urlStr)
                    if (s.indexOf("file://") === 0)
                        s = s.substring(7)
                    return decodeURIComponent(s)
                }

                function dragUrls(dragEvent) {
                    if (dragEvent.hasUrls && dragEvent.urls.length > 0)
                        return dragEvent.urls
                    if (dragEvent.getDataAsString) {
                        var text = dragEvent.getDataAsString("text/uri-list")
                        if (text && text.length > 0) {
                            var lines = text.split("\n")
                            var urls = []
                            for (var i = 0; i < lines.length; ++i) {
                                var line = lines[i].trim()
                                if (line.length > 0 && line.indexOf("#") !== 0)
                                    urls.push(line)
                            }
                            return urls
                        }
                    }
                    return []
                }

                onDropped: (drop) => {
                    var urls = dragUrls(drop)
                    if (urls.length > 0 && starredModel) {
                        for (var i = 0; i < urls.length; ++i) {
                            var path = decodedPath(urls[i])
                            if (path && path.length > 0)
                                starredModel.starPath(path)
                        }
                        drop.accept()
                    }
                }
            }
        }
    }
}
