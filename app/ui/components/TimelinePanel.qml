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
    signal generatedLayerEditRequested(string kind, string id)
    signal generatedLayerDeleteRequested(string kind, string id)
    signal effectAddRequested()
    signal assetMoveRequested(string path, int direction)
    signal assetDeleteRequested(string name, string kind, string path)
    property var cachedAssets: []
    property var cachedKeyframeLayers: []
    property var cachedMaskLayers: []
    property var cachedEffectLayers: []

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
        if (kind === "Effect") {
            return "#0f766e"
        }
        return kind === "Audio" ? "#b45309" : "#2b5361"
    }

    function rowLabel(kind, depth) {
        if (depth > 0) {
            return kind
        }
        if (kind === "Effect") {
            return "Effect"
        }
        if (kind === "Mask") {
            return "Mask"
        }
        if (kind === "Keyframes") {
            return "Keyframes"
        }
        return kind === "Audio" ? "Audio Source" : "Visual Source"
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
        if (kind === "Effect") {
            return "#5eead4"
        }
        return kind === "Audio" ? Theme.audioStroke : "#6dbad0"
    }

    function rebuildTimeline() {
        timelineModel.clear()
        var groupedKeyframes = {}
        var groupedMasks = {}
        var groupedEffects = {}
        var usedKeyframes = {}
        var usedMasks = {}
        var usedEffects = {}

        for (var keyframeIndex = 0; keyframeIndex < cachedKeyframeLayers.length; keyframeIndex++) {
            var keyframeLayer = cachedKeyframeLayers[keyframeIndex]
            var audioPath = keyframeLayer.source_audio_path || ""
            if (!groupedKeyframes[audioPath]) {
                groupedKeyframes[audioPath] = []
            }
            groupedKeyframes[audioPath].push(keyframeLayer)
        }

        for (var maskIndex = 0; maskIndex < cachedMaskLayers.length; maskIndex++) {
            var maskLayer = cachedMaskLayers[maskIndex]
            var visualPath = maskLayer.source_video_path || ""
            if (!groupedMasks[visualPath]) {
                groupedMasks[visualPath] = []
            }
            groupedMasks[visualPath].push(maskLayer)
        }

        for (var effectIndex = 0; effectIndex < cachedEffectLayers.length; effectIndex++) {
            var effectLayer = cachedEffectLayers[effectIndex]
            var effectVisualPath = effectLayer.source_visual_path || ""
            if (!groupedEffects[effectVisualPath]) {
                groupedEffects[effectVisualPath] = []
            }
            groupedEffects[effectVisualPath].push(effectLayer)
        }

        for (var i = 0; i < cachedAssets.length; i++) {
            var asset = cachedAssets[i]
            timelineModel.append({
                "name": asset.name,
                "kind": asset.kind,
                "path": asset.path,
                "start": 0,
                "depth": 0,
                "selectable": true
            })

            var keyframeChildren = groupedKeyframes[asset.path] || []
            for (var j = 0; j < keyframeChildren.length; j++) {
                var childKeyframes = keyframeChildren[j]
                usedKeyframes[childKeyframes.id] = true
                timelineModel.append({
                    "name": childKeyframes.name + " (" + childKeyframes.keyframes.length + ")",
                    "kind": "Keyframes",
                    "path": childKeyframes.id,
                    "start": 0,
                    "depth": 1,
                    "selectable": false
                })
            }

            var maskChildren = groupedMasks[asset.path] || []
            for (var k = 0; k < maskChildren.length; k++) {
                var childMask = maskChildren[k]
                usedMasks[childMask.id] = true
                timelineModel.append({
                    "name": childMask.name,
                    "kind": "Mask",
                    "path": childMask.id,
                    "start": 0,
                    "depth": 1,
                    "selectable": false
                })
            }

            var effectChildren = groupedEffects[asset.path] || []
            for (var effectChildIndex = 0; effectChildIndex < effectChildren.length; effectChildIndex++) {
                var childEffect = effectChildren[effectChildIndex]
                usedEffects[childEffect.id] = true
                timelineModel.append({
                    "name": childEffect.name,
                    "kind": "Effect",
                    "path": childEffect.id,
                    "start": 0,
                    "depth": 1,
                    "selectable": false
                })
            }
        }

        for (var orphanKeyframeIndex = 0; orphanKeyframeIndex < cachedKeyframeLayers.length; orphanKeyframeIndex++) {
            var layer = cachedKeyframeLayers[orphanKeyframeIndex]
            if (usedKeyframes[layer.id]) {
                continue
            }
            timelineModel.append({
                "name": layer.name + " (" + layer.keyframes.length + ")",
                "kind": "Keyframes",
                "path": layer.id,
                "start": 0,
                "depth": 0,
                "selectable": false
            })
        }
        for (var orphanMaskIndex = 0; orphanMaskIndex < cachedMaskLayers.length; orphanMaskIndex++) {
            var mask = cachedMaskLayers[orphanMaskIndex]
            if (usedMasks[mask.id]) {
                continue
            }
            timelineModel.append({
                "name": mask.name,
                "kind": "Mask",
                "path": mask.id,
                "start": 0,
                "depth": 0,
                "selectable": false
            })
        }
        for (var orphanEffectIndex = 0; orphanEffectIndex < cachedEffectLayers.length; orphanEffectIndex++) {
            var effect = cachedEffectLayers[orphanEffectIndex]
            if (usedEffects[effect.id]) {
                continue
            }
            timelineModel.append({
                "name": effect.name,
                "kind": "Effect",
                "path": effect.id,
                "start": 0,
                "depth": 0,
                "selectable": false
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

    function loadTimelineData(assets, keyframeLayers, maskLayerItems, effectLayerItems) {
        cachedAssets = assets
        cachedKeyframeLayers = keyframeLayers
        cachedMaskLayers = maskLayerItems
        cachedEffectLayers = effectLayerItems
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
                onClicked: root.effectAddRequested()
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
                interactive: false
                model: timelineModel

                delegate: Rectangle {
                    required property string name
                    required property string kind
                    required property string path
                    required property int start
                    required property int depth
                    required property bool selectable

                    width: trackList.width
                    height: 44
                    color: depth > 0 ? "#fafafa" : "transparent"
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
                            text: root.rowLabel(kind, depth)
                            color: depth > 0 ? Theme.subtleText : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            width: parent.width - 20
                        }
                    }

                    Rectangle {
                        id: clip
                        x: 122 + depth * 28 + Math.round((parent.width - 142 - depth * 28) * start / root.timelineDuration)
                        y: 8
                        width: Math.max(88, parent.width - 142 - depth * 28)
                        height: parent.height - 16
                        radius: 6
                        z: 2
                        color: root.clipColor(kind)
                        opacity: path === root.selectedAssetPath ? 1.0 : 0.82
                        border.color: root.clipBorder(kind, path === root.selectedAssetPath)
                        border.width: path === root.selectedAssetPath ? 2 : 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 4
                            spacing: 4
                            z: 2

                            Text {
                                text: name
                                color: "white"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            IconButton {
                                visible: selectable
                                iconText: "\uE70E"
                                tooltip: "Move layer up"
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 24
                                onClicked: root.assetMoveRequested(path, -1)
                            }

                            IconButton {
                                visible: selectable
                                iconText: "\uE70D"
                                tooltip: "Move layer down"
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 24
                                onClicked: root.assetMoveRequested(path, 1)
                            }

                            IconButton {
                                visible: selectable
                                iconText: "\uE74D"
                                tooltip: "Delete asset"
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 24
                                onClicked: root.assetDeleteRequested(name, kind, path)
                            }

                            IconButton {
                                visible: !selectable
                                iconText: "\uE70F"
                                tooltip: "Edit layer"
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 24
                                onClicked: root.generatedLayerEditRequested(kind, path)
                            }

                            IconButton {
                                visible: !selectable
                                iconText: "\uE74D"
                                tooltip: "Delete layer"
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 24
                                onClicked: root.generatedLayerDeleteRequested(kind, path)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: selectable
                            z: 1
                            hoverEnabled: false
                            acceptedButtons: Qt.LeftButton
                            onClicked: {
                                root.assetSelected(name, kind, path)
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
