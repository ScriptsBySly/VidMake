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
    }

    function projectData() {
        return {
            "format_version": 1,
            "settings": {
                "width": 1080,
                "height": 1920,
                "frame_rate": 30,
                "duration": 15.0
            },
            "assets": assetPanel.assets()
        }
    }

    function applyProject(data, path) {
        assetPanel.loadAssets(data.assets || [])
        refreshLatestAssetNames()
        selectedAssetName = ""
        selectedAssetKind = ""
        selectedAssetPath = ""
        projectPath = path || ""
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

    Connections {
        target: projectController
        function onStatusChanged(message) {
            window.statusMessage = message
        }
        function onErrorOccurred(message) {
            window.statusMessage = message
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
                }
                onVisualImported: function(name, path) {
                    window.visualAssetName = name
                }
                onAssetSelected: function(name, kind, path) {
                    window.selectedAssetName = name
                    window.selectedAssetKind = kind
                    window.selectedAssetPath = path
                }
                onAudioDeleted: function(name, path) {
                    if (window.audioAssetName === name) {
                        window.audioAssetName = assetPanel.latestAssetName("Audio")
                    }
                }
                onVisualDeleted: function(name, path) {
                    if (window.visualAssetName === name) {
                        window.visualAssetName = assetPanel.latestAssetName("Visual")
                    }
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
                    visualName: window.visualAssetName
                    assetName: window.selectedAssetName
                    assetKind: window.selectedAssetKind
                    assetPath: window.selectedAssetPath
                    SplitView.fillWidth: true
                    SplitView.fillHeight: true
                    SplitView.minimumHeight: 320
                    SplitView.preferredHeight: 575
                }

                TimelinePanel {
                    audioName: window.audioAssetName
                    visualName: window.visualAssetName
                    SplitView.fillWidth: true
                    SplitView.minimumHeight: 210
                    SplitView.preferredHeight: 290
                }
            }
        }
    }
}
