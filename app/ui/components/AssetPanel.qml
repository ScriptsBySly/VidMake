import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

Panel {
    id: root
    title: "Assets"
    signal audioImported(string name, string path)
    signal visualImported(string name, string path)
    signal audioDeleted(string name, string path)
    signal visualDeleted(string name, string path)

    function fileNameFromUrl(fileUrl) {
        var path = localPathFromUrl(fileUrl)
        var slash = Math.max(path.lastIndexOf("/"), path.lastIndexOf("\\"))
        return slash >= 0 ? path.slice(slash + 1) : path
    }

    function localPathFromUrl(fileUrl) {
        var text = decodeURIComponent(fileUrl.toString())
        if (text.indexOf("file:///") === 0) {
            return text.slice(8)
        }
        if (text.indexOf("file://") === 0) {
            return text.slice(7)
        }
        return text
    }

    function addAsset(kind, icon, fileUrl) {
        var path = localPathFromUrl(fileUrl)
        var name = fileNameFromUrl(fileUrl)
        assetModel.append({ "name": name, "kind": kind, "icon": icon, "path": path })
        return { "name": name, "path": path }
    }

    function deleteAsset(index, kind, name, path) {
        assetModel.remove(index)
        if (kind === "Audio") {
            root.audioDeleted(name, path)
        } else if (kind === "Visual") {
            root.visualDeleted(name, path)
        }
    }

    FileDialog {
        id: audioDialog
        title: "Import audio"
        fileMode: FileDialog.OpenFile
        nameFilters: [
            "Audio files (*.wav *.mp3 *.flac *.aac *.m4a *.ogg)",
            "All files (*)"
        ]
        onAccepted: {
            var asset = root.addAsset("Audio", "\uE8D6", selectedFile)
            root.audioImported(asset.name, asset.path)
        }
    }

    FileDialog {
        id: visualDialog
        title: "Import visual"
        fileMode: FileDialog.OpenFile
        nameFilters: [
            "Visual files (*.png *.jpg *.jpeg *.webp *.gif *.mp4 *.mov *.mkv *.avi)",
            "All files (*)"
        ]
        onAccepted: {
            var asset = root.addAsset("Visual", "\uEB9F", selectedFile)
            root.visualImported(asset.name, asset.path)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 58
        anchors.bottomMargin: 16
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            PillButton {
                text: "Audio"
                iconText: "\uE8D6"
                Layout.fillWidth: true
                onClicked: audioDialog.open()
            }

            PillButton {
                text: "Visual"
                iconText: "\uEB9F"
                Layout.fillWidth: true
                onClicked: visualDialog.open()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 116
            radius: 8
            color: Theme.surfaceRaised
            border.color: Theme.stroke

            Column {
                anchors.centerIn: parent
                spacing: 9

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "\uE8B5"
                    color: Theme.accent
                    font.family: "Segoe MDL2 Assets"
                    font.pixelSize: 24
                }

                Text {
                    width: root.width - 64
                    horizontalAlignment: Text.AlignHCenter
                    text: "Drop media here"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }

                Text {
                    width: root.width - 64
                    horizontalAlignment: Text.AlignHCenter
                    text: "Audio, images, GIFs, and video"
                    color: Theme.subtleText
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
        }

        TextField {
            Layout.fillWidth: true
            placeholderText: "Search assets"
            leftPadding: 34
            color: Theme.text
            placeholderTextColor: Theme.mutedText
            font.family: Theme.fontFamily
            font.pixelSize: 13
            background: Rectangle {
                radius: 6
                color: Theme.input
                border.color: parent.activeFocus ? Theme.accent : Theme.stroke
            }

            Text {
                x: 11
                anchors.verticalCenter: parent.verticalCenter
                text: "\uE721"
                color: Theme.mutedText
                font.family: "Segoe MDL2 Assets"
                font.pixelSize: 13
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: assetModel
            visible: assetModel.count > 0

            delegate: Rectangle {
                required property string name
                required property string kind
                required property string icon
                required property string path
                required property int index
                readonly property bool isAudio: kind === "Audio"

                width: ListView.view.width
                height: 64
                radius: 8
                color: hover.hovered
                    ? (isAudio ? Theme.audioSurfaceHover : Theme.surfaceHover)
                    : (isAudio ? Theme.audioSurface : Theme.surfaceRaised)
                border.color: isAudio ? Theme.audioStroke : Theme.stroke

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 42
                        Layout.preferredHeight: 42
                        radius: 6
                        color: isAudio ? Theme.audioTile : Theme.tile

                        Text {
                            anchors.centerIn: parent
                            text: icon
                            color: isAudio ? Theme.audioAccent : Theme.accent
                            font.family: "Segoe MDL2 Assets"
                            font.pixelSize: 17
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: name
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: path.length > 0 ? path : kind
                            color: isAudio ? Theme.audioAccent : Theme.subtleText
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }

                    IconButton {
                        iconText: "\uE74D"
                        tooltip: "Delete asset"
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        onClicked: root.deleteAsset(index, kind, name, path)
                    }
                }

                HoverHandler {
                    id: hover
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: assetModel.count === 0
            radius: 8
            color: Theme.surfaceRaised
            border.color: Theme.stroke

            Text {
                anchors.centerIn: parent
                width: parent.width - 36
                text: "No assets imported"
                color: Theme.subtleText
                font.family: Theme.fontFamily
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
    }

    ListModel {
        id: assetModel
    }
}
