import QtQuick
import "../components"

SetupPage {
    anchors.fill: parent
    title: qsTr("Where do you want to install Aero7?")
    description: ""
    showBack: true
    nextEnabled: controller.selectedDisk.device !== undefined

    body: [
        Rectangle {
            id: diskTable
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 210
            color: "#ffffff"
            border.color: "#858f96"

            Rectangle {
                id: tableHeader
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 27
                gradient: Gradient {
                    GradientStop { position: 0; color: "#f4f4f4" }
                    GradientStop { position: 1; color: "#d4d4d4" }
                }
                border.color: "#8a8a8a"

                Row {
                    anchors.fill: parent
                    Text { width: 330; leftPadding: 44; text: qsTr("Name"); color: "#20272c"; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                    Text { width: 105; text: qsTr("Total Size"); color: "#20272c"; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                    Text { width: 105; text: qsTr("Free Space"); color: "#20272c"; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                    Text { text: qsTr("Type"); color: "#20272c"; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                }
            }

            ListView {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: tableHeader.bottom
                anchors.bottom: parent.bottom
                clip: true
                model: controller.disks

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    activeFocusOnTab: true
                    width: ListView.view.width
                    height: 45
                    color: controller.selectedDisk.device === modelData.device ? "#b9e9ff" : "#ffffff"
                    border.width: activeFocus ? 1 : 0
                    border.color: "#3da4d5"

                    Row {
                        anchors.fill: parent
                        Item { width: 7; height: 1 }
                        Image { width: 35; height: 38; anchors.verticalCenter: parent.verticalCenter; source: "qrc:/assets/icons/harddisk.svg"; fillMode: Image.PreserveAspectFit }
                        Text { width: 288; text: qsTr("Disk %1 Unallocated Space").arg(index); color: "#18252e"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight }
                        Text { width: 105; text: modelData.size || "—"; color: "#18252e"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        Text { width: 105; text: modelData.free_space || modelData.size || "—"; color: "#18252e"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: modelData.type || ""; color: "#18252e"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    }

                    MouseArea { anchors.fill: parent; onClicked: controller.selectDisk(index) }
                    Keys.onReturnPressed: controller.selectDisk(index)
                    Keys.onSpacePressed: controller.selectDisk(index)
                }
            }
        },

        Row {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 225
            spacing: 28

            Row {
                spacing: 5
                Image { width: 19; height: 19; source: "qrc:/assets/icons/refresh.svg" }
                Text { text: qsTr("Refresh"); color: "#0067b1"; font.pixelSize: 12; font.underline: refreshMouse.containsMouse }
                MouseArea { id: refreshMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: controller.refreshDisks() }
            }
            Row {
                opacity: 0.55
                spacing: 5
                Image { width: 19; height: 19; source: "qrc:/assets/icons/harddisk.svg" }
                Text { text: qsTr("Load Driver"); color: "#0067b1"; font.pixelSize: 12 }
            }
        },

        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 228
            text: qsTr("Drive options (advanced)")
            color: "#0067b1"
            font.pixelSize: 12
            font.underline: driveOptions.containsMouse
            MouseArea { id: driveOptions; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
        },

        Row {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 266
            spacing: 34
            opacity: 0.52
            Repeater {
                model: [qsTr("Delete"), qsTr("Format"), qsTr("New"), qsTr("Extend")]
                Text { required property string modelData; text: modelData; color: "#52616b"; font.pixelSize: 12 }
            }
        }
    ]
}
