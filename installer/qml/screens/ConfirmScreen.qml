import QtQuick
import "../components"

SetupPage {
    anchors.fill: parent
    title: qsTr("Confirm the installation")
    description: qsTr("Review the target disk before setup begins.")
    showBack: true
    nextText: controller.demoMode ? qsTr("Simulate install") : qsTr("Install now")

    body: [
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 202
            color: "#fffdf6"
            border.color: "#e3b45a"

            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 19
                spacing: 16

                Image {
                    width: 52
                    height: 52
                    source: "qrc:/assets/icons/warning.svg"
                    fillMode: Image.PreserveAspectFit
                }

                Column {
                    width: parent.width - 68
                    spacing: 8
                    Text {
                        width: parent.width
                        text: qsTr("Everything on this disk will be erased")
                        color: "#4b340b"
                        font.pixelSize: 16
                    }
                    Text {
                        width: parent.width
                        text: qsTr("Setup will create a new Aero7 installation on the selected disk. This operation cannot be undone.")
                        color: "#4f4b42"
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.bottomMargin: 18
                height: 78
                color: "#ffffff"
                border.color: "#c4c8ca"

                Image {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 43
                    height: 43
                    source: "qrc:/assets/icons/harddisk.svg"
                    fillMode: Image.PreserveAspectFit
                }
                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 64
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text { text: controller.selectedDisk.model || qsTr("Selected disk"); color: "#1d2b34"; font.pixelSize: 13 }
                    Text { text: qsTr("Capacity: %1     Device: %2").arg(controller.selectedDisk.size || "—").arg(controller.selectedDisk.device || "—"); color: "#536069"; font.pixelSize: 12 }
                }
            }
        },
        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 224
            text: controller.demoMode
                  ? qsTr("Simulation mode is active. Setup will show the complete flow without executing disk commands.")
                  : qsTr("For safety, setup will verify this exact device again immediately before making any changes.")
            color: controller.demoMode ? "#18772d" : "#7c2a18"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
    ]
}
