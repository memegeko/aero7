import QtQuick
import ".."

Item {
    id: root
    property alias title: heading.text
    property alias description: description.text
    property alias body: body.data
    property bool showBack: true
    property bool showHeading: true
    property string nextText: qsTr("Next")
    property bool nextEnabled: true
    property bool showNext: true
    property bool showFooter: true
    property bool showProgressFooter: !controller.oobeMode
    property int progressStep: 1
    property int panelWidth: controller.oobeMode ? 760 : 790
    property int panelHeight: 560
    property string captionMode: controller.oobeMode ? "none" : "close"

    GlassWindow {
        anchors.fill: parent
        panelWidth: root.panelWidth
        panelHeight: root.panelHeight
        title: controller.oobeMode ? qsTr("Set Up Aero7") : qsTr("Install Aero7")
        showBack: root.showBack
        captionMode: root.captionMode

        Text {
            id: heading
            visible: root.showHeading
            anchors.left: parent.left
            anchors.leftMargin: 46
            anchors.top: parent.top
            anchors.topMargin: 27
            color: "#0755a0"
            font.pixelSize: 20
            font.weight: Font.Light
        }

        Text {
            id: description
            visible: root.showHeading && description.text.length > 0
            anchors.left: heading.left
            anchors.right: parent.right
            anchors.rightMargin: 46
            anchors.top: heading.bottom
            anchors.topMargin: 12
            color: "#2a3138"
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }

        Item {
            id: body
            anchors.left: heading.left
            anchors.right: parent.right
            anchors.rightMargin: 46
            anchors.top: !root.showHeading ? parent.top
                         : description.text.length > 0 ? description.bottom : heading.bottom
            anchors.topMargin: 18
            anchors.bottom: root.showFooter ? footer.top : parent.bottom
            anchors.bottomMargin: root.showFooter ? 12 : 28
        }

        Rectangle {
            id: footer
            visible: root.showFooter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 58
            gradient: Gradient {
                GradientStop { position: 0; color: "#f7f7f7" }
                GradientStop { position: 1; color: "#e7e7e7" }
            }
            border.color: "#d1d1d1"

            AeroButton {
                visible: root.showNext
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: root.nextText
                enabled: root.nextEnabled && !controller.busy
                onClicked: controller.goNext()
            }
        }
    }

    ProgressFooter {
        visible: root.showProgressFooter
        activeStep: root.progressStep
        z: 20
    }
}
