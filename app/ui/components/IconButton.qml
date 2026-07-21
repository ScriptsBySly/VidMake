import QtQuick
import QtQuick.Controls

Button {
    id: control
    property string iconText: ""
    property string badgeText: ""
    property string tooltip: ""
    property bool accented: false

    implicitWidth: 34
    implicitHeight: 34
    padding: 0

    ToolTip.visible: hovered && tooltip.length > 0
    ToolTip.text: tooltip

    contentItem: Item {
        Text {
            anchors.centerIn: parent
            text: control.iconText
            color: control.accented ? "white" : Theme.text
            font.family: "Segoe MDL2 Assets"
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 3
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            visible: control.badgeText.length > 0
            text: control.badgeText
            color: control.accented ? "white" : Theme.subtleText
            font.family: Theme.fontFamily
            font.pixelSize: 8
            font.weight: Font.DemiBold
        }
    }

    background: Rectangle {
        radius: 6
        color: control.down
            ? (control.accented ? Theme.accentPressed : Theme.buttonPressed)
            : control.hovered
                ? (control.accented ? Theme.accentHover : Theme.buttonHover)
                : (control.accented ? Theme.accent : Theme.button)
        border.color: control.accented ? Theme.accentBorder : Theme.stroke
    }
}
