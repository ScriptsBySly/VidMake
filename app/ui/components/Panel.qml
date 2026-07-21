import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    property string title: ""

    radius: 8
    color: Theme.surface
    border.color: Theme.stroke
    clip: true

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 42
        color: Theme.panelHeader
        border.color: Theme.stroke
        z: 10

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
    }
}
