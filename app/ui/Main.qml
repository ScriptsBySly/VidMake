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
    property string analysisVisualName: ""
    property string analysisVisualPath: ""
    property var maskLayers: []
    property var effectLayers: []
    property string editingLayerKind: ""
    property string editingLayerId: ""
    property var editingLayer: ({})

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
        var visualAsset = assetPanel.latestVisualAsset()
        window.analysisVisualName = visualAsset.name
        window.analysisVisualPath = visualAsset.path
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
            "audio_keyframe_layers": audioKeyframeLayers,
            "mask_layers": maskLayers,
            "effect_layers": effectLayers
        }
    }

    function applyProject(data, path) {
        assetPanel.loadAssets(data.assets || [])
        audioKeyframeLayers = data.audio_keyframe_layers || []
        maskLayers = data.mask_layers || []
        effectLayers = data.effect_layers || []
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
            timelinePanel.loadTimelineData(assets, audioKeyframeLayers, maskLayers, effectLayers)
            previewPanel.loadCompositionAssets(assets)
            previewPanel.loadAudioKeyframeLayers(audioKeyframeLayers)
            previewPanel.loadCompositionEffects(effectLayers)
        }
    }

    function audioKeyframeLayerIndex(layerId) {
        if (layerId.length === 0) {
            return audioKeyframeLayers.length > 0 ? 0 : -1
        }
        for (var i = 0; i < audioKeyframeLayers.length; i++) {
            if (audioKeyframeLayers[i].id === layerId) {
                return i
            }
        }
        return -1
    }

    function audioKeyframeLayerIdAt(index) {
        if (index < 0 || index >= audioKeyframeLayers.length) {
            return ""
        }
        return audioKeyframeLayers[index].id || ""
    }

    function addAudioKeyframeLayer(layerJson) {
        var layer = JSON.parse(layerJson)
        var layers = audioKeyframeLayers.slice(0)
        layers.push(layer)
        audioKeyframeLayers = layers
        syncTimelineAssets()
        statusMessage = "Created " + layer.name
    }

    function addMaskLayer(layerJson) {
        var layer = JSON.parse(layerJson)
        var layers = maskLayers.slice(0)
        layers.push(layer)
        maskLayers = layers
        syncTimelineAssets()
        statusMessage = "Created " + layer.name
    }

    function addEffectLayer(layer) {
        var layers = effectLayers.slice(0)
        layers.push(layer)
        effectLayers = layers
        syncTimelineAssets()
        statusMessage = "Created " + layer.name
    }

    function createZoomBlurEffect() {
        if (analysisVisualPath.length === 0) {
            statusMessage = "Select or import a visual asset before adding an effect"
            return
        }
        var triggerMode = zoomTriggerMode.currentIndex === 1 ? "keyframes" : "interval"
        var keyframeLayerId = triggerMode === "keyframes" ? audioKeyframeLayerIdAt(zoomKeyframeLayer.currentIndex) : ""
        if (triggerMode === "keyframes" && keyframeLayerId.length === 0) {
            statusMessage = "Create an audio keyframe layer before using beat keyframes"
            return
        }
        addEffectLayer({
            "id": "effect-" + Date.now(),
            "name": zoomBlurName.text,
            "plugin": "builtin.zoom_blur",
            "source_visual_name": analysisVisualName,
            "source_visual_path": analysisVisualPath,
            "trigger_mode": triggerMode,
            "keyframe_layer_id": keyframeLayerId,
            "trigger_interval_seconds": triggerInterval.value,
            "blur_strength": blurStrength.value,
            "zoom_amount": zoomAmount.value
        })
    }

    function findGeneratedLayer(kind, id) {
        var source = kind === "Keyframes" ? audioKeyframeLayers : kind === "Mask" ? maskLayers : effectLayers
        for (var i = 0; i < source.length; i++) {
            if (source[i].id === id) {
                return source[i]
            }
        }
        return null
    }

    function updateGeneratedLayer(kind, updatedLayer) {
        var source = kind === "Keyframes" ? audioKeyframeLayers : kind === "Mask" ? maskLayers : effectLayers
        var updated = []
        for (var i = 0; i < source.length; i++) {
            updated.push(source[i].id === updatedLayer.id ? updatedLayer : source[i])
        }
        if (kind === "Keyframes") {
            audioKeyframeLayers = updated
        } else if (kind === "Mask") {
            maskLayers = updated
        } else {
            effectLayers = updated
        }
        syncTimelineAssets()
        statusMessage = "Updated " + updatedLayer.name
    }

    function deleteGeneratedLayer(kind, id) {
        var source = kind === "Keyframes" ? audioKeyframeLayers : kind === "Mask" ? maskLayers : effectLayers
        var updated = []
        var deletedName = ""
        for (var i = 0; i < source.length; i++) {
            if (source[i].id === id) {
                deletedName = source[i].name
            } else {
                updated.push(source[i])
            }
        }
        if (kind === "Keyframes") {
            audioKeyframeLayers = updated
        } else if (kind === "Mask") {
            maskLayers = updated
        } else {
            effectLayers = updated
        }
        syncTimelineAssets()
        statusMessage = deletedName.length > 0 ? "Deleted " + deletedName : "Layer deleted"
    }

    function openGeneratedLayerEditor(kind, id) {
        var layer = findGeneratedLayer(kind, id)
        if (!layer) {
            statusMessage = "Layer not found"
            return
        }
        editingLayerKind = kind
        editingLayerId = id
        editingLayer = JSON.parse(JSON.stringify(layer))
        editLayerName.text = layer.name || ""
        if (kind === "Keyframes") {
            editBandName.text = layer.band_name || ""
            editLowHz.value = Math.round(layer.low_hz || 0)
            editHighHz.value = Math.round(layer.high_hz || 0)
        } else if (kind === "Mask") {
            editKeyColor.text = layer.key_color || "#00ff00"
            editTolerance.value = layer.tolerance || 0.28
            editInverted.checked = !!layer.inverted
        } else {
            editTriggerMode.currentIndex = (layer.trigger_mode || "interval") === "keyframes" ? 1 : 0
            editKeyframeLayer.currentIndex = audioKeyframeLayerIndex(layer.keyframe_layer_id || "")
            editTriggerInterval.value = layer.trigger_interval_seconds || 1.0
            editBlurStrength.value = layer.blur_strength || 0.35
            editZoomAmount.value = layer.zoom_amount || 1.12
        }
        generatedLayerDialog.open()
    }

    function saveGeneratedLayerEdits() {
        var layer = JSON.parse(JSON.stringify(editingLayer))
        layer.name = editLayerName.text
        if (editingLayerKind === "Keyframes") {
            layer.band_name = editBandName.text
            layer.low_hz = editLowHz.value
            layer.high_hz = editHighHz.value
        } else if (editingLayerKind === "Mask") {
            if (!/^#[0-9a-fA-F]{6}$/.test(editKeyColor.text)) {
                statusMessage = "Mask key color must use #rrggbb"
                return
            }
            layer.key_color = editKeyColor.text
            layer.tolerance = editTolerance.value
            layer.inverted = editInverted.checked
        } else {
            var editMode = editTriggerMode.currentIndex === 1 ? "keyframes" : "interval"
            var editKeyframeLayerId = editMode === "keyframes" ? audioKeyframeLayerIdAt(editKeyframeLayer.currentIndex) : ""
            if (editMode === "keyframes" && editKeyframeLayerId.length === 0) {
                statusMessage = "Create an audio keyframe layer before using beat keyframes"
                return
            }
            layer.trigger_mode = editMode
            layer.keyframe_layer_id = editKeyframeLayerId
            layer.trigger_interval_seconds = editTriggerInterval.value
            layer.blur_strength = editBlurStrength.value
            layer.zoom_amount = editZoomAmount.value
        }
        updateGeneratedLayer(editingLayerKind, layer)
    }

    function openAudioAnalysis() {
        audioAnalysisLoader.active = true
        audioAnalysisLoader.item.open()
    }

    function openVideoAnalysis() {
        videoAnalysisLoader.active = true
        videoAnalysisLoader.item.open()
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

    Loader {
        id: audioAnalysisLoader
        active: false
        sourceComponent: AnalysisDialog {
            audioName: window.audioAssetName
            audioPath: window.audioAssetPath
            projectFrameRate: 30
            x: Math.round((window.width - width) / 2)
            y: Math.round((window.height - height) / 2)
            onKeyframeLayerCreated: function(layerJson) {
                window.addAudioKeyframeLayer(layerJson)
            }
            onClosed: audioAnalysisLoader.active = false
        }
    }

    Dialog {
        id: generatedLayerDialog
        title: editingLayerKind === "Keyframes" ? "Edit Keyframe Layer" : editingLayerKind === "Mask" ? "Edit Mask Layer" : "Edit Effect Layer"
        modal: true
        standardButtons: Dialog.Save | Dialog.Cancel
        width: 430
        x: Math.round((window.width - width) / 2)
        y: Math.round((window.height - height) / 2)
        onAccepted: window.saveGeneratedLayerEdits()

        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            Text {
                text: "Name"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            TextField {
                id: editLayerName
                Layout.fillWidth: true
                color: Theme.text
                font.family: Theme.fontFamily
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10
                visible: editingLayerKind === "Keyframes"

                Text {
                    text: "Band name"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                TextField {
                    id: editBandName
                    Layout.fillWidth: true
                    color: Theme.text
                    font.family: Theme.fontFamily
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    SpinBox {
                        id: editLowHz
                        Layout.fillWidth: true
                        from: 0
                        to: 24000
                    }

                    SpinBox {
                        id: editHighHz
                        Layout.fillWidth: true
                        from: 0
                        to: 24000
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10
                visible: editingLayerKind === "Mask"

                Text {
                    text: "Key color"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 42
                        Layout.preferredHeight: 34
                        radius: 6
                        color: editKeyColor.text
                        border.color: Theme.strokeStrong
                    }

                    TextField {
                        id: editKeyColor
                        Layout.fillWidth: true
                        color: Theme.text
                        font.family: Theme.monoFamily
                    }
                }

                Text {
                    text: "Tolerance " + editTolerance.value.toFixed(2)
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                Slider {
                    id: editTolerance
                    Layout.fillWidth: true
                    from: 0.02
                    to: 0.8
                    value: 0.28
                }

                CheckBox {
                    id: editInverted
                    text: "Invert result"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10
                visible: editingLayerKind === "Effect"

                Text {
                    text: "Trigger source"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                ComboBox {
                    id: editTriggerMode
                    Layout.fillWidth: true
                    model: ["Manual interval", "Beat keyframes"]
                }

                Text {
                    text: "Beat keyframe layer"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    visible: editTriggerMode.currentIndex === 1
                }

                ComboBox {
                    id: editKeyframeLayer
                    Layout.fillWidth: true
                    model: audioKeyframeLayers
                    textRole: "name"
                    enabled: audioKeyframeLayers.length > 0
                    visible: editTriggerMode.currentIndex === 1
                }

                Text {
                    text: "Trigger every " + editTriggerInterval.value.toFixed(2) + " seconds"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    visible: editTriggerMode.currentIndex === 0
                }

                Slider {
                    id: editTriggerInterval
                    Layout.fillWidth: true
                    from: 0.1
                    to: 10
                    value: 1
                    stepSize: 0.1
                    visible: editTriggerMode.currentIndex === 0
                }

                Text {
                    text: "Blur strength " + editBlurStrength.value.toFixed(2)
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                Slider {
                    id: editBlurStrength
                    Layout.fillWidth: true
                    from: 0
                    to: 1
                    value: 0.35
                }

                Text {
                    text: "Zoom amount " + editZoomAmount.value.toFixed(2) + "x"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                Slider {
                    id: editZoomAmount
                    Layout.fillWidth: true
                    from: 1
                    to: 2
                    value: 1.12
                }
            }
        }
    }

    Dialog {
        id: zoomBlurDialog
        title: "Add Zoom Blur"
        modal: true
        standardButtons: Dialog.Save | Dialog.Cancel
        width: 430
        x: Math.round((window.width - width) / 2)
        y: Math.round((window.height - height) / 2)
        onOpened: {
            zoomBlurName.text = "Zoom blur"
            zoomTriggerMode.currentIndex = 0
            zoomKeyframeLayer.currentIndex = audioKeyframeLayers.length > 0 ? 0 : -1
            triggerInterval.value = 1.0
            blurStrength.value = 0.35
            zoomAmount.value = 1.12
        }
        onAccepted: window.createZoomBlurEffect()

        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            Text {
                text: analysisVisualName.length > 0 ? "Source: " + analysisVisualName : "Select a visual source first"
                color: analysisVisualName.length > 0 ? Theme.subtleText : "#b91c1c"
                font.family: Theme.fontFamily
                font.pixelSize: 12
                elide: Text.ElideMiddle
                Layout.fillWidth: true
            }

            TextField {
                id: zoomBlurName
                Layout.fillWidth: true
                color: Theme.text
                font.family: Theme.fontFamily
                placeholderText: "Effect name"
            }

            Text {
                text: "Trigger source"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            ComboBox {
                id: zoomTriggerMode
                Layout.fillWidth: true
                model: ["Manual interval", "Beat keyframes"]
            }

            Text {
                text: "Beat keyframe layer"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                visible: zoomTriggerMode.currentIndex === 1
            }

            ComboBox {
                id: zoomKeyframeLayer
                Layout.fillWidth: true
                    model: audioKeyframeLayers
                    textRole: "name"
                    enabled: audioKeyframeLayers.length > 0
                    visible: zoomTriggerMode.currentIndex === 1
                }

            Text {
                text: "Trigger every " + triggerInterval.value.toFixed(2) + " seconds"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                visible: zoomTriggerMode.currentIndex === 0
            }

            Slider {
                id: triggerInterval
                Layout.fillWidth: true
                from: 0.1
                to: 10
                value: 1
                stepSize: 0.1
                visible: zoomTriggerMode.currentIndex === 0
            }

            Text {
                text: "Blur strength " + blurStrength.value.toFixed(2)
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            Slider {
                id: blurStrength
                Layout.fillWidth: true
                from: 0
                to: 1
                value: 0.35
            }

            Text {
                text: "Zoom amount " + zoomAmount.value.toFixed(2) + "x"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            Slider {
                id: zoomAmount
                Layout.fillWidth: true
                from: 1
                to: 2
                value: 1.12
            }
        }
    }

    Loader {
        id: videoAnalysisLoader
        active: false
        sourceComponent: VideoAnalysisDialog {
            videoName: window.analysisVisualName
            videoPath: window.analysisVisualPath
            x: Math.round((window.width - width) / 2)
            y: Math.round((window.height - height) / 2)
            onMaskLayerCreated: function(layerJson) {
                window.addMaskLayer(layerJson)
            }
            onClosed: videoAnalysisLoader.active = false
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
                onClicked: window.openAudioAnalysis()
            }

            ToolButton {
                text: "\uE8B9"
                font.family: "Segoe MDL2 Assets"
                ToolTip.visible: hovered
                ToolTip.text: "Analyze visual"
                onClicked: window.openVideoAnalysis()
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
                    var visualAsset = assetPanel.latestVisualAsset()
                    window.analysisVisualName = visualAsset.name
                    window.analysisVisualPath = visualAsset.path
                    window.syncTimelineAssets()
                }
                onAssetSelected: function(name, kind, path) {
                    window.selectedAssetName = name
                    window.selectedAssetKind = kind
                    window.selectedAssetPath = path
                    if (kind === "Visual") {
                        window.analysisVisualName = name
                        window.analysisVisualPath = path
                    }
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
                    var visualAsset = assetPanel.latestVisualAsset()
                    window.analysisVisualName = visualAsset.name
                    window.analysisVisualPath = visualAsset.path
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
                        if (kind === "Visual") {
                            window.analysisVisualName = name
                            window.analysisVisualPath = path
                        }
                        window.timelinePlayheadPosition = 0
                    }
                    onSeekRequested: function(milliseconds) {
                        previewPanel.seekCompositionTo(milliseconds)
                        window.timelinePlayheadPosition = milliseconds
                        window.timelineDuration = Math.max(15000, previewPanel.currentDuration)
                    }
                    onPlaybackToggled: previewPanel.toggleCompositionPlayback()
                    onGeneratedLayerEditRequested: function(kind, id) {
                        window.openGeneratedLayerEditor(kind, id)
                    }
                    onGeneratedLayerDeleteRequested: function(kind, id) {
                        window.deleteGeneratedLayer(kind, id)
                    }
                    onEffectAddRequested: zoomBlurDialog.open()
                    SplitView.fillWidth: true
                    SplitView.minimumHeight: 210
                    SplitView.preferredHeight: 290
                }
            }
        }
    }
}
