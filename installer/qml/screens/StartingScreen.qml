import QtQuick
import "../components"

Item {
    anchors.fill: parent

    Row {
        anchors.centerIn: parent
        spacing: 18

        AeroSpinner { width: 24; height: 24 }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Setup is starting…")
            color: "white"
            style: Text.Outline
            styleColor: "#315676"
            font.pixelSize: 24
            font.weight: Font.Light
        }
    }
}
