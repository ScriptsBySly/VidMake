import QtQuick

Rectangle {
    id: root
    property string label: ""
    property string clipName: ""
    property color clipColor: "#3f6a87"
    property real clipStart: 0.0
    property real clipWidth: 0.5

    color: "transparent"
    border.color: Theme.stroke
    border.width: 1

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 112
        color: Theme.trackHeader

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 12
            elide: Text.ElideRight
            width: parent.width - 20
        }
    }

    Rectangle {
        x: 122 + (parent.width - 142) * root.clipStart
        y: 8
        width: Math.max(72, (parent.width - 142) * root.clipWidth)
        height: parent.height - 16
        radius: 6
        color: root.clipColor
        border.color: Qt.lighter(root.clipColor, 1.25)

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: root.clipName
            color: "white"
            font.family: Theme.fontFamily
            font.pixelSize: 12
            elide: Text.ElideRight
            width: parent.width - 20
        }
    }
}
