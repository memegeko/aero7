pragma ComponentBehavior: Bound
import QtQuick
import "../components"

Item {
    id: root
    anchors.fill: parent

    readonly property int visualStageIndex: controller.progressStageIndex <= 1 ? 0
                                            : controller.progressStageIndex === 2 ? 1
                                            : controller.progressStageIndex === 3 ? 2
                                            : controller.progressStageIndex <= 5 ? 3 : 4

    function stagePercent(index) {
        if (index < visualStageIndex)
            return 100
        if (index > visualStageIndex)
            return 0
        return controller.progressStagePercent
    }

    GlassWindow {
        anchors.fill: parent
        panelWidth: 790
        panelHeight: 560
        title: qsTr("Install Aero7")
        showBack: false
        captionMode: "close"

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 46
            anchors.top: parent.top
            anchors.topMargin: 29
            text: qsTr("Installing Aero7…")
            color: "#0755a0"
            font.pixelSize: 20
            font.weight: Font.Light
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 46
            anchors.right: parent.right
            anchors.rightMargin: 46
            anchors.top: parent.top
            anchors.topMargin: 77
            text: qsTr("That's all the information we need right now. Your computer may restart several times during installation.")
            color: "#252d33"
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 64
            anchors.top: parent.top
            anchors.topMargin: 132
            spacing: 3

            Repeater {
                model: [
                    qsTr("Copying Aero7 files"),
                    qsTr("Expanding Aero7 files"),
                    qsTr("Installing features"),
                    qsTr("Installing updates"),
                    qsTr("Completing installation")
                ]

                Row {
                    id: stageRow
                    required property string modelData
                    required property int index
                    width: 560
                    height: 27
                    spacing: 8

                    Item {
                        width: 23
                        height: 23
                        Image {
                            anchors.centerIn: parent
                            width: 22
                            height: 22
                            visible: stageRow.index < root.visualStageIndex
                            source: "qrc:/assets/icons/check-green.svg"
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("%1 (%2%)%3")
                            .arg(stageRow.modelData)
                            .arg(root.stagePercent(stageRow.index))
                            .arg(stageRow.index === root.visualStageIndex ? qsTr("…") : "")
                        color: stageRow.index === root.visualStageIndex ? "#17212a"
                              : stageRow.index < root.visualStageIndex ? "#747b80" : "#8a9095"
                        font.pixelSize: 13
                        font.bold: stageRow.index === root.visualStageIndex
                    }
                }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 46
            anchors.bottom: overallProgress.top
            anchors.bottomMargin: 9
            text: controller.progressStage
            color: "#59656d"
            font.pixelSize: 12
        }

        AeroProgressBar {
            id: overallProgress
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 46
            anchors.rightMargin: 46
            anchors.bottomMargin: 24
            height: 12
            value: controller.progress
        }
    }

    ProgressFooter { activeStep: 2 }
}
