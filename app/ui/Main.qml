import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import "components"

ApplicationWindow {
    id: window
    property string audioAssetName: ""
    property string visualAssetName: ""
    property string selectedAssetName: ""
    property string selectedAssetKind: ""
    property string selectedAssetPath: ""
    property string projectPath: ""
    property string statusMessage: "Ready"
    property int projectWidth: 1080
    property int projectHeight: 1920
    property int timelinePlayheadPosition: 0
    property int timelineDuration: 15000
    property string audioAssetPath: ""
    property var audioKeyframeLayers: []

    width: 1440
    height: 900
    minimumWidth: 980
    minimumHeight: 640
    visible: true
    title: projectPath.length > 0 ? "VidMake - " + projectPath : "VidMake"
    color: Theme.window

    function fileNameFromPath(path) {
        var slash = Math.max(path.lastIndexOf("/"), path.lastIndexOf("\\"))
        return slash >= 0 ? path.slice(slash + 1) : path
    }

    function refreshLatestAssetNames() {
        var audio = assetPanel.latestAssetName("Audio")
        var visual = assetPanel.latestAssetName("Visual")
        window.audioAssetName = audio
        window.visualAssetName = visual
        window.audioAssetPath = assetPanel.latestAssetPath("Audio")
    }

    function projectData() {
        return {
            "format_version": 1,
            "settings": {
                "width": projectWidth,
                "height": projectHeight,
                "frame_rate": 30,
                "duration": 15.0
            },
            "assets": assetPanel.assets(),
            "audio_keyframe_layers": audioKeyframeLayers
        }
    }

    function applyProject(data, path) {
        assetPanel.loadAssets(data.assets || [])
        audioKeyframeLayers = data.audio_keyframe_layers || []
        syncTimelineAssets()
        refreshLatestAssetNames()
        selectedAssetName = ""
        selectedAssetKind = ""
        selectedAssetPath = ""
        timelinePlayheadPosition = 0
        timelineDuration = 15000
        projectWidth = data.settings && data.settings.width ? data.settings.width : 1080
        projectHeight = data.settings && data.settings.height ? data.settings.height : 1920
        projectPath = path || ""
    }

    function syncTimelineAssets() {
        if (timelinePanel) {
            var assets = assetPanel.assets()
            timelinePanel.loadAssets(assets)
            timelinePanel.loadKeyframeLayers(audioKeyframeLayers)
            previewPanel.loadCompositionAssets(assets)
        }
    }

    function addAudioKeyframeLayer(layerJson) {
        var layer = JSON.parse(layerJson)
        var layers = audioKeyframeLayers.slice(0)
        layers.push(layer)
        audioKeyframeLayers = layers
        syncTimelineAssets()
        statusMessage = "Created " + layer.name
    }

    function newProject() {
        var data = JSON.parse(projectController.newProjectJson())
        applyProject(data, "")
        statusMessage = "Created new project"
    }

    function saveProject(fileUrl) {
        var savedPath = projectController.saveProject(fileUrl, JSON.stringify(projectData()))
        if (savedPath.length > 0) {
            projectPath = savedPath
        }
    }

    function openProject(fileUrl) {
        var loadedJson = projectController.loadProject(fileUrl)
        if (loadedJson.length === 0) {
            return
        }
        applyProject(JSON.parse(loadedJson), assetPanel.localPathFromUrl(fileUrl))
    }

    FileDialog {
        id: openProjectDialog
        title: "Open project"
        fileMode: FileDialog.OpenFile
        nameFilters: [
            "VidMake projects (*.vidmake *.json)",
            "All files (*)"
        ]
        onAccepted: window.openProject(selectedFile)
    }

    FileDialog {
        id: saveProjectDialog
        title: "Save project"
        fileMode: FileDialog.SaveFile
        defaultSuffix: "vidmake"
        nameFilters: [
            "VidMake projects (*.vidmake)",
            "JSON files (*.json)",
            "All files (*)"
        ]
        onAccepted: window.saveProject(selectedFile)
    }

    Dialog {
        id: settingsDialog
        title: "Settings"
        modal: true
        standardButtons: Dialog.Ok
        width: 390
        x: Math.round((window.width - width) / 2)
        y: Math.round((window.height - height) / 2)

        ColumnLayout {
            anchors.fill: parent
            spacing: 14

            Text {
                text: "Project resolution"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            ButtonGroup {
                id: resolutionGroup
            }

            RadioButton {
                text: "Vertical 1080 x 1920"
                checked: window.projectWidth === 1080 && window.projectHeight === 1920
                ButtonGroup.group: resolutionGroup
                onClicked: {
                    window.projectWidth = 1080
                    window.projectHeight = 1920
                    window.statusMessage = "Resolution set to 1080 x 1920"
                }
            }

            RadioButton {
                text: "Horizontal 1920 x 1080"
                checked: window.projectWidth === 1920 && window.projectHeight === 1080
                ButtonGroup.group: resolutionGroup
                onClicked: {
                    window.projectWidth = 1920
                    window.projectHeight = 1080
                    window.statusMessage = "Resolution set to 1920 x 1080"
                }
            }
        }
    }

    AnalysisDialog {
        id: analysisDialog
        audioName: window.audioAssetName
        audioPath: window.audioAssetPath
        projectFrameRate: 30
        x: Math.round((window.width - width) / 2)
        y: Math.round((window.height - height) / 2)
        onKeyframeLayerCreated: function(layerJson) {
            window.addAudioKeyframeLayer(layerJson)
        }
    }

    Connections {
        target: projectController
        function onStatusChanged(message) {
            window.statusMessage = message
        }
        function onErrorOccurred(message) {
            window.statusMessage = message
        }
    }

    Timer {
        interval: 125
        repeat: true
        running: previewPanel && previewPanel.isPlaying
        onTriggered: {
            window.timelinePlayheadPosition = previewPanel.currentPosition
            window.timelineDuration = Math.max(15000, previewPanel.currentDuration)
        }
    }

    Connections {
        target: previewPanel
        function onCurrentDurationChanged() {
            window.timelineDuration = Math.max(15000, previewPanel.currentDuration)
        }
        function onCurrentPositionChanged() {
            if (!previewPanel.isPlaying) {
                window.timelinePlayheadPosition = previewPanel.currentPosition
            }
        }
    }

    FontLoader {
        id: segoe
        source: ""
    }

    header: Rectangle {
        height: 52
        color: Theme.chrome
        border.color: Theme.stroke
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 14
            spacing: 14

            Text {
                text: projectPath.length > 0 ? fileNameFromPath(projectPath) : "VidMake"
                color: Theme.text
                font.family: "Segoe UI Variable Display"
                font.pixelSize: 18
                font.weight: Font.DemiBold
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                width: 1
                height: 24
                color: Theme.stroke
                Layout.alignment: Qt.AlignVCenter
            }

            ToolButton {
                text: "\uE8E5"
                font.family: "Segoe MDL2 Assets"
                ToolTip.visible: hovered
                ToolTip.text: "New project"
                onClicked: window.newProject()
            }

            ToolButton {
                text: "\uE8E5"
                font.family: "Segoe MDL2 Assets"
                ToolTip.visible: hovered
                ToolTip.text: "Open project"
                onClicked: openProjectDialog.open()
            }

            ToolButton {
                text: "\uE74E"
                font.family: "Segoe MDL2 Assets"
                ToolTip.visible: hovered
                ToolTip.text: "Save project"
                onClicked: saveProjectDialog.open()
            }

            ToolButton {
                text: "\uE713"
                font.family: "Segoe MDL2 Assets"
                ToolTip.visible: hovered
                ToolTip.text: "Settings"
                onClicked: settingsDialog.open()
            }

            ToolButton {
                text: "\uE9D9"
                font.family: "Segoe MDL2 Assets"
                ToolTip.visible: hovered
                ToolTip.text: "Analyze audio"
                onClicked: analysisDialog.open()
            }

            Text {
                text: statusMessage
                color: Theme.subtleText
                font.family: Theme.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
                Layout.maximumWidth: 360
            }

            Item {
                Layout.fillWidth: true
            }

            PillButton {
                text: "Export"
                iconText: "\uE118"
                accent: true
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.window

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            AssetPanel {
                id: assetPanel
                Layout.preferredWidth: 322
                Layout.minimumWidth: 280
                Layout.maximumWidth: 390
                Layout.fillHeight: true
                onAudioImported: function(name, path) {
                    window.audioAssetName = name
                    window.audioAssetPath = path
                    window.syncTimelineAssets()
                }
                onVisualImported: function(name, path) {
                    window.visualAssetName = name
                    window.syncTimelineAssets()
                }
                onAssetSelected: function(name, kind, path) {
                    window.selectedAssetName = name
                    window.selectedAssetKind = kind
                    window.selectedAssetPath = path
                    window.timelinePlayheadPosition = 0
                }
                onAudioDeleted: function(name, path) {
                    if (window.audioAssetName === name) {
                        window.audioAssetName = assetPanel.latestAssetName("Audio")
                        window.audioAssetPath = assetPanel.latestAssetPath("Audio")
                    }
                    window.syncTimelineAssets()
                }
                onVisualDeleted: function(name, path) {
                    if (window.visualAssetName === name) {
                        window.visualAssetName = assetPanel.latestAssetName("Visual")
                    }
                    window.syncTimelineAssets()
                }
            }

            SplitView {
                id: rightSplit
                orientation: Qt.Vertical
                Layout.fillWidth: true
                Layout.fillHeight: true
                handle: Rectangle {
                    implicitHeight: 8
                    color: SplitHandle.hovered || SplitHandle.pressed ? Theme.accentSoft : "transparent"

                    Rectangle {
                        anchors.centerIn: parent
                        width: 56
                        height: 3
                        radius: 2
                        color: Theme.strokeStrong
                    }
                }

                PreviewPanel {
                    id: previewPanel
                    visualName: window.visualAssetName
                    assetName: window.selectedAssetName
                    assetKind: window.selectedAssetKind
                    assetPath: window.selectedAssetPath
                    projectWidth: window.projectWidth
                    projectHeight: window.projectHeight
                    SplitView.fillWidth: true
                    SplitView.fillHeight: true
                    SplitView.minimumHeight: 320
                    SplitView.preferredHeight: 575
                }

                TimelinePanel {
                    id: timelinePanel
                    selectedAssetPath: window.selectedAssetPath
                    playheadPosition: window.timelinePlayheadPosition
                    timelineDuration: window.timelineDuration
                    playing: previewPanel.isPlaying
                    audioName: window.audioAssetName
                    visualName: window.visualAssetName
                    onAssetSelected: function(name, kind, path) {
                        window.selectedAssetName = name
                        window.selectedAssetKind = kind
                        window.selectedAssetPath = path
                        window.timelinePlayheadPosition = 0
                    }
                    onSeekRequested: function(milliseconds) {
                        previewPanel.seekCompositionTo(milliseconds)
                        window.timelinePlayheadPosition = milliseconds
                        window.timelineDuration = Math.max(15000, previewPanel.currentDuration)
                    }
                    onPlaybackToggled: previewPanel.toggleCompositionPlayback()
                    SplitView.fillWidth: true
                    SplitView.minimumHeight: 210
                    SplitView.preferredHeight: 290
                }
            }
        }
    }
}
