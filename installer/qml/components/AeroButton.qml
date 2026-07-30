import QtQuick
import QtQuick.Controls

Button {
    id: control

    implicitWidth: 98
    implicitHeight: 30
    leftPadding: 10
    rightPadding: 10
    topPadding: 4
    bottomPadding: 5
    font.pixelSize: 13
    focusPolicy: Qt.StrongFocus

    contentItem: Text {
        text: control.text
        color: control.enabled ? "#111111" : "#777777"
        font: control.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: BorderImage {
        source: control.down
                ? "qrc:/assets/controls/button-pressed.png"
                : (control.hovered || control.activeFocus)
                  ? "qrc:/assets/controls/button-focused.png"
                  : "qrc:/assets/controls/button-normal.png"
        border.left: 3
        border.top: 3
        border.right: 3
        border.bottom: 3
        horizontalTileMode: BorderImage.Stretch
        verticalTileMode: BorderImage.Stretch
        opacity: control.enabled ? 1 : 0.58
    }
}
