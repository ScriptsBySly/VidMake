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
    readonly property string mediaUrl: assetPath.length > 0 ? pathToUrl(assetPath) : ""
    readonly property string assetExtension: extensionFromName(assetName.length > 0 ? assetName : assetPath)
    readonly property bool isAudio: assetKind === "Audio"
    readonly property bool isVideo: assetKind === "Visual" && ["mp4", "mov", "mkv", "avi"].indexOf(assetExtension) >= 0
    readonly property bool isImage: assetKind === "Visual" && ["png", "jpg", "jpeg", "webp", "gif"].indexOf(assetExtension) >= 0
    readonly property bool canPlay: isAudio || isVideo
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

    function togglePlayback() {
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
        if (!canPlay) {
            return
        }
        player.position = Math.max(0, Math.min(player.duration, player.position + milliseconds))
    }

    onMediaUrlChanged: {
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
        source: root.canPlay ? root.mediaUrl : ""
        audioOutput: audioOutput
        videoOutput: videoOutput
        onPositionChanged: {
            if (!root.seeking) {
                scrubber.value = position
            }
        }
        onDurationChanged: scrubber.value = 0
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
                width: Math.min(parent.width - 48, (parent.height - 48) * 9 / 16)
                height: width * 16 / 9
                radius: 6
                color: "#1c1d20"
                border.color: "#303238"
                clip: true

                VideoOutput {
                    id: videoOutput
                    anchors.fill: parent
                    fillMode: VideoOutput.PreserveAspectFit
                    visible: root.isVideo
                }

                Image {
                    anchors.fill: parent
                    anchors.margins: 12
                    source: root.isImage ? root.mediaUrl : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    visible: root.isImage
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 14
                    visible: !root.isImage && !root.isVideo

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 96
                        height: 96
                        radius: 8
                        color: root.isAudio ? Theme.audioTile : "#2b5361"
                        border.color: root.isAudio ? Theme.audioAccent : "#6dbad0"

                        Text {
                            anchors.centerIn: parent
                            text: root.isAudio ? "\uE8D6" : "\uEB9F"
                            color: root.isAudio ? Theme.audioAccent : "#d7f4ff"
                            font.family: "Segoe MDL2 Assets"
                            font.pixelSize: 42
                        }
                    }

                    Text {
                        width: Math.min(frame.width - 32, 360)
                        horizontalAlignment: Text.AlignHCenter
                        text: root.assetName.length > 0 ? root.assetName : "Select an asset"
                        color: "#d9dbe1"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        elide: Text.ElideMiddle
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 18
                    text: root.assetName.length > 0
                        ? root.assetName
                        : root.visualName.length > 0 ? root.visualName : "1080 x 1920"
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
                enabled: root.canPlay
                onClicked: root.jumpBy(-1000)
            }

            IconButton {
                iconText: player.playbackState === MediaPlayer.PlayingState ? "\uE769" : "\uE768"
                tooltip: player.playbackState === MediaPlayer.PlayingState ? "Pause" : "Play"
                accented: true
                enabled: root.canPlay
                onClicked: root.togglePlayback()
            }

            IconButton {
                iconText: "\uE893"
                tooltip: "Jump forward"
                enabled: root.canPlay
                onClicked: root.jumpBy(1000)
            }

            Slider {
                id: scrubber
                Layout.fillWidth: true
                from: 0
                to: Math.max(1, player.duration)
                enabled: root.canPlay && player.duration > 0
                onPressedChanged: {
                    root.seeking = pressed
                    if (!pressed && root.canPlay) {
                        player.position = value
                    }
                }
                onMoved: {
                    if (root.canPlay) {
                        player.position = value
                    }
                }
            }

            Text {
                text: root.canPlay ? root.formatTime(player.position) : "00:00.00"
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
                enabled: root.canPlay
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
                enabled: root.canPlay
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
                enabled: root.canPlay
                onClicked: root.previewMuted = !root.previewMuted
            }

            Slider {
                Layout.preferredWidth: 160
                from: 0
                to: 1
                value: root.previewVolume
                enabled: root.canPlay
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
