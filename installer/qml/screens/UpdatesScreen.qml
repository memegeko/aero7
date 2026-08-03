pragma ComponentBehavior: Bound
import QtQuick
import "../components"

SetupPage {
    anchors.fill: parent
    title: qsTr("Help protect your computer and improve Aero7 automatically")
    description: ""
    showBack: true
    showNext: false
    showFooter: false

    body: [
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 4

            Repeater {
                model: [
                    { key: "recommended", icon: "shield-recommended.svg", title: qsTr("Use recommended settings"), detail: qsTr("Install important and recommended updates, and check online for solutions to problems.") },
                    { key: "notify", icon: "shield-notify.svg", title: qsTr("Install important updates only"), detail: qsTr("Install security and other important updates, then notify me about the rest.") },
                    { key: "manual", icon: "shield-manual.svg", title: qsTr("Ask me later"), detail: qsTr("Until you decide, your computer might be more vulnerable to security threats.") }
                ]

                AeroChoice {
                    required property var modelData
                    width: parent.width
                    compact: true
                    selected: controller.updatePreference === modelData.key
                    iconSource: "qrc:/assets/icons/" + modelData.icon
                    title: modelData.title
                    detail: modelData.detail
                    onChosen: {
                        controller.updatePreference = modelData.key
                        controller.goNext()
                    }
                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 68
                anchors.topMargin: 4
                text: qsTr("Learn more about each option")
                color: "#0067b1"
                font.pixelSize: 12
                font.underline: updateHelp.containsMouse
                MouseArea { id: updateHelp; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 68
                width: parent.width - 90
                text: qsTr("When you use recommended settings or install important updates only, some system information may be used to check for solutions and improve Aero7. You can change these settings later in System Settings.")
                color: "#35424b"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 68
                text: qsTr("Read the privacy statement")
                color: "#0067b1"
                font.pixelSize: 12
                font.underline: privacyHelp.containsMouse
                MouseArea { id: privacyHelp; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
            }
        }
    ]
}
