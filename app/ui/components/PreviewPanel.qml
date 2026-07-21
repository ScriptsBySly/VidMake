import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

Panel {
    id: root
    title: "Preview"
    property string visualName: ""
    property string assetName: ""
    property string assetKind: ""
    property string assetPath: ""
    property int projectWidth: 1080
    property int projectHeight: 1920
    property string compositionAudioName: ""
    property string compositionAudioPath: ""
    property string compositionVisualName: ""
    property string compositionVisualPath: ""
    property var compositionEffectLayers: []
    property var audioKeyframeLayers: []
    property var compositionMaskLayers: []
    property bool compositionMode: false
    readonly property string mediaUrl: assetPath.length > 0 ? pathToUrl(assetPath) : ""
    readonly property string compositionAudioUrl: compositionAudioPath.length > 0 ? pathToUrl(compositionAudioPath) : ""
    readonly property string compositionVisualUrl: compositionVisualPath.length > 0 ? pathToUrl(compositionVisualPath) : ""
    readonly property string assetExtension: extensionFromName(assetName.length > 0 ? assetName : assetPath)
    readonly property string compositionVisualExtension: extensionFromName(compositionVisualName.length > 0 ? compositionVisualName : compositionVisualPath)
    readonly property bool isAudio: assetKind === "Audio"
    readonly property bool isVideo: assetKind === "Visual" && ["mp4", "mov", "mkv", "avi"].indexOf(assetExtension) >= 0
    readonly property bool isImage: assetKind === "Visual" && ["png", "jpg", "jpeg", "webp", "gif"].indexOf(assetExtension) >= 0
    readonly property bool canPlay: isAudio || isVideo
    readonly property bool compositionVisualIsVideo: ["mp4", "mov", "mkv", "avi"].indexOf(compositionVisualExtension) >= 0
    readonly property bool compositionVisualIsImage: ["png", "jpg", "jpeg", "webp", "gif"].indexOf(compositionVisualExtension) >= 0
    readonly property bool compositionCanPlay: compositionAudioPath.length > 0 || compositionVisualIsVideo
    readonly property bool activeCanPlay: compositionMode ? compositionCanPlay : canPlay
    readonly property int compositionPosition: compositionAudioPath.length > 0 ? compositionAudioPlayer.position : compositionVideoPlayer.position
    readonly property int compositionDuration: Math.max(compositionAudioPlayer.duration, compositionVideoPlayer.duration)
    readonly property int currentPosition: compositionMode ? compositionPosition : player.position
    readonly property int currentDuration: compositionMode ? compositionDuration : player.duration
    readonly property bool isPlaying: compositionMode
        ? (compositionAudioPlayer.playbackState === MediaPlayer.PlayingState || compositionVideoPlayer.playbackState === MediaPlayer.PlayingState)
        : player.playbackState === MediaPlayer.PlayingState
    readonly property var activeZoomBlurEffect: zoomBlurEffectForCurrentVisual()
    readonly property real zoomBlurPulse: zoomBlurPulseValue()
    readonly property bool zoomBlurMaskMode: activeZoomBlurEffect && (activeZoomBlurEffect.mask_mode || "none") === "mask"
    readonly property var activeZoomBlurMaskLayer: maskLayerById(zoomBlurMaskMode ? activeZoomBlurEffect.mask_layer_id || "" : "")
    readonly property bool zoomBlurUsesMask: activeZoomBlurMaskLayer !== null
    readonly property string zoomBlurCutoutPath: zoomBlurUsesMask ? activeZoomBlurMaskLayer.cutout_path || activeZoomBlurMaskLayer.preview_path || "" : ""
    readonly property string zoomBlurCutoutUrl: zoomBlurCutoutPath.length > 0 ? pathToUrl(zoomBlurCutoutPath) : ""
    readonly property real zoomBlurOriginX: zoomBlurUsesMask ? activeZoomBlurMaskLayer.mask_center_x || 0.5 : 0.5
    readonly property real zoomBlurOriginY: zoomBlurUsesMask ? activeZoomBlurMaskLayer.mask_center_y || 0.5 : 0.5
    readonly property real zoomBlurScale: activeZoomBlurEffect && !zoomBlurMaskMode ? 1.0 + (activeZoomBlurEffect.zoom_amount - 1.0) * zoomBlurPulse : 1.0
    readonly property real zoomBlurOpacity: activeZoomBlurEffect && (!zoomBlurMaskMode || (zoomBlurUsesMask && zoomBlurCutoutUrl.length > 0)) ? activeZoomBlurEffect.blur_strength * zoomBlurPulse : 0.0
    property bool seeking: false
    property real previewVolume: 0.85
    property bool previewMuted: false

    function extensionFromName(name) {
        var dot = name.lastIndexOf(".")
        return dot >= 0 ? name.slice(dot + 1).toLowerCase() : ""
    }

    function pathToUrl(path) {
        var normalized = path.replace(/\\/g, "/")
        if (normalized.indexOf("file://") === 0) {
            return normalized
        }
        return "file:///" + encodeURI(normalized)
    }

    function formatTime(milliseconds) {
        var total = Math.max(0, Math.floor(milliseconds / 1000))
        var minutes = Math.floor(total / 60)
        var seconds = total % 60
        var hundredths = Math.floor((milliseconds % 1000) / 10)
        return twoDigits(minutes) + ":" + twoDigits(seconds) + "." + twoDigits(hundredths)
    }

    function twoDigits(value) {
        return value < 10 ? "0" + value : "" + value
    }

    function placeholderLabel() {
        if (compositionMode) {
            return compositionAudioName.length > 0 ? compositionAudioName : "Timeline playback"
        }
        return assetName.length > 0 ? assetName : "Select an asset"
    }

    function frameCaption() {
        if (compositionMode) {
            if (compositionVisualName.length > 0 && compositionAudioName.length > 0) {
                return compositionVisualName + " + " + compositionAudioName
            }
            if (compositionVisualName.length > 0) {
                return compositionVisualName
            }
            return compositionAudioName
        }
        if (assetName.length > 0) {
            return assetName
        }
        if (visualName.length > 0) {
            return visualName
        }
        return projectWidth + " x " + projectHeight
    }

    function togglePlayback() {
        if (compositionMode) {
            toggleCompositionPlayback()
            return
        }
        if (!canPlay) {
            return
        }
        if (player.playbackState === MediaPlayer.PlayingState) {
            player.pause()
        } else {
            player.play()
        }
    }

    function jumpBy(milliseconds) {
        if (!activeCanPlay) {
            return
        }
        seekTo(currentPosition + milliseconds)
    }

    function seekTo(milliseconds) {
        if (!activeCanPlay) {
            return
        }
        var target = Math.max(0, Math.min(Math.max(1, currentDuration), milliseconds))
        if (compositionMode) {
            if (compositionAudioPath.length > 0) {
                compositionAudioPlayer.position = target
            }
            if (compositionVisualIsVideo) {
                compositionVideoPlayer.position = target
            }
        } else {
            player.position = target
        }
    }

    function loadCompositionAssets(items) {
        compositionAudioName = ""
        compositionAudioPath = ""
        compositionVisualName = ""
        compositionVisualPath = ""
        for (var i = 0; i < items.length; i++) {
            var asset = items[i]
            if (asset.kind === "Audio") {
                compositionAudioName = asset.name
                compositionAudioPath = asset.path
            } else if (asset.kind === "Visual") {
                compositionVisualName = asset.name
                compositionVisualPath = asset.path
            }
        }
    }

    function loadCompositionEffects(items) {
        compositionEffectLayers = items
    }

    function loadAudioKeyframeLayers(items) {
        audioKeyframeLayers = items
    }

    function loadCompositionMasks(items) {
        compositionMaskLayers = items
    }

    function audioKeyframeLayerById(layerId) {
        if (layerId.length === 0) {
            return null
        }
        for (var i = 0; i < audioKeyframeLayers.length; i++) {
            if (audioKeyframeLayers[i].id === layerId) {
                return audioKeyframeLayers[i]
            }
        }
        return null
    }

    function maskLayerById(layerId) {
        if (layerId.length === 0) {
            return null
        }
        for (var i = 0; i < compositionMaskLayers.length; i++) {
            if (compositionMaskLayers[i].id === layerId) {
                return compositionMaskLayers[i]
            }
        }
        return null
    }

    function maskBound(name, fallback) {
        if (!zoomBlurUsesMask || !activeZoomBlurMaskLayer.mask_bounds) {
            return fallback
        }
        var value = activeZoomBlurMaskLayer.mask_bounds[name]
        return value === undefined ? fallback : value
    }

    function zoomBlurBurstScale(index) {
        var zoomAmount = activeZoomBlurEffect ? activeZoomBlurEffect.zoom_amount : 1.12
        return 1.0 + (zoomAmount - 1.0) * zoomBlurPulse * (1.0 + index * 0.55)
    }

    function zoomBlurEffectForCurrentVisual() {
        var targetPath = compositionMode ? compositionVisualPath : assetKind === "Visual" ? assetPath : ""
        if (targetPath.length === 0) {
            return null
        }
        for (var i = compositionEffectLayers.length - 1; i >= 0; i--) {
            var effect = compositionEffectLayers[i]
            if (effect.plugin === "builtin.zoom_blur" && effect.source_visual_path === targetPath) {
                return effect
            }
        }
        return null
    }

    function zoomBlurPulseValue() {
        var effect = activeZoomBlurEffect
        if (!effect) {
            return 0.0
        }
        if ((effect.trigger_mode || "interval") === "keyframes") {
            var layer = audioKeyframeLayerById(effect.keyframe_layer_id || "")
            if (!layer || !layer.keyframes || layer.keyframes.length === 0) {
                return 0.0
            }
            var nowSeconds = currentPosition / 1000.0
            var attackSeconds = 0.06
            var releaseSeconds = 0.28
            var bestPulse = 0.0
            for (var i = 0; i < layer.keyframes.length; i++) {
                var keyframe = layer.keyframes[i]
                var timeSeconds = keyframe.time_seconds || 0.0
                if (timeSeconds > nowSeconds + attackSeconds) {
                    break
                }
                var delta = nowSeconds - timeSeconds
                var pulse = 0.0
                if (delta < 0 && -delta <= attackSeconds) {
                    pulse = 1.0 + (delta / attackSeconds)
                } else if (delta >= 0 && delta <= releaseSeconds) {
                    pulse = 1.0 - (delta / releaseSeconds)
                }
                if (pulse > 0.0) {
                    bestPulse = Math.max(bestPulse, pulse * Math.max(0.0, Math.min(1.0, keyframe.value || 1.0)))
                }
            }
            return Math.max(0.0, Math.min(1.0, bestPulse))
        }
        var intervalMs = Math.max(50, effect.trigger_interval_seconds * 1000.0)
        var phase = currentPosition % intervalMs
        var attackMs = Math.min(120, intervalMs * 0.25)
        var releaseMs = Math.min(420, intervalMs * 0.75)
        if (phase <= attackMs) {
            return phase / Math.max(1, attackMs)
        }
        if (phase <= attackMs + releaseMs) {
            return 1.0 - ((phase - attackMs) / Math.max(1, releaseMs))
        }
        return 0.0
    }

    function stopComposition() {
        compositionAudioPlayer.stop()
        compositionVideoPlayer.stop()
        compositionMode = false
    }

    function toggleCompositionPlayback() {
        if (!compositionCanPlay) {
            return
        }
        player.stop()
        compositionMode = true
        if (isPlaying) {
            compositionAudioPlayer.pause()
            compositionVideoPlayer.pause()
            return
        }
        if (compositionVisualIsVideo) {
            compositionVideoPlayer.play()
        }
        if (compositionAudioPath.length > 0) {
            compositionAudioPlayer.play()
        }
    }

    function seekCompositionTo(milliseconds) {
        if (!compositionCanPlay) {
            return
        }
        player.stop()
        compositionMode = true
        seekTo(milliseconds)
    }

    onMediaUrlChanged: {
        stopComposition()
        player.stop()
        player.position = 0
    }

    AudioOutput {
        id: audioOutput
        volume: root.previewVolume
        muted: root.previewMuted
    }

    MediaPlayer {
        id: player
        source: root.canPlay && !root.compositionMode ? root.mediaUrl : ""
        audioOutput: audioOutput
        videoOutput: assetVideoOutput
        onPositionChanged: {
            if (!root.seeking && !root.compositionMode) {
                scrubber.value = position
            }
        }
        onDurationChanged: scrubber.value = 0
    }

    AudioOutput {
        id: compositionAudioOutput
        volume: root.previewVolume
        muted: root.previewMuted
    }

    AudioOutput {
        id: compositionVideoAudioOutput
        volume: root.previewVolume
        muted: root.previewMuted || root.compositionAudioPath.length > 0
    }

    MediaPlayer {
        id: compositionAudioPlayer
        source: root.compositionAudioPath.length > 0 ? root.compositionAudioUrl : ""
        audioOutput: compositionAudioOutput
        onPositionChanged: {
            if (!root.seeking && root.compositionMode) {
                scrubber.value = root.currentPosition
            }
        }
    }

    MediaPlayer {
        id: compositionVideoPlayer
        source: root.compositionVisualIsVideo ? root.compositionVisualUrl : ""
        audioOutput: compositionVideoAudioOutput
        videoOutput: compositionVideoOutput
        onPositionChanged: {
            if (!root.seeking && root.compositionMode && root.compositionAudioPath.length === 0) {
                scrubber.value = position
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 54
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 16
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            color: "#111113"
            border.color: Theme.strokeStrong
            clip: true

            Rectangle {
                id: frame
                anchors.centerIn: parent
                width: Math.min(parent.width - 48, (parent.height - 48) * root.projectWidth / root.projectHeight)
                height: width * root.projectHeight / root.projectWidth
                radius: 6
                color: "#1c1d20"
                border.color: "#303238"
                clip: true

                Item {
                    id: visualContent
                    anchors.fill: parent
                    scale: root.zoomBlurScale
                    transformOrigin: Item.Center

                    Behavior on scale {
                        NumberAnimation {
                            duration: 55
                            easing.type: Easing.OutCubic
                        }
                    }

                    VideoOutput {
                        id: assetVideoOutput
                        anchors.fill: parent
                        fillMode: VideoOutput.PreserveAspectFit
                        visible: !root.compositionMode && root.isVideo
                    }

                    VideoOutput {
                        id: compositionVideoOutput
                        anchors.fill: parent
                        fillMode: VideoOutput.PreserveAspectFit
                        visible: root.compositionMode && root.compositionVisualIsVideo
                    }

                    Image {
                        anchors.fill: parent
                        anchors.margins: 12
                        source: root.compositionMode && root.compositionVisualIsImage
                            ? root.compositionVisualUrl
                            : !root.compositionMode && root.isImage ? root.mediaUrl : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        visible: source.toString().length > 0
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 14
                        visible: root.compositionMode
                            ? !root.compositionVisualIsImage && !root.compositionVisualIsVideo
                            : !root.isImage && !root.isVideo

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 96
                            height: 96
                            radius: 8
                            color: root.isAudio ? Theme.audioTile : "#2b5361"
                            border.color: root.isAudio ? Theme.audioAccent : "#6dbad0"

                            Text {
                                anchors.centerIn: parent
                                text: root.compositionMode || root.isAudio ? "\uE8D6" : "\uEB9F"
                                color: root.compositionMode || root.isAudio ? Theme.audioAccent : "#d7f4ff"
                                font.family: "Segoe MDL2 Assets"
                                font.pixelSize: 42
                            }
                        }

                        Text {
                            width: Math.min(frame.width - 32, 360)
                            horizontalAlignment: Text.AlignHCenter
                            text: root.placeholderLabel()
                            color: "#d9dbe1"
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            elide: Text.ElideMiddle
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    visible: root.zoomBlurOpacity > 0.01 && !root.zoomBlurMaskMode
                    opacity: root.zoomBlurOpacity

                    Rectangle {
                        x: root.maskBound("min_x", 0.0) * frame.width
                        y: root.maskBound("min_y", 0.0) * frame.height
                        width: root.zoomBlurUsesMask ? Math.max(12, (root.maskBound("max_x", 1.0) - root.maskBound("min_x", 0.0)) * frame.width) : frame.width
                        height: root.zoomBlurUsesMask ? Math.max(12, (root.maskBound("max_y", 1.0) - root.maskBound("min_y", 0.0)) * frame.height) : frame.height
                        color: "transparent"
                        border.color: root.zoomBlurUsesMask ? "#ffffff" : "transparent"
                        border.width: root.zoomBlurUsesMask ? 2 : 0
                        radius: 6
                        scale: 1.0 + root.zoomBlurPulse * 0.25
                        opacity: root.zoomBlurUsesMask ? 0.36 : 0.0
                        transformOrigin: Item.Center
                    }

                    Repeater {
                        model: 12

                        Rectangle {
                            required property int index
                            width: frame.width * (root.zoomBlurUsesMask ? 0.62 : 0.42) * (0.65 + root.zoomBlurPulse * 0.55)
                            height: 2
                            radius: 1
                            color: "white"
                            opacity: 0.42
                            x: frame.width * root.zoomBlurOriginX
                            y: frame.height * root.zoomBlurOriginY
                            transformOrigin: Item.Left
                            rotation: index * 30
                        }
                    }

                    Repeater {
                        model: root.zoomBlurUsesMask ? 3 : 0

                        Rectangle {
                            required property int index
                            width: 34 + index * 34 + root.zoomBlurPulse * 92
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.color: "white"
                            border.width: 2
                            opacity: 0.38 - index * 0.1
                            x: frame.width * root.zoomBlurOriginX - width / 2
                            y: frame.height * root.zoomBlurOriginY - height / 2
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    visible: root.zoomBlurMaskMode && root.zoomBlurOpacity > 0.01
                    opacity: Math.min(1.0, 0.38 + root.zoomBlurOpacity)

                    Repeater {
                        model: 4

                        Image {
                            id: maskCutoutBurst
                            required property int index
                            anchors.fill: parent
                            anchors.margins: 12
                            source: root.zoomBlurCutoutUrl
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                            opacity: Math.max(0.0, 0.42 - index * 0.1) * root.zoomBlurPulse
                            transform: Scale {
                                origin.x: maskCutoutBurst.width * root.zoomBlurOriginX
                                origin.y: maskCutoutBurst.height * root.zoomBlurOriginY
                                xScale: root.zoomBlurBurstScale(maskCutoutBurst.index)
                                yScale: root.zoomBlurBurstScale(maskCutoutBurst.index)
                            }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 18
                    text: root.frameCaption()
                    color: "#a9adb7"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    width: parent.width - 28
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideMiddle
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            IconButton {
                iconText: "\uE892"
                tooltip: "Jump backward"
                enabled: root.activeCanPlay
                onClicked: root.jumpBy(-1000)
            }

            IconButton {
                iconText: root.isPlaying ? "\uE769" : "\uE768"
                tooltip: root.isPlaying ? "Pause" : "Play"
                accented: true
                enabled: root.activeCanPlay
                onClicked: root.togglePlayback()
            }

            IconButton {
                iconText: "\uE893"
                tooltip: "Jump forward"
                enabled: root.activeCanPlay
                onClicked: root.jumpBy(1000)
            }

            Slider {
                id: scrubber
                Layout.fillWidth: true
                from: 0
                to: Math.max(1, root.currentDuration)
                enabled: root.activeCanPlay && root.currentDuration > 0
                onPressedChanged: {
                    root.seeking = pressed
                    if (!pressed && root.activeCanPlay) {
                        root.seekTo(value)
                    }
                }
                onMoved: {
                    if (root.activeCanPlay) {
                        root.seekTo(value)
                    }
                }
            }

            Text {
                text: root.activeCanPlay ? root.formatTime(root.currentPosition) : "00:00.00"
                color: Theme.subtleText
                font.family: Theme.monoFamily
                font.pixelSize: 12
                Layout.preferredWidth: 62
                horizontalAlignment: Text.AlignRight
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            IconButton {
                iconText: "\uE892"
                badgeText: "5s"
                tooltip: "Back 5 seconds"
                enabled: root.activeCanPlay
                onClicked: root.jumpBy(-5000)
            }

            Item {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
            }

            IconButton {
                iconText: "\uE893"
                badgeText: "5s"
                tooltip: "Forward 5 seconds"
                enabled: root.activeCanPlay
                onClicked: root.jumpBy(5000)
            }

            Item {
                Layout.fillWidth: true
            }

            Item {
                Layout.preferredWidth: 62
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Item {
                Layout.fillWidth: true
            }

            IconButton {
                iconText: root.previewMuted || root.previewVolume === 0 ? "\uE74F" : "\uE767"
                tooltip: root.previewMuted ? "Unmute preview" : "Mute preview"
                enabled: root.activeCanPlay
                onClicked: root.previewMuted = !root.previewMuted
            }

            Slider {
                Layout.preferredWidth: 160
                from: 0
                to: 1
                value: root.previewVolume
                enabled: root.activeCanPlay
                onMoved: {
                    root.previewVolume = value
                    if (value > 0) {
                        root.previewMuted = false
                    }
                }
            }
        }
    }
}
