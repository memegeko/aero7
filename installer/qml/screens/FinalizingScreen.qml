import QtQuick
import "../components"

Item {
    anchors.fill: parent

    Rectangle { anchors.fill: parent; color: "#000000" }

    Column {
        anchors.centerIn: parent
        spacing: 20

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 92
            height: 92
            source: "qrc:/assets/aero7-logo-plain.png"
            fillMode: Image.PreserveAspectFit
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            AeroSpinner { width: 20; height: 20 }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Setup is finalizing your settings…")
                color: "white"
                font.pixelSize: 23
                font.weight: Font.Light
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: controller.progressStage + "  " + controller.progress + "%"
            color: "#c6ccd0"
            font.pixelSize: 13
        }
        AeroProgressBar { width: 430; height: 12; value: controller.progress }
    }
}
