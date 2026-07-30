import QtQuick
import QtQuick.Controls
import "../components"

Item {
    anchors.fill: parent

    GlassWindow {
        anchors.fill: parent
        panelWidth: 820
        panelHeight: 610
        title: qsTr("Install Aero7")
        showBack: false
        useBackdrop: true

        Brand {
            width: 380
            height: 190
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 24
            stacked: true
            markSize: 108
            titleSize: 50
        }

        Grid {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 246
            columns: 2
            columnSpacing: 18
            rowSpacing: 16

            Text { text: qsTr("Language to install:"); color: "#f7fbff"; style: Text.Outline; styleColor: "#24537c"; font.pixelSize: 15; width: 210; horizontalAlignment: Text.AlignRight }
            AeroComboBox {
                width: 400
                model: ["English", "Nederlands"]
                currentIndex: controller.language === "Nederlands" ? 1 : 0
                onActivated: controller.language = currentText
            }
            Text { text: qsTr("Time and currency format:"); color: "#f7fbff"; style: Text.Outline; styleColor: "#24537c"; font.pixelSize: 15; width: 210; horizontalAlignment: Text.AlignRight }
            AeroComboBox {
                width: 400
                model: ["English (United States)", "Nederlands (Nederland)"]
                currentIndex: controller.timeFormat.indexOf("Nederlands") === 0 ? 1 : 0
                onActivated: controller.timeFormat = currentText
            }
            Text { text: qsTr("Keyboard or input method:"); color: "#f7fbff"; style: Text.Outline; styleColor: "#24537c"; font.pixelSize: 15; width: 210; horizontalAlignment: Text.AlignRight }
            AeroComboBox {
                width: 400
                model: ["US", "Dutch"]
                currentIndex: controller.keyboard === "Dutch" ? 1 : 0
                onActivated: controller.keyboard = currentText
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 421
            text: qsTr("Enter your language and other preferences and select Next to continue.")
            color: "white"
            style: Text.Outline
            styleColor: "#24537c"
            font.pixelSize: 15
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 40
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 36
            text: "Aero7 — independent open-source software"
            color: "white"
            style: Text.Outline
            styleColor: "#24537c"
            font.pixelSize: 12
        }

        AeroButton {
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24
            text: qsTr("Next")
            onClicked: controller.goNext()
        }
    }
}
