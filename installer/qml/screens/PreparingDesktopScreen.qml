import QtQuick
import "../components"

Item {
    anchors.fill: parent

    Row {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -24
        spacing: 16

        AeroSpinner { width: 22; height: 22 }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Preparing your desktop…")
            color: "white"
            style: Text.Outline
            styleColor: "#315676"
            font.pixelSize: 25
            font.weight: Font.Light
        }
    }

    Brand {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30
        width: 260
        height: 62
        markSize: 44
        titleSize: 27
        edition: qsTr("Professional")
    }
}
