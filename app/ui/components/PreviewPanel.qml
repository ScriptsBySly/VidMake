import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
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
    property string compositionVideoName: ""
    property string compositionVideoPath: ""
    property int compositionVideoLayerIndex: -1
    property var compositionVisualAssets: []
    property var compositionEffectLayers: []
    property var audioKeyframeLayers: []
    property var compositionMaskLayers: []
    property bool compositionMode: false
    readonly property string mediaUrl: assetPath.length > 0 ? pathToUrl(assetPath) : ""
    readonly property string compositionAudioUrl: compositionAudioPath.length > 0 ? pathToUrl(compositionAudioPath) : ""
    readonly property string compositionVisualUrl: compositionVisualPath.length > 0 ? pathToUrl(compositionVisualPath) : ""
    readonly property string compositionVideoUrl: compositionVideoPath.length > 0 ? pathToUrl(compositionVideoPath) : ""
    readonly property string assetExtension: extensionFromName(assetName.length > 0 ? assetName : assetPath)
    readonly property string compositionVisualExtension: extensionFromName(compositionVisualName.length > 0 ? compositionVisualName : compositionVisualPath)
    readonly property string compositionVideoExtension: extensionFromName(compositionVideoName.length > 0 ? compositionVideoName : compositionVideoPath)
    readonly property bool isAudio: assetKind === "Audio"
    readonly property bool isVideo: assetKind === "Visual" && isVideoExtension(assetExtension)
    readonly property bool isImage: assetKind === "Visual" && isImageExtension(assetExtension)
    readonly property bool canPlay: isAudio || isVideo
    readonly property bool compositionVisualIsVideo: isVideoExtension(compositionVisualExtension)
    readonly property bool compositionVisualIsImage: isImageExtension(compositionVisualExtension)
    readonly property bool compositionVideoIsVideo: isVideoExtension(compositionVideoExtension)
    readonly property bool compositionVideoLoopEnabled: assetLoopEnabled(compositionVideoPath)
    readonly property bool assetLoopEnabledForCurrentAsset: assetLoopEnabled(assetPath)
    readonly property bool compositionCanPlay: compositionAudioPath.length > 0 || compositionVideoIsVideo
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
    readonly property string zoomBlurCutoutPath: zoomBlurUsesMask ? activeZoomBlurMaskLayer.cutout_path || "" : ""
    readonly property int zoomBlurFrameIndex: chromaRemoveFrameIndexForLayer(activeZoomBlurMaskLayer)
    readonly property string zoomBlurFrameUrl: chromaRemoveFrameUrlForLayerAt(activeZoomBlurMaskLayer, zoomBlurFrameIndex)
    readonly property string zoomBlurCutoutUrl: zoomBlurFrameUrl.length > 0 ? zoomBlurFrameUrl : isImagePath(zoomBlurCutoutPath) ? pathToUrl(zoomBlurCutoutPath) : ""
    readonly property bool zoomBlurHasCutout: zoomBlurCutoutUrl.length > 0
    readonly property var zoomBlurBursts: zoomBlurBurstModel()
    readonly property real zoomBlurOriginX: zoomBlurUsesMask ? activeZoomBlurMaskLayer.mask_center_x || 0.5 : 0.5
    readonly property real zoomBlurOriginY: zoomBlurUsesMask ? activeZoomBlurMaskLayer.mask_center_y || 0.5 : 0.5
    readonly property real zoomBlurMaskX: maskBound("min_x", 0.0) * frame.width
    readonly property real zoomBlurMaskY: maskBound("min_y", 0.0) * frame.height
    readonly property real zoomBlurMaskWidth: zoomBlurUsesMask ? Math.max(12, (maskBound("max_x", 1.0) - maskBound("min_x", 0.0)) * frame.width) : frame.width
    readonly property real zoomBlurMaskHeight: zoomBlurUsesMask ? Math.max(12, (maskBound("max_y", 1.0) - maskBound("min_y", 0.0)) * frame.height) : frame.height
    readonly property real zoomBlurScale: activeZoomBlurEffect && !zoomBlurMaskMode ? 1.0 + (activeZoomBlurEffect.zoom_amount - 1.0) * zoomBlurPulse : 1.0
    readonly property real zoomBlurOpacity: activeZoomBlurEffect && (!zoomBlurMaskMode || zoomBlurHasCutout) ? activeZoomBlurEffect.blur_strength * zoomBlurPulse : 0.0
    readonly property var activeColorSpreadEffect: colorSpreadEffectForCurrentVisual()
    readonly property var activeColorSpreadMaskLayer: maskLayerById(activeColorSpreadEffect ? activeColorSpreadEffect.mask_layer_id || "" : "")
    readonly property bool colorSpreadReady: activeColorSpreadEffect !== null && activeColorSpreadMaskLayer !== null
    readonly property string colorSpreadMaskPath: colorSpreadReady ? activeColorSpreadMaskLayer.cutout_path || "" : ""
    readonly property int colorSpreadFrameIndex: chromaRemoveFrameIndexForLayer(activeColorSpreadMaskLayer)
    readonly property string colorSpreadFrameUrl: chromaRemoveFrameUrlForLayerAt(activeColorSpreadMaskLayer, colorSpreadFrameIndex)
    readonly property string colorSpreadMaskUrl: colorSpreadFrameUrl.length > 0 ? colorSpreadFrameUrl : isImagePath(colorSpreadMaskPath) ? pathToUrl(colorSpreadMaskPath) : ""
    readonly property bool colorSpreadHasMaskImage: colorSpreadMaskUrl.length > 0
    readonly property real colorSpreadProgress: colorSpreadProgressValue()
    readonly property string colorSpreadColor: colorSpreadCurrentColor()
    readonly property var colorSpreadBursts: colorSpreadBurstModel()
    readonly property real colorSpreadOriginX: colorSpreadReady ? activeColorSpreadMaskLayer.mask_center_x || 0.5 : 0.5
    readonly property real colorSpreadOriginY: colorSpreadReady ? activeColorSpreadMaskLayer.mask_center_y || 0.5 : 0.5
    readonly property var activeChromaRemoveEffect: chromaRemoveEffectForCurrentVisual()
    readonly property var activeChromaRemoveMaskLayer: maskLayerById(activeChromaRemoveEffect ? activeChromaRemoveEffect.mask_layer_id || "" : "")
    readonly property bool chromaRemoveReady: activeChromaRemoveEffect !== null && activeChromaRemoveMaskLayer !== null && ((activeChromaRemoveMaskLayer.cutout_path || "").length > 0 || (activeChromaRemoveMaskLayer.preview_path || "").length > 0)
    readonly property string chromaRemoveCutoutPath: chromaRemoveReady ? activeChromaRemoveMaskLayer.cutout_path || "" : ""
    readonly property string chromaRemoveCutoutUrl: chromaRemoveCutoutIsImage ? pathToUrl(chromaRemoveCutoutPath) : ""
    readonly property bool chromaRemoveCutoutIsVideo: isVideoPath(chromaRemoveCutoutPath)
    readonly property bool chromaRemoveCutoutIsImage: isImagePath(chromaRemoveCutoutPath)
    readonly property string chromaRemoveMaskPath: chromaRemoveReady ? activeChromaRemoveMaskLayer.preview_path || "" : ""
    readonly property string chromaRemoveMaskUrl: chromaRemoveMaskPath.length > 0 ? pathToUrl(chromaRemoveMaskPath) : ""
    readonly property bool chromaRemoveMaskIsVideo: isVideoPath(chromaRemoveMaskPath)
    readonly property bool chromaRemoveMaskIsImage: isImagePath(chromaRemoveMaskPath)
    readonly property string chromaRemoveFramesPath: chromaRemoveReady ? activeChromaRemoveMaskLayer.cutout_frames_path || "" : ""
    readonly property bool chromaRemoveHasFrameSequence: chromaRemoveFramesPath.length > 0
    readonly property int chromaRemoveFrameIndex: chromaRemoveFrameIndexForLayer(activeChromaRemoveMaskLayer)
    readonly property string chromaRemoveFrameUrl: chromaRemoveFrameUrlForLayerAt(activeChromaRemoveMaskLayer, chromaRemoveFrameIndex)
    property bool seeking: false
    property real previewVolume: 0.85
    property bool previewMuted: false
    property string chromaRemoveDebugSignature: ""

    function extensionFromName(name) {
        var dot = name.lastIndexOf(".")
        return dot >= 0 ? name.slice(dot + 1).toLowerCase() : ""
    }

    function isVideoExtension(extension) {
        return ["mp4", "mov", "mkv", "avi", "webm"].indexOf(extension) >= 0
    }

    function isImageExtension(extension) {
        return ["png", "jpg", "jpeg", "webp", "gif", "bmp"].indexOf(extension) >= 0
    }

    function isVideoPath(path) {
        return isVideoExtension(extensionFromName(path || ""))
    }

    function isImagePath(path) {
        return isImageExtension(extensionFromName(path || ""))
    }

    function sixDigits(value) {
        var text = "" + Math.max(0, value)
        while (text.length < 6) {
            text = "0" + text
        }
        return text
    }

    function pathToUrl(path) {
        var normalized = path.replace(/\\/g, "/")
        if (normalized.indexOf("file://") === 0) {
            return normalized
        }
        return "file:///" + encodeURI(normalized)
    }

    function mediaStatusName(status) {
        if (status === MediaPlayer.NoMedia) return "NoMedia"
        if (status === MediaPlayer.LoadingMedia) return "LoadingMedia"
        if (status === MediaPlayer.LoadedMedia) return "LoadedMedia"
        if (status === MediaPlayer.BufferingMedia) return "BufferingMedia"
        if (status === MediaPlayer.BufferedMedia) return "BufferedMedia"
        if (status === MediaPlayer.StalledMedia) return "StalledMedia"
        if (status === MediaPlayer.EndOfMedia) return "EndOfMedia"
        if (status === MediaPlayer.InvalidMedia) return "InvalidMedia"
        return "Unknown(" + status + ")"
    }

    function playbackStateName(state) {
        if (state === MediaPlayer.StoppedState) return "Stopped"
        if (state === MediaPlayer.PlayingState) return "Playing"
        if (state === MediaPlayer.PausedState) return "Paused"
        return "Unknown(" + state + ")"
    }

    function logChromaRemove(reason) {
        var effectId = activeChromaRemoveEffect ? activeChromaRemoveEffect.id || "" : ""
        var maskId = activeChromaRemoveMaskLayer ? activeChromaRemoveMaskLayer.id || "" : ""
        var signature = [
            reason,
            "mode=" + (compositionMode ? "composition" : "asset"),
            "ready=" + chromaRemoveReady,
            "effect=" + effectId,
            "mask=" + maskId,
            "source=" + (compositionMode ? compositionVideoPath : assetPath),
            "preview=" + chromaRemoveMaskPath,
            "previewVideo=" + chromaRemoveMaskIsVideo,
            "cutout=" + chromaRemoveCutoutPath,
            "cutoutImage=" + chromaRemoveCutoutIsImage,
            "frames=" + chromaRemoveFramesPath,
            "frameSeq=" + chromaRemoveHasFrameSequence,
            "frameUrl=" + chromaRemoveFrameUrl,
            "maskPlayer=" + mediaStatusName(chromaRemoveMaskPlayer.mediaStatus) + "/" + playbackStateName(chromaRemoveMaskPlayer.playbackState),
            "maskError=" + chromaRemoveMaskPlayer.error + ":" + chromaRemoveMaskPlayer.errorString
        ].join(" | ")
        if (signature === chromaRemoveDebugSignature && reason !== "manual") {
            return
        }
        chromaRemoveDebugSignature = signature
        console.log("[VidMake][ChromaRemove] " + signature)
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
            chromaRemoveMaskPlayer.pause()
        } else {
            if (chromaRemoveMaskIsVideo) {
                chromaRemoveMaskPlayer.position = player.position
                chromaRemoveMaskPlayer.play()
            }
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
            if (compositionVideoIsVideo) {
                compositionVideoPlayer.position = loopedPosition(target, compositionVideoPlayer.duration, compositionVideoLoopEnabled)
            }
            if (chromaRemoveMaskIsVideo) {
                chromaRemoveMaskPlayer.position = loopedPositionForLayer(activeChromaRemoveMaskLayer)
            }
        } else {
            player.position = loopedPosition(target, player.duration, assetLoopEnabledForCurrentAsset)
            if (chromaRemoveMaskIsVideo) {
                chromaRemoveMaskPlayer.position = loopedPositionForLayer(activeChromaRemoveMaskLayer)
            }
        }
    }

    function loadCompositionAssets(items) {
        compositionAudioName = ""
        compositionAudioPath = ""
        compositionVisualName = ""
        compositionVisualPath = ""
        compositionVideoName = ""
        compositionVideoPath = ""
        compositionVideoLayerIndex = -1
        var visualAssets = []
        for (var i = 0; i < items.length; i++) {
            var asset = items[i]
            if (asset.kind === "Audio") {
                compositionAudioName = asset.name
                compositionAudioPath = asset.path
            } else if (asset.kind === "Visual") {
                visualAssets.push({ "name": asset.name, "kind": asset.kind, "path": asset.path, "loop": asset.loop || false })
                compositionVisualName = asset.name
                compositionVisualPath = asset.path
                if (visualAssetIsVideo(asset)) {
                    compositionVideoName = asset.name
                    compositionVideoPath = asset.path
                    compositionVideoLayerIndex = visualAssets.length - 1
                }
            }
        }
        compositionVisualAssets = visualAssets
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

    function assetLoopEnabled(path) {
        if (!path || path.length === 0) {
            return false
        }
        for (var i = 0; i < compositionVisualAssets.length; i++) {
            var asset = compositionVisualAssets[i]
            if ((asset.path || "") === path) {
                return asset.loop || false
            }
        }
        return false
    }

    function loopedPosition(position, duration, enabled) {
        if (!enabled || duration <= 0) {
            return Math.max(0, position)
        }
        var wrapped = position % duration
        return wrapped < 0 ? wrapped + duration : wrapped
    }

    function loopedPositionForLayer(layer) {
        if (!layer) {
            return currentPosition
        }
        var fps = Math.max(1.0, layer.frame_rate || 30.0)
        var frameCount = Math.max(1, layer.frame_count || 1)
        var duration = Math.max(1, Math.round(frameCount / fps * 1000.0))
        return loopedPosition(currentPosition, duration, assetLoopEnabled(layer.source_video_path || ""))
    }

    function visualAssetExtension(asset) {
        if (!asset) {
            return ""
        }
        return extensionFromName(asset.name && asset.name.length > 0 ? asset.name : asset.path || "")
    }

    function visualAssetIsVideo(asset) {
        return isVideoExtension(visualAssetExtension(asset))
    }

    function visualAssetIsImage(asset) {
        return isImageExtension(visualAssetExtension(asset))
    }

    function chromaRemoveEffectForPath(path) {
        if (!path || path.length === 0) {
            return null
        }
        for (var i = compositionEffectLayers.length - 1; i >= 0; i--) {
            var effect = compositionEffectLayers[i]
            if (effect.plugin === "builtin.chroma_key_remove" && effect.source_visual_path === path) {
                return effect
            }
        }
        return null
    }

    function chromaRemoveMaskLayerForPath(path) {
        var effect = chromaRemoveEffectForPath(path)
        return effect ? maskLayerById(effect.mask_layer_id || "") : null
    }

    function chromaRemoveReadyForPath(path) {
        var layer = chromaRemoveMaskLayerForPath(path)
        return layer !== null && ((layer.cutout_path || "").length > 0 || (layer.preview_path || "").length > 0)
    }

    function chromaRemoveCutoutUrlForPath(path) {
        var layer = chromaRemoveMaskLayerForPath(path)
        return layer !== null && isImagePath(layer.cutout_path || "") ? pathToUrl(layer.cutout_path) : ""
    }

    function chromaRemoveCutoutIsImageForPath(path) {
        var layer = chromaRemoveMaskLayerForPath(path)
        return layer !== null && isImagePath(layer.cutout_path || "")
    }

    function chromaRemoveCutoutIsVideoForPath(path) {
        var layer = chromaRemoveMaskLayerForPath(path)
        return layer !== null && isVideoPath(layer.cutout_path || "")
    }

    function chromaRemoveMaskUrlForPath(path) {
        var layer = chromaRemoveMaskLayerForPath(path)
        return layer !== null && (layer.preview_path || "").length > 0 ? pathToUrl(layer.preview_path) : ""
    }

    function chromaRemoveMaskIsVideoForPath(path) {
        var layer = chromaRemoveMaskLayerForPath(path)
        return layer !== null && isVideoPath(layer.preview_path || "")
    }

    function chromaRemoveFrameUrlForLayerAt(layer, frameIndex) {
        if (!layer || !(layer.cutout_frames_path || "").length) {
            return ""
        }
        if (frameIndex < 0) {
            return ""
        }
        var basePath = (layer.cutout_frames_path || "").replace(/\\/g, "/")
        return pathToUrl(basePath + "/frame_" + sixDigits(frameIndex) + ".png")
    }

    function chromaRemoveFrameIndexForLayerAtPosition(layer, position) {
        if (!layer || !(layer.cutout_frames_path || "").length) {
            return -1
        }
        var fps = Math.max(1.0, layer.frame_rate || 30.0)
        var frameCount = Math.max(1, layer.frame_count || 1)
        var loopDuration = Math.max(1, Math.round(frameCount / fps * 1000.0))
        var looped = loopedPosition(position, loopDuration, assetLoopEnabled(layer.source_video_path || ""))
        return Math.max(0, Math.min(frameCount - 1, Math.floor((looped / 1000.0) * fps)))
    }

    function chromaRemoveFrameUrlForLayerAtPosition(layer, position) {
        return chromaRemoveFrameUrlForLayerAt(layer, chromaRemoveFrameIndexForLayerAtPosition(layer, position))
    }

    function maskCenterForLayerAtPosition(layer, position) {
        if (!layer) {
            return { "x": 0.5, "y": 0.5 }
        }
        var frameIndex = chromaRemoveFrameIndexForLayerAtPosition(layer, position)
        var centers = layer.frame_mask_centers || []
        if (frameIndex >= 0 && frameIndex < centers.length) {
            var center = centers[frameIndex]
            if ((center.weight || 0) > 0) {
                return {
                    "x": center.center_x === undefined ? layer.mask_center_x || 0.5 : center.center_x,
                    "y": center.center_y === undefined ? layer.mask_center_y || 0.5 : center.center_y
                }
            }
        }
        return { "x": layer.mask_center_x || 0.5, "y": layer.mask_center_y || 0.5 }
    }

    function chromaRemoveFrameUrlForLayer(layer) {
        return chromaRemoveFrameUrlForLayerAt(layer, chromaRemoveFrameIndexForLayer(layer))
    }

    function chromaRemoveFrameIndexForLayer(layer) {
        if (!layer || !(layer.cutout_frames_path || "").length) {
            return -1
        }
        return chromaRemoveFrameIndexForLayerAtPosition(layer, currentPosition)
    }

    function chromaRemoveFrameUrlForPath(path) {
        return chromaRemoveFrameUrlForLayer(chromaRemoveMaskLayerForPath(path))
    }

    function maskBound(name, fallback) {
        if (!zoomBlurUsesMask || !activeZoomBlurMaskLayer.mask_bounds) {
            return fallback
        }
        var value = activeZoomBlurMaskLayer.mask_bounds[name]
        return value === undefined ? fallback : value
    }

    function maskLayerBound(layer, name, fallback) {
        if (!layer || !layer.mask_bounds) {
            return fallback
        }
        var value = layer.mask_bounds[name]
        return value === undefined ? fallback : value
    }

    function zoomBlurBurstScale(index, pulse) {
        var zoomAmount = activeZoomBlurEffect ? activeZoomBlurEffect.zoom_amount : 1.12
        var amount = pulse === undefined ? zoomBlurPulse : pulse
        return 1.0 + (zoomAmount - 1.0) * amount * (1.0 + index * 0.55)
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

    function colorSpreadEffectForCurrentVisual() {
        var targetPath = compositionMode ? compositionVisualPath : assetKind === "Visual" ? assetPath : ""
        if (targetPath.length === 0) {
            return null
        }
        for (var i = compositionEffectLayers.length - 1; i >= 0; i--) {
            var effect = compositionEffectLayers[i]
            if (effect.plugin === "builtin.color_spread" && effect.source_visual_path === targetPath) {
                return effect
            }
        }
        return null
    }

    function chromaRemoveEffectForCurrentVisual() {
        var targetPath = compositionMode ? compositionVisualPath : assetKind === "Visual" ? assetPath : ""
        return chromaRemoveEffectForPath(targetPath)
    }

    function colorSpreadProgressValue() {
        var effect = activeColorSpreadEffect
        if (!effect || !activeColorSpreadMaskLayer) {
            return 0.0
        }
        var durationMs = Math.max(50, effect.spread_duration_seconds * 1000.0)
        var cutoffMs = colorSpreadCutoffMilliseconds(effect)
        if ((effect.trigger_mode || "interval") === "keyframes") {
            var layer = audioKeyframeLayerById(effect.keyframe_layer_id || "")
            if (!layer || !layer.keyframes || layer.keyframes.length === 0) {
                return 0.0
            }
            var nowSeconds = currentPosition / 1000.0
            var cutoffSeconds = cutoffMs / 1000.0
            var latestDelta = -1.0
            for (var i = 0; i < layer.keyframes.length; i++) {
                var timeSeconds = layer.keyframes[i].time_seconds || 0.0
                if (timeSeconds > nowSeconds) {
                    break
                }
                var delta = nowSeconds - timeSeconds
                if (delta <= cutoffSeconds) {
                    latestDelta = delta
                }
            }
            return latestDelta < 0.0 ? 0.0 : Math.max(0.0, Math.min(1.0, latestDelta / (durationMs / 1000.0)))
        }
        var intervalMs = Math.max(50, effect.trigger_interval_seconds * 1000.0)
        var phase = currentPosition % intervalMs
        if (phase > cutoffMs) {
            return 0.0
        }
        return Math.max(0.0, Math.min(1.0, phase / durationMs))
    }

    function colorSpreadCurrentColor() {
        var effect = activeColorSpreadEffect
        if (!effect) {
            return "#00c8ff"
        }
        if ((effect.trigger_mode || "interval") === "keyframes") {
            var layer = audioKeyframeLayerById(effect.keyframe_layer_id || "")
            if (!layer || !layer.keyframes || layer.keyframes.length === 0) {
                return effect.color_1 || "#00c8ff"
            }
            var nowSeconds = currentPosition / 1000.0
            var firedCount = 0
            for (var i = 0; i < layer.keyframes.length; i++) {
                if ((layer.keyframes[i].time_seconds || 0.0) > nowSeconds) {
                    break
                }
                firedCount += 1
            }
            return firedCount % 2 === 1 ? effect.color_1 || "#00c8ff" : effect.color_2 || "#ff4fd8"
        }
        var intervalMs = Math.max(50, effect.trigger_interval_seconds * 1000.0)
        var cycle = Math.floor(currentPosition / intervalMs)
        return cycle % 2 === 0 ? effect.color_1 || "#00c8ff" : effect.color_2 || "#ff4fd8"
    }

    function colorSpreadMaxScale() {
        if (!activeColorSpreadMaskLayer) {
            return 3.0
        }
        var maskWidth = Math.max(1, (maskLayerBound(activeColorSpreadMaskLayer, "max_x", 1.0)
            - maskLayerBound(activeColorSpreadMaskLayer, "min_x", 0.0)) * frame.width)
        var maskHeight = Math.max(1, (maskLayerBound(activeColorSpreadMaskLayer, "max_y", 1.0)
            - maskLayerBound(activeColorSpreadMaskLayer, "min_y", 0.0)) * frame.height)
        return Math.max(2.0, Math.max(frame.width / maskWidth, frame.height / maskHeight) * 1.35)
    }

    function colorSpreadSilhouetteScaleForProgress(progress) {
        return 1.0 + (colorSpreadMaxScale() - 1.0) * Math.max(0.0, Math.min(1.0, progress))
    }

    function colorSpreadCutoffMilliseconds(effect) {
        var durationSeconds = effect.spread_duration_seconds || 0.8
        var cutoffSeconds = effect.spread_cutoff_seconds === undefined ? durationSeconds : effect.spread_cutoff_seconds
        return Math.max(50, cutoffSeconds * 1000.0)
    }

    function colorSpreadBurstModel() {
        var effect = activeColorSpreadEffect
        if (!effect || !activeColorSpreadMaskLayer) {
            return []
        }
        var fallbackMaskUrl = isImagePath(colorSpreadMaskPath) ? pathToUrl(colorSpreadMaskPath) : colorSpreadMaskUrl
        function maskUrlAt(triggerMilliseconds) {
            var frameUrl = chromaRemoveFrameUrlForLayerAtPosition(activeColorSpreadMaskLayer, triggerMilliseconds)
            return frameUrl.length > 0 ? frameUrl : fallbackMaskUrl
        }
        function burstCenterAt(triggerMilliseconds) {
            return maskCenterForLayerAtPosition(activeColorSpreadMaskLayer, triggerMilliseconds)
        }
        if (!effect.finish_spread) {
            var currentProgress = colorSpreadProgressValue()
            if (currentProgress <= 0.0) {
                return []
            }
            var triggerMs = currentPosition
            if ((effect.trigger_mode || "interval") === "keyframes") {
                var keyframeLayer = audioKeyframeLayerById(effect.keyframe_layer_id || "")
                if (keyframeLayer && keyframeLayer.keyframes) {
                    var nowSeconds = currentPosition / 1000.0
                    for (var keyframeIndex = 0; keyframeIndex < keyframeLayer.keyframes.length; keyframeIndex++) {
                        var keyframeTime = keyframeLayer.keyframes[keyframeIndex].time_seconds || 0.0
                        if (keyframeTime > nowSeconds) {
                            break
                        }
                        triggerMs = Math.round(keyframeTime * 1000.0)
                    }
                }
            } else {
                var singleIntervalMs = Math.max(50, effect.trigger_interval_seconds * 1000.0)
                triggerMs = Math.floor(currentPosition / singleIntervalMs) * singleIntervalMs
            }
            return [{
                "progress": currentProgress,
                "color": colorSpreadCurrentColor(),
                "maskUrl": maskUrlAt(triggerMs),
                "originX": burstCenterAt(triggerMs).x,
                "originY": burstCenterAt(triggerMs).y
            }]
        }

        var durationMs = Math.max(50, effect.spread_duration_seconds * 1000.0)
        var cutoffMs = colorSpreadCutoffMilliseconds(effect)
        var durationSeconds = durationMs / 1000.0
        var cutoffSeconds = cutoffMs / 1000.0
        var nowSeconds = currentPosition / 1000.0
        var bursts = []
        if ((effect.trigger_mode || "interval") === "keyframes") {
            var layer = audioKeyframeLayerById(effect.keyframe_layer_id || "")
            if (!layer || !layer.keyframes || layer.keyframes.length === 0) {
                return []
            }
            for (var i = 0; i < layer.keyframes.length; i++) {
                var timeSeconds = layer.keyframes[i].time_seconds || 0.0
                if (timeSeconds > nowSeconds) {
                    break
                }
                var delta = nowSeconds - timeSeconds
                if (delta <= cutoffSeconds) {
                    var triggerMs = Math.round(timeSeconds * 1000.0)
                    bursts.push({
                        "progress": Math.max(0.0, Math.min(1.0, delta / durationSeconds)),
                        "color": i % 2 === 0 ? effect.color_1 || "#00c8ff" : effect.color_2 || "#ff4fd8",
                        "maskUrl": maskUrlAt(triggerMs),
                        "originX": burstCenterAt(triggerMs).x,
                        "originY": burstCenterAt(triggerMs).y
                    })
                }
            }
            return bursts
        }

        var intervalMs = Math.max(50, effect.trigger_interval_seconds * 1000.0)
        var currentCycle = Math.floor(currentPosition / intervalMs)
        var lookbackCycles = Math.ceil(cutoffMs / intervalMs)
        for (var cycle = Math.max(0, currentCycle - lookbackCycles); cycle <= currentCycle; cycle++) {
            var triggerMs = cycle * intervalMs
            var ageMs = currentPosition - triggerMs
            if (ageMs >= 0 && ageMs <= cutoffMs) {
                bursts.push({
                    "progress": Math.max(0.0, Math.min(1.0, ageMs / durationMs)),
                    "color": cycle % 2 === 0 ? effect.color_1 || "#00c8ff" : effect.color_2 || "#ff4fd8",
                    "maskUrl": maskUrlAt(triggerMs),
                    "originX": burstCenterAt(triggerMs).x,
                    "originY": burstCenterAt(triggerMs).y
                })
            }
        }
        return bursts
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

    function zoomBlurBurstModel() {
        var effect = activeZoomBlurEffect
        if (!effect || !activeZoomBlurMaskLayer) {
            return []
        }
        var fallbackMaskUrl = isImagePath(zoomBlurCutoutPath) ? pathToUrl(zoomBlurCutoutPath) : zoomBlurCutoutUrl
        function maskUrlAt(triggerMilliseconds) {
            var frameUrl = chromaRemoveFrameUrlForLayerAtPosition(activeZoomBlurMaskLayer, triggerMilliseconds)
            return frameUrl.length > 0 ? frameUrl : fallbackMaskUrl
        }
        function burstAt(triggerMilliseconds, pulse) {
            var center = maskCenterForLayerAtPosition(activeZoomBlurMaskLayer, triggerMilliseconds)
            return {
                "pulse": Math.max(0.0, Math.min(1.0, pulse)),
                "maskUrl": maskUrlAt(triggerMilliseconds),
                "originX": center.x,
                "originY": center.y
            }
        }

        if ((effect.trigger_mode || "interval") === "keyframes") {
            var layer = audioKeyframeLayerById(effect.keyframe_layer_id || "")
            if (!layer || !layer.keyframes || layer.keyframes.length === 0) {
                return []
            }
            var nowSeconds = currentPosition / 1000.0
            var attackSeconds = 0.06
            var releaseSeconds = 0.28
            var bestPulse = 0.0
            var bestTriggerMs = -1
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
                pulse *= Math.max(0.0, Math.min(1.0, keyframe.value || 1.0))
                if (pulse > bestPulse) {
                    bestPulse = pulse
                    bestTriggerMs = Math.round(timeSeconds * 1000.0)
                }
            }
            return bestPulse > 0.01 && bestTriggerMs >= 0 ? [burstAt(bestTriggerMs, bestPulse)] : []
        }

        var intervalMs = Math.max(50, effect.trigger_interval_seconds * 1000.0)
        var phase = currentPosition % intervalMs
        var attackMs = Math.min(120, intervalMs * 0.25)
        var releaseMs = Math.min(420, intervalMs * 0.75)
        var pulseValue = 0.0
        if (phase <= attackMs) {
            pulseValue = phase / Math.max(1, attackMs)
        } else if (phase <= attackMs + releaseMs) {
            pulseValue = 1.0 - ((phase - attackMs) / Math.max(1, releaseMs))
        }
        if (pulseValue <= 0.01) {
            return []
        }
        return [burstAt(Math.floor(currentPosition / intervalMs) * intervalMs, pulseValue)]
    }

    function stopComposition() {
        compositionAudioPlayer.stop()
        compositionVideoPlayer.stop()
        chromaRemoveMaskPlayer.stop()
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
            chromaRemoveMaskPlayer.pause()
            return
        }
        if (compositionVideoIsVideo) {
            compositionVideoPlayer.play()
        }
        if (chromaRemoveMaskIsVideo) {
            chromaRemoveMaskPlayer.position = root.currentPosition
            chromaRemoveMaskPlayer.play()
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
        chromaRemoveMaskPlayer.stop()
        player.position = 0
    }

    onChromaRemoveReadyChanged: logChromaRemove("readyChanged")
    onChromaRemoveMaskPathChanged: logChromaRemove("maskPathChanged")
    onChromaRemoveCutoutPathChanged: logChromaRemove("cutoutPathChanged")
    onChromaRemoveMaskIsVideoChanged: logChromaRemove("maskTypeChanged")
    onCompositionModeChanged: logChromaRemove("modeChanged")

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
        loops: root.assetLoopEnabledForCurrentAsset ? MediaPlayer.Infinite : 1
        onPositionChanged: {
            if (!root.seeking && !root.compositionMode) {
                scrubber.value = player.position
            }
            var maskPosition = root.loopedPositionForLayer(root.activeChromaRemoveMaskLayer)
            if (!root.compositionMode && root.chromaRemoveMaskIsVideo && Math.abs(chromaRemoveMaskPlayer.position - maskPosition) > 120) {
                chromaRemoveMaskPlayer.position = maskPosition
            }
        }
        onDurationChanged: scrubber.value = 0
        onMediaStatusChanged: root.logChromaRemove("sourceStatusChanged:" + root.mediaStatusName(mediaStatus))
        onErrorOccurred: function(error, errorString) {
            console.log("[VidMake][ChromaRemove] sourcePlayerError | error=" + error + " | message=" + errorString)
        }
    }

    MediaPlayer {
        id: chromaRemoveMaskPlayer
        source: root.chromaRemoveMaskIsVideo ? root.chromaRemoveMaskUrl : ""
        videoOutput: chromaRemoveMaskVideoOutput
        loops: root.assetLoopEnabled((root.activeChromaRemoveMaskLayer && root.activeChromaRemoveMaskLayer.source_video_path) || "") ? MediaPlayer.Infinite : 1
        audioOutput: AudioOutput {
            muted: true
        }
        onSourceChanged: root.logChromaRemove("maskSourceChanged")
        onMediaStatusChanged: root.logChromaRemove("maskStatusChanged:" + root.mediaStatusName(mediaStatus))
        onPlaybackStateChanged: root.logChromaRemove("maskPlaybackChanged:" + root.playbackStateName(playbackState))
        onErrorOccurred: function(error, errorString) {
            console.log("[VidMake][ChromaRemove] maskPlayerError | error=" + error + " | message=" + errorString + " | source=" + source)
        }
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
        source: root.compositionVideoIsVideo ? root.compositionVideoUrl : ""
        audioOutput: compositionVideoAudioOutput
        videoOutput: compositionVideoOutput
        loops: root.compositionVideoLoopEnabled ? MediaPlayer.Infinite : 1
        onPositionChanged: {
            if (!root.seeking && root.compositionMode && root.compositionAudioPath.length === 0) {
                scrubber.value = compositionVideoPlayer.position
            }
            var maskPosition = root.loopedPositionForLayer(root.activeChromaRemoveMaskLayer)
            if (root.compositionMode && root.chromaRemoveMaskIsVideo && Math.abs(chromaRemoveMaskPlayer.position - maskPosition) > 120) {
                chromaRemoveMaskPlayer.position = maskPosition
            }
        }
        onMediaStatusChanged: root.logChromaRemove("compositionVideoStatusChanged:" + root.mediaStatusName(mediaStatus))
        onErrorOccurred: function(error, errorString) {
            console.log("[VidMake][ChromaRemove] compositionVideoError | error=" + error + " | message=" + errorString)
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
                        visible: !root.compositionMode
                            && root.isVideo
                            && (!root.chromaRemoveReady || (root.chromaRemoveMaskIsVideo && !root.chromaRemoveHasFrameSequence))
                    }

                    VideoOutput {
                        id: compositionVideoOutput
                        anchors.fill: parent
                        fillMode: VideoOutput.PreserveAspectFit
                        z: Math.max(0, root.compositionVideoLayerIndex)
                        visible: root.compositionMode
                            && root.compositionVideoIsVideo
                            && (!root.chromaRemoveReadyForPath(root.compositionVideoPath)
                                || (root.chromaRemoveMaskIsVideo && !root.chromaRemoveHasFrameSequence))
                    }

                    VideoOutput {
                        id: chromaRemoveMaskVideoOutput
                        anchors.fill: parent
                        anchors.margins: 12
                        fillMode: VideoOutput.PreserveAspectFit
                        visible: root.chromaRemoveReady && root.chromaRemoveMaskIsVideo && !root.chromaRemoveHasFrameSequence
                    }

                    ShaderEffectSource {
                        id: chromaRemoveSourceTexture
                        sourceItem: root.compositionMode ? compositionVideoOutput : assetVideoOutput
                        live: true
                        recursive: true
                        hideSource: root.chromaRemoveReady && root.chromaRemoveMaskIsVideo && !root.chromaRemoveHasFrameSequence
                        visible: false
                    }

                    ShaderEffectSource {
                        id: chromaRemoveMaskTexture
                        sourceItem: chromaRemoveMaskVideoOutput
                        live: true
                        recursive: true
                        hideSource: root.chromaRemoveReady && root.chromaRemoveMaskIsVideo && !root.chromaRemoveHasFrameSequence
                        visible: false
                    }

                    ShaderEffect {
                        id: chromaRemoveShaderItem
                        anchors.fill: parent
                        anchors.margins: 12
                        z: root.compositionMode ? Math.max(0, root.compositionVideoLayerIndex) : 0
                        property variant source: chromaRemoveSourceTexture
                        property variant maskSource: chromaRemoveMaskTexture
                        fragmentShader: Qt.resolvedUrl("../shaders/luma_mask.frag.qsb")
                        visible: root.chromaRemoveReady && root.chromaRemoveMaskIsVideo && !root.chromaRemoveHasFrameSequence
                        onVisibleChanged: root.logChromaRemove("shaderVisibleChanged")
                        Component.onCompleted: root.logChromaRemove("shaderCompleted")
                    }

                    Repeater {
                        model: root.compositionMode ? root.compositionVisualAssets : []

                        Image {
                            required property var modelData
                            required property int index
                            anchors.fill: parent
                            anchors.margins: 12
                            z: index
                            source: root.visualAssetIsImage(modelData) && !root.chromaRemoveReadyForPath(modelData.path)
                                ? root.pathToUrl(modelData.path)
                                : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            visible: source.toString().length > 0
                        }
                    }

                    Item {
                        anchors.fill: parent
                        visible: root.colorSpreadReady && root.colorSpreadHasMaskImage && root.colorSpreadBursts.length > 0

                        Repeater {
                            model: root.colorSpreadBursts

                            Item {
                                id: colorSpreadBurst
                                required property var modelData
                                readonly property real burstProgress: modelData.progress || 0.0
                                readonly property string burstColor: modelData.color || root.colorSpreadColor
                                readonly property string burstMaskUrl: modelData.maskUrl || root.colorSpreadMaskUrl
                                readonly property real burstOriginX: modelData.originX === undefined ? root.colorSpreadOriginX : modelData.originX
                                readonly property real burstOriginY: modelData.originY === undefined ? root.colorSpreadOriginY : modelData.originY
                                anchors.fill: parent

                                Item {
                                    id: colorSpreadSilhouette
                                    anchors.fill: parent
                                    opacity: 0.72
                                    transform: Scale {
                                        origin.x: colorSpreadSilhouette.width * colorSpreadBurst.burstOriginX
                                        origin.y: colorSpreadSilhouette.height * colorSpreadBurst.burstOriginY
                                        xScale: root.colorSpreadSilhouetteScaleForProgress(colorSpreadBurst.burstProgress)
                                        yScale: root.colorSpreadSilhouetteScaleForProgress(colorSpreadBurst.burstProgress)
                                    }

                                    Image {
                                        id: silhouetteMask
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        source: colorSpreadBurst.burstMaskUrl
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: false
                                        cache: true
                                        visible: false
                                    }

                                    ColorOverlay {
                                        anchors.fill: silhouetteMask
                                        source: silhouetteMask
                                        color: colorSpreadBurst.burstColor
                                    }
                                }

                            }
                        }
                    }

                    Repeater {
                        model: root.compositionMode ? root.compositionVisualAssets : []

                        Image {
                            required property var modelData
                            required property int index
                            anchors.fill: parent
                            anchors.margins: 12
                            z: index
                            readonly property string chromaFrameUrl: root.chromaRemoveFrameUrlForPath(modelData.path)
                            source: chromaFrameUrl.length > 0
                                ? chromaFrameUrl
                                : root.chromaRemoveCutoutUrlForPath(modelData.path)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: false
                            cache: true
                            visible: source.toString().length > 0
                        }
                    }

                    Image {
                        anchors.fill: parent
                        anchors.margins: 12
                        source: !root.compositionMode && root.isImage ? root.mediaUrl : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        visible: !root.chromaRemoveReady && source.toString().length > 0
                    }

                    Image {
                        anchors.fill: parent
                        anchors.margins: 12
                        source: root.chromaRemoveFrameUrl.length > 0 ? root.chromaRemoveFrameUrl : root.chromaRemoveCutoutUrl
                        fillMode: Image.PreserveAspectFit
                        asynchronous: false
                        cache: true
                        visible: root.chromaRemoveReady && (root.chromaRemoveHasFrameSequence || root.chromaRemoveCutoutIsImage)
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 14
                        visible: root.compositionMode
                            ? root.compositionVisualAssets.length === 0
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
                    visible: root.zoomBlurMaskMode && root.zoomBlurBursts.length > 0
                    opacity: Math.min(1.0, 0.38 + root.zoomBlurOpacity)

                    Repeater {
                        model: root.zoomBlurBursts

                        Item {
                            id: zoomBlurBurst
                            required property var modelData
                            anchors.fill: parent
                            readonly property real burstPulse: modelData.pulse || 0.0
                            readonly property string burstMaskUrl: modelData.maskUrl || root.zoomBlurCutoutUrl
                            readonly property real burstOriginX: modelData.originX === undefined ? root.zoomBlurOriginX : modelData.originX
                            readonly property real burstOriginY: modelData.originY === undefined ? root.zoomBlurOriginY : modelData.originY

                            Repeater {
                                model: zoomBlurBurst.burstMaskUrl.length > 0 ? 5 : 0

                                Image {
                                    id: maskedFrameBurst
                                    required property int index
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    source: zoomBlurBurst.burstMaskUrl
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: false
                                    cache: true
                                    opacity: Math.max(0.0, 0.55 - index * 0.09) * zoomBlurBurst.burstPulse
                                    transform: Scale {
                                        origin.x: maskedFrameBurst.width * zoomBlurBurst.burstOriginX
                                        origin.y: maskedFrameBurst.height * zoomBlurBurst.burstOriginY
                                        xScale: root.zoomBlurBurstScale(maskedFrameBurst.index, zoomBlurBurst.burstPulse)
                                        yScale: root.zoomBlurBurstScale(maskedFrameBurst.index, zoomBlurBurst.burstPulse)
                                    }
                                }
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
