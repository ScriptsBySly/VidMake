import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
    id: control
    property string iconText: ""
    property bool accent: false

    implicitHeight: 34
    font.family: Theme.fontFamily
    font.pixelSize: 13

    contentItem: RowLayout {
        spacing: 8

        Text {
            visible: control.iconText.length > 0
            text: control.iconText
            color: control.accent ? "white" : Theme.text
            font.family: "Segoe MDL2 Assets"
            font.pixelSize: 13
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: control.text
            color: control.accent ? "white" : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 13
            elide: Text.ElideRight
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignVCenter
        }
    }

    background: Rectangle {
        radius: 6
        color: control.down
            ? (control.accent ? Theme.accentPressed : Theme.buttonPressed)
            : control.hovered
                ? (control.accent ? Theme.accentHover : Theme.buttonHover)
                : (control.accent ? Theme.accent : Theme.button)
        border.color: control.accent ? Theme.accentBorder : Theme.stroke
    }
}
