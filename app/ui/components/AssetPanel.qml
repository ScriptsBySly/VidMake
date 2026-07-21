import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Panel {
    id: root
    title: "Assets"

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 58
        anchors.bottomMargin: 16
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            PillButton {
                text: "Audio"
                iconText: "\uE8D6"
                Layout.fillWidth: true
            }

            PillButton {
                text: "Visual"
                iconText: "\uEB9F"
                Layout.fillWidth: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 116
            radius: 8
            color: Theme.surfaceRaised
            border.color: Theme.stroke

            Column {
                anchors.centerIn: parent
                spacing: 9

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "\uE8B5"
                    color: Theme.accent
                    font.family: "Segoe MDL2 Assets"
                    font.pixelSize: 24
                }

                Text {
                    width: root.width - 64
                    horizontalAlignment: Text.AlignHCenter
                    text: "Drop media here"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }

                Text {
                    width: root.width - 64
                    horizontalAlignment: Text.AlignHCenter
                    text: "Audio, images, GIFs, and video"
                    color: Theme.subtleText
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
        }

        TextField {
            Layout.fillWidth: true
            placeholderText: "Search assets"
            leftPadding: 34
            color: Theme.text
            placeholderTextColor: Theme.mutedText
            font.family: Theme.fontFamily
            font.pixelSize: 13
            background: Rectangle {
                radius: 6
                color: Theme.input
                border.color: parent.activeFocus ? Theme.accent : Theme.stroke
            }

            Text {
                x: 11
                anchors.verticalCenter: parent.verticalCenter
                text: "\uE721"
                color: Theme.mutedText
                font.family: "Segoe MDL2 Assets"
                font.pixelSize: 13
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: ListModel {
                ListElement { name: "No audio selected"; kind: "Audio"; icon: "\uE8D6" }
                ListElement { name: "No visual selected"; kind: "Visual"; icon: "\uEB9F" }
            }

            delegate: Rectangle {
                required property string name
                required property string kind
                required property string icon

                width: ListView.view.width
                height: 64
                radius: 8
                color: mouse.containsMouse ? Theme.surfaceHover : Theme.surfaceRaised
                border.color: Theme.stroke

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 42
                        Layout.preferredHeight: 42
                        radius: 6
                        color: Theme.tile

                        Text {
                            anchors.centerIn: parent
                            text: icon
                            color: Theme.accent
                            font.family: "Segoe MDL2 Assets"
                            font.pixelSize: 17
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: name
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: kind
                            color: Theme.subtleText
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }
        }
    }
}
