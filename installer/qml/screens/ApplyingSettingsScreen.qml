import QtQuick
import "../components"

Item {
    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        color: "#030507"
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -18
        spacing: 30

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 104
            height: 104
            source: "qrc:/assets/aero7-logo-plain.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Setup is applying system settings")
            color: "#f4f7f9"
            font.pixelSize: 24
            font.weight: Font.Light
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 62
        text: qsTr("Aero7")
        color: "#777d82"
        font.pixelSize: 15
    }
}
