import QtQuick
import "../components"

SetupPage {
    anchors.fill: parent
    title: qsTr("Select your computer's current location")
    description: qsTr("Aero7 will apply suitable sharing and firewall defaults for this network.")
    showBack: true
    showNext: false
    showFooter: false

    body: [
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 3

            Repeater {
                model: [
                    { key: "home", icon: "network-home.svg", title: qsTr("Home network"), detail: qsTr("For a trusted network at home where you recognize the other computers and devices.") },
                    { key: "work", icon: "network-work.svg", title: qsTr("Work network"), detail: qsTr("For a trusted workplace network managed by you or your organization.") },
                    { key: "public", icon: "network-public.svg", title: qsTr("Public network"), detail: qsTr("For cafés, airports, mobile broadband, and other networks you do not fully trust.") }
                ]

                AeroChoice {
                    required property var modelData
                    width: parent.width
                    compact: true
                    selected: controller.networkChoice === modelData.key
                    iconSource: "qrc:/assets/icons/" + modelData.icon
                    title: modelData.title
                    detail: modelData.detail
                    onChosen: {
                        controller.networkChoice = modelData.key
                        controller.goNext()
                    }
                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 68
                text: qsTr("If you aren't sure, select Public network.")
                color: "#4e5961"
                font.pixelSize: 12
            }
        }
    ]
}
