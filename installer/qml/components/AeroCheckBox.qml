import QtQuick
import QtQuick.Controls

CheckBox {
    id: control
    spacing: 7
    focusPolicy: Qt.StrongFocus
    font.pixelSize: 13

    indicator: Rectangle {
        implicitWidth: 15
        implicitHeight: 15
        x: control.leftPadding
        y: parent.height / 2 - height / 2
        color: "white"
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? "#0079c5" : "#6f7f8b"

        Text {
            anchors.centerIn: parent
            visible: control.checked
            text: "✓"
            color: "#174f8a"
            font.bold: true
            font.pixelSize: 14
        }
    }

    contentItem: Text {
        leftPadding: control.indicator.width + control.spacing
        text: control.text
        color: control.enabled ? "#1f2730" : "#828990"
        font: control.font
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
    }
}
