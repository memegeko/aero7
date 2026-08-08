import QtQuick
import QtQuick.Controls

Item {
    id: root

    property alias text: label.text
    property alias iconSource: icon.source
    property string toolTipText: ""
    property bool actionEnabled: true
    property bool underlined: true
    signal triggered()

    implicitWidth: icon.width + 6 + label.implicitWidth
    implicitHeight: 22
    opacity: actionEnabled ? 1 : 0.48

    Image {
        id: icon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        height: 20
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Text {
        id: label
        anchors.left: icon.right
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        color: root.actionEnabled ? "#0067b1" : "#6f777c"
        font.pixelSize: 12
        font.underline: root.underlined && actionMouse.containsMouse
    }

    MouseArea {
        id: actionMouse
        anchors.fill: parent
        enabled: root.actionEnabled
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.triggered()

        ToolTip.visible: containsMouse && root.toolTipText.length > 0
        ToolTip.delay: 500
        ToolTip.text: root.toolTipText
    }
}
