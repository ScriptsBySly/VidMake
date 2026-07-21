import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

ApplicationWindow {
    id: window
    property string audioAssetName: ""
    property string visualAssetName: ""

    width: 1440
    height: 900
    minimumWidth: 980
    minimumHeight: 640
    visible: true
    title: "VidMake"
    color: Theme.window

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
                text: "VidMake"
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
            }

            ToolButton {
                text: "\uE74E"
                font.family: "Segoe MDL2 Assets"
                ToolTip.visible: hovered
                ToolTip.text: "Open project"
            }

            ToolButton {
                text: "\uE74E"
                font.family: "Segoe MDL2 Assets"
                opacity: 0.55
                ToolTip.visible: hovered
                ToolTip.text: "Save project"
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
                onAudioDeleted: function(name, path) {
                    if (window.audioAssetName === name) {
                        window.audioAssetName = ""
                    }
                }
                onVisualDeleted: function(name, path) {
                    if (window.visualAssetName === name) {
                        window.visualAssetName = ""
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
