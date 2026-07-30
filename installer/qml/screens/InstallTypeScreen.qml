import QtQuick
import "../components"

SetupPage {
    anchors.fill: parent
    title: qsTr("Which type of installation do you want?")
    description: ""
    showBack: true
    showNext: false
    showFooter: false

    body: [
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 8

            AeroChoice {
                width: parent.width
                height: 108
                enabled: false
                iconSource: "qrc:/assets/icons/install-alongside.svg"
                title: qsTr("Upgrade")
                detail: qsTr("Upgrade an existing Aero7 installation and keep files and settings. This option is not available when setup is started from the installation media.")
            }

            AeroChoice {
                width: parent.width
                height: 112
                selected: controller.installType === "erase"
                iconSource: "qrc:/assets/icons/install-clean.svg"
                title: qsTr("Custom (advanced)")
                detail: qsTr("Install a new copy of Aero7. You will choose a target disk on the next screen. The current safety milestone supports only a complete whole-disk installation.")
                onChosen: {
                    controller.installType = "erase"
                    controller.goNext()
                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 80
                text: qsTr("Help me decide")
                color: "#0067b1"
                font.pixelSize: 13
                font.underline: helpMouse.containsMouse
                MouseArea {
                    id: helpMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    ]
}
