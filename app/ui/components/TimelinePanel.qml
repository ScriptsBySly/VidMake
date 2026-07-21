import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Panel {
    id: root
    title: "Timeline"

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
                text: "Add effect"
                iconText: "\uE710"
            }

            ComboBox {
                Layout.preferredWidth: 150
                model: ["Fit", "100%", "200%"]
                font.family: Theme.fontFamily
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
            Layout.fillWidth: true
            height: 58
            radius: 8
            color: Theme.surfaceRaised
            border.color: Theme.stroke
            clip: true

            Repeater {
                model: 80
                Rectangle {
                    required property int index
                    x: index * parent.width / 80
                    y: 14 + Math.abs(Math.sin(index * 0.47)) * 18
                    width: Math.max(2, parent.width / 120)
                    height: 16 + Math.abs(Math.cos(index * 0.39)) * 24
                    radius: 2
                    color: index % 5 === 0 ? Theme.accent : "#6a737f"
                    opacity: 0.85
                }
            }

            Rectangle {
                x: parent.width * 0.23
                width: 2
                height: parent.height
                color: Theme.accent
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            color: Theme.timeline
            border.color: Theme.stroke
            clip: true

            Column {
                anchors.fill: parent
                anchors.margins: 1

                TimelineRow {
                    width: parent.width
                    height: 44
                    label: "Visual"
                    clipColor: "#2b5361"
                    clipName: "Media layer"
                    clipStart: 0.04
                    clipWidth: 0.82
                }

                TimelineRow {
                    width: parent.width
                    height: 44
                    label: "Effect"
                    clipColor: "#496f48"
                    clipName: "Pulse"
                    clipStart: 0.15
                    clipWidth: 0.62
                }

                TimelineRow {
                    width: parent.width
                    height: 44
                    label: "Audio"
                    clipColor: "#6b4d89"
                    clipName: "Song"
                    clipStart: 0.04
                    clipWidth: 0.82
                }
            }

            Rectangle {
                x: parent.width * 0.23
                width: 2
                height: parent.height
                color: Theme.accent
                z: 5
            }
        }
    }
}
