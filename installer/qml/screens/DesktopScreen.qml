import QtQuick
import "../components"

Item {
    id: root
    anchors.fill: parent

    Image {
        anchors.fill: parent
        source: "qrc:/assets/aero-shell/aero7-background.png"
        fillMode: Image.PreserveAspectCrop
        smooth: true
    }

    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 20
        anchors.topMargin: 16
        width: 76
        spacing: 1

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 52
            height: 58
            source: "qrc:/assets/icons/recycle-bin.svg"
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Recycle Bin")
            color: "white"
            style: Text.Outline
            styleColor: "#24384a"
            font.pixelSize: 12
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 49
        gradient: Gradient {
            GradientStop { position: 0; color: "#d7eaf6f8" }
            GradientStop { position: 0.12; color: "#b8cfe3ed" }
            GradientStop { position: 0.55; color: "#a79ebdd3" }
            GradientStop { position: 1; color: "#c4b4cfdf" }
        }
        border.color: "#e7ffffff"

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: "#ffffff"
        }

        Image {
            anchors.left: parent.left
            anchors.leftMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            width: 43
            height: 43
            source: "qrc:/assets/aero7-logo-circle.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 65
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Repeater {
                model: ["qrc:/assets/aero7-logo-plain.png", "qrc:/assets/icons/harddisk.svg"]
                Rectangle {
                    required property string modelData
                    width: 43
                    height: 40
                    radius: 3
                    color: "#24ffffff"
                    border.color: "#4bffffff"
                    Image { anchors.centerIn: parent; width: 29; height: 29; source: modelData; fillMode: Image.PreserveAspectFit }
                }
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 126
            color: "#190b4168"
            border.color: "#55ffffff"

            Column {
                anchors.centerIn: parent
                Text {
                    id: desktopClock
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(new Date(), "h:mm AP")
                    color: "#ffffff"
                    style: Text.Outline
                    styleColor: "#31516b"
                    font.pixelSize: 12
                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: desktopClock.text = Qt.formatDateTime(new Date(), "h:mm AP")
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(new Date(), "M/d/yyyy")
                    color: "#ffffff"
                    style: Text.Outline
                    styleColor: "#31516b"
                    font.pixelSize: 11
                }
            }
        }
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 67
        width: finishedText.implicitWidth + 34
        height: 38
        radius: 4
        color: "#e8f3fbff"
        border.color: "#6d9db6"
        Text {
            id: finishedText
            anchors.centerIn: parent
            text: qsTr("Aero7 setup is complete")
            color: "#174668"
            font.pixelSize: 13
        }
    }

    AeroButton {
        visible: controller.demoMode
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 146
        anchors.bottomMargin: 9
        width: 112
        text: qsTr("Run again")
        onClicked: controller.goNext()
    }
}
