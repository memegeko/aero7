import QtQuick
import QtQuick.Controls

TextField {
    id: control
    implicitHeight: 28
    leftPadding: 6
    rightPadding: 6
    selectByMouse: true
    font.pixelSize: 13
    color: "#111111"
    selectionColor: "#3399ff"
    selectedTextColor: "white"

    background: Rectangle {
        color: "#ffffff"
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? "#2d75b5" : "#8e8e8e"
    }
}
