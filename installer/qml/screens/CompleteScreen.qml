import QtQuick
import "../components"

SetupPage {
    anchors.fill: parent
    title: qsTr("Aero7 needs to restart to continue")
    description: ""
    showBack: false
    progressStep: 2
    nextText: qsTr("Restart now")

    body: [
        AeroProgressBar {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 12
            value: (10 - controller.restartSeconds) * 10
        },
        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 24
            text: controller.demoMode && !documentationMode
                  ? qsTr("Restarting the simulation in %1 seconds").arg(controller.restartSeconds)
                  : qsTr("Restarting in %1 seconds").arg(controller.restartSeconds)
            color: "#182129"
            font.pixelSize: 13
        },
        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 82
            text: controller.demoMode && !documentationMode
                  ? qsTr("Setup will now simulate the restart and continue to first-boot account setup. No disk was changed.")
                  : qsTr("Setup will continue after the computer restarts. Remove the installation media when the computer begins restarting.")
            color: "#3c464d"
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
    ]
}
