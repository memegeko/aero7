import QtQuick
import "../components"

Item {
    anchors.fill: parent

    Row {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -24
        spacing: 14
        AeroSpinner { anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22 }
        Text {
            text: qsTr("Welcome")
            color: "white"
            style: Text.Outline
            styleColor: "#315676"
            font.pixelSize: 29
            font.weight: Font.Light
        }
    }

    Brand {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30
        width: 330
        height: 68
        markSize: 48
        titleSize: 30
        edition: qsTr("Professional")
    }
}
