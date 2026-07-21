import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

Dialog {
    id: root
    property string audioName: ""
    property string audioPath: ""
    property int projectFrameRate: 30
    property bool analyzing: false
    property var analysisResult: ({})
    property var ranges: JSON.parse(audioAnalysisController.suggestedRangesJson())
    property int selectedRangeIndex: 1
    property bool seeking: false
    readonly property string audioUrl: audioPath.length > 0 ? pathToUrl(audioPath) : ""
    readonly property bool canPlay: audioPath.length > 0 && !analyzing
    readonly property bool isPlaying: analysisPlayer.playbackState === MediaPlayer.PlayingState

    title: "Audio Analysis"
    modal: false
    standardButtons: Dialog.Close
    width: 940
    height: 640

    function selectedRange() {
        return ranges[Math.max(0, selectedRangeIndex)]
    }

    function analyzeSelectedRange() {
        var range = selectedRange()
        var settings = {
            "band_name": range.name,
            "low_hz": range.low_hz,
            "high_hz": range.high_hz,
            "threshold": thresholdSlider.value,
            "min_interval_ms": Math.round(minGapSlider.value),
            "sensitivity": sensitivitySlider.value,
            "frame_rate": projectFrameRate
        }
        audioAnalysisController.analyze(audioPath, JSON.stringify(settings))
    }

    function pathToUrl(path) {
        var normalized = path.replace(/\\/g, "/")
        if (normalized.indexOf("file://") === 0) {
            return normalized
        }
        return "file:///" + encodeURI(normalized)
    }

    function formatTime(seconds) {
        var total = Math.max(0, Math.floor(seconds))
        var minutes = Math.floor(total / 60)
        var secs = total % 60
        return (minutes < 10 ? "0" + minutes : "" + minutes) + ":" + (secs < 10 ? "0" + secs : "" + secs)
    }

    function formatMilliseconds(milliseconds) {
        return formatTime(milliseconds / 1000)
    }

    function togglePlayback() {
        if (!canPlay) {
            return
        }
        if (analysisPlayer.playbackState === MediaPlayer.PlayingState) {
            analysisPlayer.pause()
        } else {
            analysisPlayer.play()
        }
    }

    function seekTo(milliseconds) {
        if (!canPlay) {
            return
        }
        analysisPlayer.position = Math.max(0, Math.min(Math.max(1, analysisPlayer.duration), milliseconds))
    }

    onAudioUrlChanged: {
        analysisPlayer.stop()
        analysisPlayer.position = 0
        markerModel.clear()
        analysisResult = {}
        waveformCanvas.requestPaint()
    }

    Connections {
        target: audioAnalysisController
        function onAnalysisStarted() {
            root.analyzing = true
        }
        function onAnalysisFinished(resultJson) {
            root.analyzing = false
            root.analysisResult = JSON.parse(resultJson)
            markerModel.clear()
            var markers = root.analysisResult.markers || []
            for (var i = 0; i < markers.length; i++) {
                markerModel.append(markers[i])
            }
            waveformCanvas.requestPaint()
        }
        function onAnalysisFailed(message) {
            root.analyzing = false
            root.analysisResult = { "error": message }
            markerModel.clear()
            waveformCanvas.requestPaint()
        }
    }

    AudioOutput {
        id: analysisAudioOutput
        volume: volumeSlider.value
        muted: muteButton.checked
    }

    MediaPlayer {
        id: analysisPlayer
        source: root.audioUrl
        audioOutput: analysisAudioOutput
        onPositionChanged: {
            if (!root.seeking) {
                playbackSlider.value = position
            }
            waveformCanvas.requestPaint()
        }
        onDurationChanged: {
            playbackSlider.value = 0
            waveformCanvas.requestPaint()
        }
    }

    Timer {
        interval: 50
        repeat: true
        running: root.isPlaying
        onTriggered: waveformCanvas.requestPaint()
    }

    ListModel {
        id: markerModel
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
                    text: root.audioName.length > 0 ? root.audioName : "No audio selected"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }

                Text {
                    text: root.audioPath.length > 0 ? root.audioPath : "Import an audio asset first"
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
                enabled: root.audioPath.length > 0 && !root.analyzing
                onClicked: root.analyzeSelectedRange()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 284
                Layout.fillHeight: true
                radius: 8
                color: Theme.surfaceRaised
                border.color: Theme.stroke

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Text {
                        text: "Frequency range"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    ComboBox {
                        Layout.fillWidth: true
                        textRole: "name"
                        valueRole: "name"
                        model: root.ranges
                        currentIndex: root.selectedRangeIndex
                        onActivated: root.selectedRangeIndex = currentIndex
                    }

                    Text {
                        text: {
                            var range = root.selectedRange()
                            return range.low_hz + " Hz - " + range.high_hz + " Hz"
                        }
                        color: Theme.subtleText
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    Text {
                        text: "Threshold " + thresholdSlider.value.toFixed(2)
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    Slider {
                        id: thresholdSlider
                        Layout.fillWidth: true
                        from: 0.05
                        to: 0.95
                        value: 0.45
                    }

                    Text {
                        text: "Sensitivity " + sensitivitySlider.value.toFixed(2)
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    Slider {
                        id: sensitivitySlider
                        Layout.fillWidth: true
                        from: 0.25
                        to: 3
                        value: 1
                    }

                    Text {
                        text: "Minimum spacing " + Math.round(minGapSlider.value) + " ms"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    Slider {
                        id: minGapSlider
                        Layout.fillWidth: true
                        from: 40
                        to: 600
                        value: 120
                        stepSize: 10
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
                            : "Tempo " + (analysisResult.tempo_bpm || 0) + " BPM\n"
                                + "Global beats " + (analysisResult.beat_count || 0) + "\n"
                                + "Filtered markers " + (analysisResult.detected_beat_count || 0)
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
                        iconText: root.isPlaying ? "\uE769" : "\uE768"
                        tooltip: root.isPlaying ? "Pause analysis preview" : "Play analysis preview"
                        accented: true
                        enabled: root.canPlay
                        onClicked: root.togglePlayback()
                    }

                    Slider {
                        id: playbackSlider
                        Layout.fillWidth: true
                        from: 0
                        to: Math.max(1, analysisPlayer.duration)
                        enabled: root.canPlay && analysisPlayer.duration > 0
                        onPressedChanged: {
                            root.seeking = pressed
                            if (!pressed) {
                                root.seekTo(value)
                            }
                        }
                        onMoved: root.seekTo(value)
                    }

                    Text {
                        text: root.formatMilliseconds(analysisPlayer.position) + " / " + root.formatMilliseconds(analysisPlayer.duration)
                        color: Theme.subtleText
                        font.family: Theme.monoFamily
                        font.pixelSize: 12
                        Layout.preferredWidth: 92
                        horizontalAlignment: Text.AlignRight
                    }

                    IconButton {
                        id: muteButton
                        checkable: true
                        iconText: checked || volumeSlider.value === 0 ? "\uE74F" : "\uE767"
                        tooltip: checked ? "Unmute analysis preview" : "Mute analysis preview"
                        enabled: root.canPlay
                    }

                    Slider {
                        id: volumeSlider
                        Layout.preferredWidth: 110
                        from: 0
                        to: 1
                        value: 0.85
                        enabled: root.canPlay
                        onMoved: {
                            if (value > 0) {
                                muteButton.checked = false
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 188
                    radius: 8
                    color: "#111113"
                    border.color: Theme.strokeStrong
                    clip: true

                    Canvas {
                        id: waveformCanvas
                        anchors.fill: parent
                        anchors.margins: 12
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.fillStyle = "#111113"
                            ctx.fillRect(0, 0, width, height)

                            var points = root.analysisResult.preview_points || []
                            var duration = Math.max(0.001, root.analysisResult.duration_seconds || 15)

                            ctx.strokeStyle = "#6a737f"
                            ctx.lineWidth = 1
                            ctx.beginPath()
                            for (var i = 0; i < points.length; i++) {
                                var x = points[i].time_seconds / duration * width
                                var y = height - points[i].energy * height
                                if (i === 0) {
                                    ctx.moveTo(x, y)
                                } else {
                                    ctx.lineTo(x, y)
                                }
                            }
                            ctx.stroke()

                            var markers = root.analysisResult.markers || []
                            ctx.strokeStyle = Theme.audioAccent
                            ctx.lineWidth = 2
                            for (var j = 0; j < markers.length; j++) {
                                var markerX = markers[j].time_seconds / duration * width
                                ctx.beginPath()
                                ctx.moveTo(markerX, 0)
                                ctx.lineTo(markerX, height)
                                ctx.stroke()
                            }

                            if (analysisPlayer.duration > 0) {
                                var playheadX = analysisPlayer.position / analysisPlayer.duration * width
                                ctx.strokeStyle = Theme.accent
                                ctx.lineWidth = 2
                                ctx.beginPath()
                                ctx.moveTo(playheadX, 0)
                                ctx.lineTo(playheadX, height)
                                ctx.stroke()
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !root.analyzing && markerModel.count === 0 && !analysisResult.error
                        text: "Analyze a frequency range to show beat markers"
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

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    model: markerModel

                    delegate: Rectangle {
                        required property real time_seconds
                        required property int frame_number
                        required property real strength
                        required property string band_name

                        width: ListView.view.width
                        height: 38
                        radius: 6
                        color: Theme.surfaceRaised
                        border.color: Theme.stroke

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            Text {
                                text: root.formatTime(time_seconds)
                                color: Theme.audioAccent
                                font.family: Theme.monoFamily
                                font.pixelSize: 12
                                Layout.preferredWidth: 58
                            }

                            Text {
                                text: "Frame " + frame_number
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                Layout.preferredWidth: 78
                            }

                            Text {
                                text: band_name
                                color: Theme.subtleText
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: strength.toFixed(2)
                                color: Theme.subtleText
                                font.family: Theme.monoFamily
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignRight
                                Layout.preferredWidth: 42
                            }
                        }
                    }
                }
            }
        }
    }
}
