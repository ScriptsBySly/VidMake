import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Panel {
    id: root
    title: "Preview"
    property string visualName: ""

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

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width * 0.42, 190)
                    height: width
                    radius: 8
                    color: "#2b5361"
                    border.color: "#6dbad0"

                    Text {
                        anchors.centerIn: parent
                        text: "\uEB9F"
                        color: "#d7f4ff"
                        font.family: "Segoe MDL2 Assets"
                        font.pixelSize: 42
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 18
                    text: root.visualName.length > 0 ? root.visualName : "1080 x 1920"
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
                iconText: "\uE768"
                tooltip: "Jump backward"
            }

            IconButton {
                iconText: "\uE769"
                tooltip: "Play"
                accented: true
            }

            IconButton {
                iconText: "\uE893"
                tooltip: "Jump forward"
            }

            Slider {
                Layout.fillWidth: true
                from: 0
                to: 15
                value: 3.4
            }

            Text {
                text: "00:03.40"
                color: Theme.subtleText
                font.family: Theme.monoFamily
                font.pixelSize: 12
                Layout.preferredWidth: 62
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
