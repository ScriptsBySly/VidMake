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
    signal assetSelected(string name, string kind, string path)
    property int selectedIndex: -1

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
        selectedIndex = assetModel.count - 1
        root.assetSelected(name, kind, path)
        return { "name": name, "path": path }
    }

    function extensionFromName(name) {
        var dot = name.lastIndexOf(".")
        return dot >= 0 ? name.slice(dot + 1).toLowerCase() : ""
    }

    function kindForFile(fileUrl) {
        var extension = extensionFromName(fileNameFromUrl(fileUrl))
        var audioExtensions = ["wav", "mp3", "flac", "aac", "m4a", "ogg"]
        var visualExtensions = ["png", "jpg", "jpeg", "webp", "gif", "mp4", "mov", "mkv", "avi"]

        if (audioExtensions.indexOf(extension) >= 0) {
            return "Audio"
        }
        if (visualExtensions.indexOf(extension) >= 0) {
            return "Visual"
        }
        return ""
    }

    function importFile(fileUrl) {
        var kind = kindForFile(fileUrl)
        if (kind === "Audio") {
            var audioAsset = root.addAsset("Audio", "\uE8D6", fileUrl)
            root.audioImported(audioAsset.name, audioAsset.path)
            return true
        }
        if (kind === "Visual") {
            var visualAsset = root.addAsset("Visual", "\uEB9F", fileUrl)
            root.visualImported(visualAsset.name, visualAsset.path)
            return true
        }
        return false
    }

    function hasImportableFiles(urls) {
        for (var i = 0; i < urls.length; i++) {
            if (kindForFile(urls[i]).length > 0) {
                return true
            }
        }
        return false
    }

    function importFiles(urls) {
        var imported = 0
        for (var i = 0; i < urls.length; i++) {
            if (importFile(urls[i])) {
                imported += 1
            }
        }
        return imported
    }

    function deleteAsset(index, kind, name, path) {
        assetModel.remove(index)
        if (selectedIndex === index) {
            selectedIndex = -1
            root.assetSelected("", "", "")
        } else if (selectedIndex > index) {
            selectedIndex -= 1
        }
        if (kind === "Audio") {
            root.audioDeleted(name, path)
        } else if (kind === "Visual") {
            root.visualDeleted(name, path)
        }
    }

    function deleteAssetByPath(path) {
        var index = assetIndexForPath(path)
        if (index < 0) {
            return false
        }
        var asset = assetModel.get(index)
        deleteAsset(index, asset.kind, asset.name, asset.path)
        return true
    }

    function iconForKind(kind) {
        return kind === "Audio" ? "\uE8D6" : "\uEB9F"
    }

    function assets() {
        var items = []
        for (var i = 0; i < assetModel.count; i++) {
            var asset = assetModel.get(i)
            items.push({ "name": asset.name, "kind": asset.kind, "path": asset.path })
        }
        return items
    }

    function assetIndexForPath(path) {
        for (var i = 0; i < assetModel.count; i++) {
            if (assetModel.get(i).path === path) {
                return i
            }
        }
        return -1
    }

    function moveAssetByPath(path, direction) {
        var fromIndex = assetIndexForPath(path)
        if (fromIndex < 0) {
            return false
        }
        var toIndex = Math.max(0, Math.min(assetModel.count - 1, fromIndex + direction))
        if (fromIndex === toIndex) {
            return false
        }
        assetModel.move(fromIndex, toIndex, 1)
        if (selectedIndex === fromIndex) {
            selectedIndex = toIndex
        } else if (direction < 0 && selectedIndex === toIndex) {
            selectedIndex += 1
        } else if (direction > 0 && selectedIndex === toIndex) {
            selectedIndex -= 1
        }
        return true
    }

    function loadAssets(items) {
        assetModel.clear()
        selectedIndex = -1
        for (var i = 0; i < items.length; i++) {
            var asset = items[i]
            assetModel.append({
                "name": asset.name,
                "kind": asset.kind,
                "icon": iconForKind(asset.kind),
                "path": asset.path
            })
        }
    }

    function selectAsset(index, name, kind, path) {
        selectedIndex = index
        root.assetSelected(name, kind, path)
    }

    function latestAssetName(kind) {
        for (var i = assetModel.count - 1; i >= 0; i--) {
            var asset = assetModel.get(i)
            if (asset.kind === kind) {
                return asset.name
            }
        }
        return ""
    }

    function latestAssetPath(kind) {
        for (var i = assetModel.count - 1; i >= 0; i--) {
            var asset = assetModel.get(i)
            if (asset.kind === kind) {
                return asset.path
            }
        }
        return ""
    }

    function latestVisualAsset() {
        for (var i = assetModel.count - 1; i >= 0; i--) {
            var asset = assetModel.get(i)
            if (asset.kind === "Visual") {
                return { "name": asset.name, "path": asset.path }
            }
        }
        return { "name": "", "path": "" }
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
            root.importFile(selectedFile)
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
            root.importFile(selectedFile)
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
            id: dropZone
            Layout.fillWidth: true
            height: 116
            radius: 8
            color: mediaDrop.containsDrag ? Theme.dropSurface : Theme.surfaceRaised
            border.color: mediaDrop.containsDrag ? Theme.accent : Theme.stroke

            Column {
                anchors.centerIn: parent
                spacing: 9

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: mediaDrop.containsDrag ? "\uE8B5" : "\uE8B5"
                    color: Theme.accent
                    font.family: "Segoe MDL2 Assets"
                    font.pixelSize: 24
                }

                Text {
                    width: root.width - 64
                    horizontalAlignment: Text.AlignHCenter
                    text: mediaDrop.containsDrag ? "Release to import" : "Drop media here"
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

            DropArea {
                id: mediaDrop
                anchors.fill: parent
                onEntered: function(drag) {
                    drag.accepted = root.hasImportableFiles(drag.urls)
                }
                onDropped: function(drop) {
                    if (root.importFiles(drop.urls) > 0) {
                        drop.acceptProposedAction()
                    }
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
                    : index === root.selectedIndex
                        ? (isAudio ? Theme.audioSurfaceHover : Theme.dropSurface)
                        : (isAudio ? Theme.audioSurface : Theme.surfaceRaised)
                border.color: index === root.selectedIndex
                    ? (isAudio ? Theme.audioAccent : Theme.accent)
                    : (isAudio ? Theme.audioStroke : Theme.stroke)

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

                TapHandler {
                    onTapped: root.selectAsset(index, name, kind, path)
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
