import QtQuick

Item {
    id: root
    property int activeStep: 1
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 82

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#1a94dc" }
            GradientStop { position: 0.52; color: "#087ac8" }
            GradientStop { position: 1; color: "#0464b1" }
        }
        opacity: 0.94
    }
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 7
        color: "#b5c0c9"
    }
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        height: 7
        width: root.activeStep === 1 ? parent.width * 0.25 : parent.width * 0.72
        gradient: Gradient {
            GradientStop { position: 0; color: "#c6ee69" }
            GradientStop { position: 1; color: "#83bd20" }
        }
    }
    Rectangle {
        x: parent.width * 0.265
        anchors.top: parent.top
        width: 2
        height: 7
        color: "#f1f6f8"
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 30
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 4
        spacing: 58

        Row {
            spacing: 12
            Text { text: "1"; color: "white"; font.pixelSize: 34; font.weight: Font.Light }
            Text { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Collecting information"); color: "white"; font.pixelSize: 13 }
        }
        Row {
            spacing: 12
            Text { text: "2"; color: "white"; font.pixelSize: 34; font.weight: Font.Light }
            Text { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Installing Aero7"); color: "white"; font.pixelSize: 13 }
        }
    }
}
