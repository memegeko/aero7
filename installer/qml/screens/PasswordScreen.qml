import QtQuick
import QtQuick.Controls
import "../components"

SetupPage {
    anchors.fill: parent
    title: qsTr("Set a password for your account")
    description: qsTr("Creating a password is a smart security precaution that helps protect your user account from unwanted access. Be sure to remember your password or keep it in a safe place.")
    showBack: true

    body: [
        Column {
            anchors.left: parent.left
            anchors.top: parent.top
            width: 380
            spacing: 5

            Text { text: qsTr("Type a password (recommended):"); color: "#25323b"; font.pixelSize: 12 }
            AeroTextField {
                width: parent.width
                echoMode: TextInput.Password
                text: controller.password
                onTextChanged: controller.password = text
            }
            Text { text: qsTr("Retype your password:"); color: "#25323b"; font.pixelSize: 12 }
            AeroTextField {
                width: parent.width
                echoMode: TextInput.Password
                text: controller.passwordConfirmation
                onTextChanged: controller.passwordConfirmation = text
            }
            Text { text: qsTr("Type a password hint:"); color: "#25323b"; font.pixelSize: 12 }
            AeroTextField {
                width: parent.width
                text: controller.passwordHint
                placeholderText: qsTr("optional")
                onTextChanged: controller.passwordHint = text
            }
            Text {
                width: parent.width
                text: qsTr("Choose a word or phrase that helps you remember your password. If you forget your password, Aero7 will show you your hint.")
                color: "#4d5961"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }
    ]
}
