import QtQuick
import "../components"

Item {
    id: root
    anchors.fill: parent

    GlassWindow {
        anchors.fill: parent
        panelWidth: 780
        panelHeight: 560
        title: qsTr("Install Aero7")
        showBack: true
        useBackdrop: true

        Brand {
            width: 430
            height: 216
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 27
            stacked: true
            markSize: 124
            titleSize: 56
        }

        AeroButton {
            width: 180
            height: 38
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 272
            text: qsTr("Install now   ➜")
            font.pixelSize: 15
            onClicked: controller.goNext()
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 34
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 72
            text: qsTr("What to know before installing Aero7")
            color: "#f4fbff"
            style: Text.Outline
            styleColor: "#24537c"
            font.pixelSize: 14
        }

        Text {
            id: repairLink
            anchors.left: parent.left
            anchors.leftMargin: 34
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 42
            text: qsTr("Repair your computer")
            color: "#f4fbff"
            style: Text.Outline
            styleColor: "#24537c"
            font.pixelSize: 14
            font.underline: repairMouse.containsMouse

            MouseArea {
                id: repairMouse
                anchors.fill: parent
                anchors.margins: -7
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: repairConfirmation.visible = true
            }
        }
    }

    Rectangle {
        id: modalShade
        anchors.fill: parent
        visible: repairConfirmation.visible
        color: "#5c000000"
        z: 90

        MouseArea {
            anchors.fill: parent
            onClicked: repairConfirmation.visible = false
        }
    }

    Rectangle {
        id: repairConfirmation
        visible: false
        anchors.centerIn: parent
        width: 470
        height: 176
        radius: 7
        color: "#eef5fb"
        border.width: 1
        border.color: "#55758c"
        z: 100

        MouseArea { anchors.fill: parent }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 34
            radius: 6
            gradient: Gradient {
                GradientStop { position: 0; color: "#f8fcff" }
                GradientStop { position: 1; color: "#b7ccdc" }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 13
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Aero7 Recovery")
                color: "#18232c"
                font.pixelSize: 13
            }
        }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 23
            anchors.rightMargin: 23
            anchors.topMargin: 56
            text: qsTr("Leave setup and open the recovery command shell?\nYou can return to setup with Alt+F1.")
            color: "#20262b"
            font.pixelSize: 14
            lineHeight: 1.25
        }

        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 18
            anchors.bottomMargin: 16
            spacing: 9

            AeroButton {
                width: 86
                text: qsTr("Yes")
                onClicked: {
                    repairConfirmation.visible = false
                    controller.openRecoveryShell()
                }
            }
            AeroButton {
                width: 86
                text: qsTr("No")
                onClicked: repairConfirmation.visible = false
            }
        }
    }
}
