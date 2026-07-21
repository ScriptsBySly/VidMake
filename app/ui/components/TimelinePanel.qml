import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Panel {
    id: root
    title: "Timeline"
    property string audioName: ""
    property string visualName: ""
    property string selectedAssetPath: ""
    property int playheadPosition: 0
    property int timelineDuration: 15000
    property bool playing: false
    signal assetSelected(string name, string kind, string path)
    signal seekRequested(int milliseconds)
    signal playbackToggled()
    property var cachedAssets: []
    property var cachedKeyframeLayers: []
    property var cachedMaskLayers: []

    function formatTime(milliseconds) {
        var total = Math.max(0, Math.floor(milliseconds / 1000))
        var minutes = Math.floor(total / 60)
        var seconds = total % 60
        return (minutes < 10 ? "0" + minutes : "" + minutes) + ":"
            + (seconds < 10 ? "0" + seconds : "" + seconds)
    }

    function clipColor(kind) {
        if (kind === "Keyframes") {
            return "#496f48"
        }
        if (kind === "Mask") {
            return "#5b4b8a"
        }
        return kind === "Audio" ? "#b45309" : "#2b5361"
    }

    function clipBorder(kind, selected) {
        if (selected) {
            return kind === "Audio" ? "#7c2d12" : Theme.accent
        }
        if (kind === "Keyframes") {
            return "#8fb889"
        }
        if (kind === "Mask") {
            return "#a99be0"
        }
        return kind === "Audio" ? Theme.audioStroke : "#6dbad0"
    }

    function rebuildTimeline() {
        timelineModel.clear()
        for (var i = 0; i < cachedAssets.length; i++) {
            var asset = cachedAssets[i]
            timelineModel.append({
                "name": asset.name,
                "kind": asset.kind,
                "path": asset.path,
                "start": 0
            })
        }
        for (var j = 0; j < cachedKeyframeLayers.length; j++) {
            var layer = cachedKeyframeLayers[j]
            timelineModel.append({
                "name": layer.name + " (" + layer.keyframes.length + ")",
                "kind": "Keyframes",
                "path": layer.id,
                "start": 0
            })
        }
        for (var k = 0; k < cachedMaskLayers.length; k++) {
            var mask = cachedMaskLayers[k]
            timelineModel.append({
                "name": mask.name,
                "kind": "Mask",
                "path": mask.id,
                "start": 0
            })
        }
    }

    function loadAssets(items) {
        cachedAssets = items
        rebuildTimeline()
    }

    function loadKeyframeLayers(layers) {
        cachedKeyframeLayers = layers
        rebuildTimeline()
    }

    function loadMaskLayers(layers) {
        cachedMaskLayers = layers
        rebuildTimeline()
    }

    ListModel {
        id: timelineModel
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 52
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.bottomMargin: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            PillButton {
                text: root.playing ? "Pause" : "Play"
                iconText: root.playing ? "\uE769" : "\uE768"
                accent: true
                onClicked: root.playbackToggled()
            }

            PillButton {
                text: "Add effect"
                iconText: "\uE710"
            }

            ComboBox {
                Layout.preferredWidth: 150
                model: ["Fit", "100%", "200%"]
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            Text {
                text: root.formatTime(root.playheadPosition) + " / " + root.formatTime(root.timelineDuration)
                color: Theme.subtleText
                font.family: Theme.monoFamily
                font.pixelSize: 12
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: "30 fps"
                color: Theme.subtleText
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }

        Rectangle {
            id: ruler
            Layout.fillWidth: true
            height: 58
            radius: 8
            color: Theme.surfaceRaised
            border.color: Theme.stroke
            clip: true

            Repeater {
                model: 16
                Rectangle {
                    required property int index
                    x: index * ruler.width / 15
                    y: 0
                    width: 1
                    height: index % 5 === 0 ? ruler.height : 34
                    color: index % 5 === 0 ? Theme.strokeStrong : Theme.stroke

                    Text {
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        anchors.left: parent.left
                        anchors.leftMargin: 5
                        text: index + "s"
                        visible: index % 5 === 0
                        color: Theme.subtleText
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }
            }

            Rectangle {
                x: Math.min(ruler.width - width, Math.max(0, ruler.width * root.playheadPosition / root.timelineDuration))
                width: 2
                height: ruler.height
                color: Theme.accent
                z: 5
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: false
                acceptedButtons: Qt.LeftButton
                onClicked: function(mouse) {
                    root.seekRequested(Math.round(root.timelineDuration * mouse.x / ruler.width))
                }
            }
        }

        Rectangle {
            id: timelineBody
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            color: Theme.timeline
            border.color: Theme.stroke
            clip: true

            ListView {
                id: trackList
                anchors.fill: parent
                anchors.margins: 1
                clip: true
                spacing: 0
                model: timelineModel

                delegate: Rectangle {
                    required property string name
                    required property string kind
                    required property string path
                    required property int start

                    width: trackList.width
                    height: 44
                    color: "transparent"
                    border.color: Theme.stroke

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 112
                        color: Theme.trackHeader

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: kind
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            width: parent.width - 20
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: false
                        acceptedButtons: Qt.LeftButton
                        onClicked: function(mouse) {
                            if (mouse.x > 112) {
                                root.seekRequested(Math.round(root.timelineDuration * (mouse.x - 122) / Math.max(1, parent.width - 142)))
                            }
                        }
                    }

                    Rectangle {
                        id: clip
                        x: 122 + Math.round((parent.width - 142) * start / root.timelineDuration)
                        y: 8
                        width: Math.max(88, parent.width - 142)
                        height: parent.height - 16
                        radius: 6
                        z: 2
                        color: root.clipColor(kind)
                        opacity: path === root.selectedAssetPath ? 1.0 : 0.82
                        border.color: root.clipBorder(kind, path === root.selectedAssetPath)
                        border.width: path === root.selectedAssetPath ? 2 : 1

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: name
                            color: "white"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            width: parent.width - 20
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: false
                            acceptedButtons: Qt.LeftButton
                            onClicked: {
                                if (kind !== "Keyframes" && kind !== "Mask") {
                                    root.assetSelected(name, kind, path)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 48
                    height: 36
                    radius: 8
                    color: Theme.surfaceRaised
                    border.color: Theme.stroke
                    visible: timelineModel.count === 0

                    Text {
                        anchors.centerIn: parent
                        text: "Import assets to populate the timeline"
                        color: Theme.subtleText
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }
                }
            }

            Rectangle {
                x: 123 + Math.min(timelineBody.width - 143, Math.max(0, (timelineBody.width - 142) * root.playheadPosition / root.timelineDuration))
                width: 2
                height: timelineBody.height
                color: Theme.accent
                z: 5
            }

        }
    }
}
