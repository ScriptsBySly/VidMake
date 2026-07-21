import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

Dialog {
    id: root
    property string videoName: ""
    property string videoPath: ""
    property bool analyzing: false
    property bool pickingColor: false
    property color keyColor: "#00ff00"
    property bool inverted: false
    property var analysisResult: ({})
    readonly property string videoUrl: videoPath.length > 0 ? pathToUrl(videoPath) : ""
    readonly property bool canPreview: videoPath.length > 0
    readonly property string assetExtension: extensionFromName(videoName.length > 0 ? videoName : videoPath)
    readonly property bool isImage: ["png", "jpg", "jpeg", "webp", "bmp"].indexOf(assetExtension) >= 0
    readonly property bool isVideo: ["mp4", "mov", "mkv", "avi"].indexOf(assetExtension) >= 0
    readonly property string resultExtension: extensionFromName(analysisResult.preview_path || "")
    readonly property bool resultIsVideo: ["mp4", "mov", "mkv", "avi", "webm"].indexOf(resultExtension) >= 0
    readonly property bool canSaveMask: !!analysisResult.preview_path && !analyzing
    signal maskLayerCreated(string layerJson)

    title: "Visual Analysis"
    modal: false
    standardButtons: Dialog.Close
    width: 980
    height: 680

    function pathToUrl(path) {
        var normalized = path.replace(/\\/g, "/")
        if (normalized.indexOf("file://") === 0) {
            return normalized
        }
        return "file:///" + encodeURI(normalized)
    }

    function extensionFromName(name) {
        var dot = name.lastIndexOf(".")
        return dot >= 0 ? name.slice(dot + 1).toLowerCase() : ""
    }

    function colorToHex(value) {
        var r = Math.round(value.r * 255)
        var g = Math.round(value.g * 255)
        var b = Math.round(value.b * 255)
        return "#" + hexByte(r) + hexByte(g) + hexByte(b)
    }

    function hexByte(value) {
        var text = Math.max(0, Math.min(255, value)).toString(16)
        return text.length === 1 ? "0" + text : text
    }

    function formatMilliseconds(milliseconds) {
        var total = Math.max(0, Math.floor(milliseconds / 1000))
        var minutes = Math.floor(total / 60)
        var seconds = total % 60
        return (minutes < 10 ? "0" + minutes : "" + minutes) + ":" + (seconds < 10 ? "0" + seconds : "" + seconds)
    }

    function analyzeMask() {
        var settings = {
            "key_color": colorToHex(keyColor),
            "tolerance": toleranceSlider.value,
            "inverted": inverted,
            "preview_time_ms": root.isVideo ? videoPlayer.position : 0
        }
        videoAnalysisController.analyze(videoPath, JSON.stringify(settings))
    }

    function sampleAt(x, y) {
        var sampled = videoAnalysisController.sampleColor(
            videoPath,
            root.isVideo ? videoPlayer.position : 0,
            Math.max(0, Math.min(1, x / Math.max(1, videoSurface.width))),
            Math.max(0, Math.min(1, y / Math.max(1, videoSurface.height)))
        )
        if (sampled.length > 0) {
            keyColor = sampled
            pickingColor = false
        }
    }

    function createMaskLayer() {
        if (!canSaveMask) {
            return
        }
        var settings = analysisResult.settings || {}
        var layer = {
            "id": "mask-" + Date.now(),
            "name": "Chroma mask - " + videoName,
            "source_video_name": videoName,
            "source_video_path": videoPath,
            "source_type": analysisResult.source_type || (root.isImage ? "image" : "video"),
            "key_color": settings.key_color || colorToHex(keyColor),
            "tolerance": settings.tolerance || toleranceSlider.value,
            "inverted": settings.inverted || false,
            "preview_path": analysisResult.preview_path || "",
            "cutout_path": analysisResult.cutout_path || "",
            "cutout_frames_path": analysisResult.cutout_frames_path || "",
            "frame_rate": analysisResult.frame_rate || 0,
            "frame_count": analysisResult.frame_count || 0,
            "mask_center_x": analysisResult.mask_center_x || 0.5,
            "mask_center_y": analysisResult.mask_center_y || 0.5,
            "mask_bounds": analysisResult.mask_bounds || {
                "min_x": 0.0,
                "min_y": 0.0,
                "max_x": 1.0,
                "max_y": 1.0
            }
        }
        root.maskLayerCreated(JSON.stringify(layer))
    }

    onVideoUrlChanged: {
        videoPlayer.stop()
        analysisResult = {}
    }

    Connections {
        target: videoAnalysisController
        function onAnalysisStarted() {
            root.analyzing = true
        }
        function onAnalysisFinished(resultJson) {
            root.analyzing = false
            root.analysisResult = JSON.parse(resultJson)
        }
        function onAnalysisFailed(message) {
            root.analyzing = false
            root.analysisResult = { "error": message }
        }
    }

    MediaPlayer {
        id: videoPlayer
        source: root.videoUrl
        videoOutput: videoOutput
        audioOutput: AudioOutput {
            muted: true
        }
        onPositionChanged: {
            scrubber.value = position
            if (root.resultIsVideo && Math.abs(maskPreviewPlayer.position - position) > 120) {
                maskPreviewPlayer.position = position
            }
        }
        onDurationChanged: scrubber.value = 0
    }

    MediaPlayer {
        id: maskPreviewPlayer
        source: root.resultIsVideo ? analysisResult.preview_url || "" : ""
        videoOutput: maskPreviewOutput
        audioOutput: AudioOutput {
            muted: true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    text: root.videoName.length > 0 ? root.videoName : "No visual selected"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }

                Text {
                    text: root.videoPath.length > 0 ? root.videoPath : "Import or select an image/video asset first"
                    color: Theme.subtleText
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }

            PillButton {
                text: root.analyzing ? "Analyzing" : "Analyze"
                iconText: "\uE9D9"
                accent: true
                enabled: root.canPreview && !root.analyzing
                onClicked: root.analyzeMask()
            }

            PillButton {
                text: "Save Mask"
                iconText: "\uE74E"
                enabled: root.canSaveMask
                onClicked: root.createMaskLayer()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 286
                Layout.fillHeight: true
                radius: 8
                color: Theme.surfaceRaised
                border.color: Theme.stroke

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Text {
                        text: "Chroma key"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 34
                            radius: 6
                            color: root.keyColor
                            border.color: Theme.strokeStrong
                        }

                        Text {
                            text: root.colorToHex(root.keyColor)
                            color: Theme.text
                            font.family: Theme.monoFamily
                            font.pixelSize: 12
                            Layout.fillWidth: true
                        }

                        IconButton {
                            iconText: "\uE8B3"
                            tooltip: root.pickingColor ? "Click video to pick color" : "Pick chroma key color"
                            accented: root.pickingColor
                            onClicked: root.pickingColor = !root.pickingColor
                        }
                    }

                    Text {
                        text: "Tolerance " + toleranceSlider.value.toFixed(2)
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    Slider {
                        id: toleranceSlider
                        Layout.fillWidth: true
                        from: 0.02
                        to: 0.8
                        value: 0.28
                    }

                    PillButton {
                        text: root.inverted ? "Invert On" : "Invert Off"
                        iconText: "\uE7AD"
                        accent: root.inverted
                        Layout.fillWidth: true
                        onClicked: {
                            root.inverted = !root.inverted
                            if (analysisResult.preview_path) {
                                root.analyzeMask()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.stroke
                    }

                    Text {
                        Layout.fillWidth: true
                        text: analysisResult.error
                            ? analysisResult.error
                            : analysisResult.preview_path
                                ? (analysisResult.source_type === "image" ? "Image " : "Video ")
                                    + analysisResult.width + " x " + analysisResult.height + "\n"
                                    + "Kept " + Math.round((analysisResult.kept_ratio || 0) * 100) + "%\n"
                                    + "Transparent " + Math.round((analysisResult.transparent_ratio || 0) * 100) + "%\n"
                                    + "Origin " + Math.round((analysisResult.mask_center_x || 0.5) * 100) + "%, "
                                    + Math.round((analysisResult.mask_center_y || 0.5) * 100) + "%"
                                : "Preview a visual, pick a key color, then analyze."
                        color: analysisResult.error ? "#b91c1c" : Theme.subtleText
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    IconButton {
                        iconText: videoPlayer.playbackState === MediaPlayer.PlayingState ? "\uE769" : "\uE768"
                        tooltip: videoPlayer.playbackState === MediaPlayer.PlayingState ? "Pause video preview" : "Play video preview"
                        accented: true
                        enabled: root.canPreview && root.isVideo
                        onClicked: {
                            if (videoPlayer.playbackState === MediaPlayer.PlayingState) {
                                videoPlayer.pause()
                                maskPreviewPlayer.pause()
                            } else {
                                videoPlayer.play()
                                if (root.resultIsVideo) {
                                    maskPreviewPlayer.position = videoPlayer.position
                                    maskPreviewPlayer.play()
                                }
                            }
                        }
                    }

                    Slider {
                        id: scrubber
                        Layout.fillWidth: true
                        from: 0
                        to: Math.max(1, videoPlayer.duration)
                        enabled: root.canPreview && root.isVideo && videoPlayer.duration > 0
                        onMoved: {
                            videoPlayer.position = value
                            if (root.resultIsVideo) {
                                maskPreviewPlayer.position = value
                            }
                        }
                    }

                    Text {
                        text: root.isVideo
                            ? root.formatMilliseconds(videoPlayer.position) + " / " + root.formatMilliseconds(videoPlayer.duration)
                            : "Image"
                        color: Theme.subtleText
                        font.family: Theme.monoFamily
                        font.pixelSize: 12
                        Layout.preferredWidth: 92
                        horizontalAlignment: Text.AlignRight
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                    Rectangle {
                        id: videoSurface
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: "#111113"
                        border.color: root.pickingColor ? Theme.accent : Theme.strokeStrong
                        clip: true

                        VideoOutput {
                            id: videoOutput
                            anchors.fill: parent
                            anchors.margins: 10
                            fillMode: VideoOutput.PreserveAspectFit
                            visible: root.isVideo
                        }

                        Image {
                            anchors.fill: parent
                            anchors.margins: 10
                            source: root.isImage ? root.videoUrl : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            visible: root.isImage
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !root.canPreview
                            text: "Select an image or video asset"
                            color: "#a9adb7"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: root.pickingColor && root.canPreview
                            cursorShape: Qt.CrossCursor
                            onClicked: function(mouse) {
                                root.sampleAt(mouse.x, mouse.y)
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: "#111113"
                        border.color: Theme.strokeStrong
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: 10
                            source: !root.resultIsVideo ? analysisResult.preview_url || "" : ""
                            cache: false
                            fillMode: Image.PreserveAspectFit
                            visible: source.toString().length > 0
                        }

                        VideoOutput {
                            id: maskPreviewOutput
                            anchors.fill: parent
                            anchors.margins: 10
                            fillMode: VideoOutput.PreserveAspectFit
                            visible: root.resultIsVideo
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !root.analyzing && !analysisResult.preview_url && !analysisResult.error
                            text: "Mask preview appears here"
                            color: "#a9adb7"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }

                        BusyIndicator {
                            anchors.centerIn: parent
                            running: root.analyzing
                            visible: root.analyzing
                        }
                    }
                }
            }
        }
    }
}
