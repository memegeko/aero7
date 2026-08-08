import QtQuick
import QtQuick.Controls
import "../components"

SetupPage {
    id: root
    anchors.fill: parent
    title: qsTr("Where do you want to install Aero7?")
    description: ""
    showBack: true
    nextEnabled: controller.diskSelectionReady

    function rowIsVisible(item) {
        return controller.advancedDriveOptions
                ? item.target_kind !== "disk"
                : item.target_kind === "disk"
    }

    function rowIsSelected(item) {
        if (item.target_kind === "disk")
            return controller.selectedDisk.target_kind === "disk"
                    && controller.selectedDisk.device === item.device
        if (item.target_kind === "free")
            return controller.selectedDisk.target_kind === "free"
                    && controller.selectedDisk.device === item.device
                    && controller.selectedDisk.start_sector === item.start_sector
        return controller.selectedDisk.device === item.device
                && controller.selectedDisk.partition_device === item.partition_device
    }

    body: [
        Rectangle {
            id: diskTable
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: controller.advancedDriveOptions ? 225 : 210
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
                id: targetList
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: tableHeader.bottom
                anchors.bottom: parent.bottom
                clip: true
                model: controller.disks

                delegate: Rectangle {
                    id: targetRow
                    required property var modelData
                    required property int index
                    readonly property bool shown: root.rowIsVisible(modelData)
                    activeFocusOnTab: shown
                    visible: shown
                    width: ListView.view.width
                    height: shown ? 42 : 0
                    color: root.rowIsSelected(modelData) ? "#b9e9ff" : "#ffffff"
                    border.width: activeFocus ? 1 : 0
                    border.color: "#3da4d5"

                    Row {
                        anchors.fill: parent
                        Item { width: modelData.target_kind === "disk" ? 7 : 17; height: 1 }
                        Image {
                            width: 35
                            height: 35
                            anchors.verticalCenter: parent.verticalCenter
                            source: "qrc:/assets/icons/harddisk.svg"
                            fillMode: Image.PreserveAspectFit
                        }
                        Text {
                            width: modelData.target_kind === "disk" ? 288 : 278
                            text: modelData.display_name || modelData.model || qsTr("Disk")
                            color: "#18252e"
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                        }
                        Text { width: 105; text: modelData.size || "—"; color: "#18252e"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        Text { width: 105; text: modelData.free_space || "—"; color: "#18252e"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: modelData.type || ""; color: "#18252e"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: targetRow.shown
                        onClicked: {
                            shrinkPanel.visible = false
                            controller.selectDisk(targetRow.index)
                        }
                    }
                    Keys.onReturnPressed: controller.selectDisk(index)
                    Keys.onSpacePressed: controller.selectDisk(index)
                }
            }
        },

        Row {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: controller.advancedDriveOptions ? 240 : 225
            spacing: 28

            Row {
                width: 88
                height: 19
                spacing: 5
                Image { width: 19; height: 19; source: "qrc:/assets/icons/refresh.svg" }
                Text { text: qsTr("Refresh"); color: "#0067b1"; font.pixelSize: 12; font.underline: refreshMouse.containsMouse }
                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        shrinkPanel.visible = false
                        controller.refreshDisks()
                    }
                }
            }
            Row {
                width: 100
                height: 19
                opacity: 0.55
                spacing: 5
                Image { width: 19; height: 19; source: "qrc:/assets/icons/harddisk.svg" }
                Text { text: qsTr("Load Driver"); color: "#0067b1"; font.pixelSize: 12 }
            }
        },

        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: controller.advancedDriveOptions ? 243 : 228
            text: controller.advancedDriveOptions
                  ? qsTr("Hide drive options")
                  : qsTr("Drive options (advanced)")
            color: "#0067b1"
            font.pixelSize: 12
            font.underline: driveOptions.containsMouse
            MouseArea {
                id: driveOptions
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    shrinkPanel.visible = false
                    controller.setAdvancedDriveOptions(!controller.advancedDriveOptions)
                }
            }
        },

        Row {
            id: advancedActions
            visible: controller.advancedDriveOptions
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 278
            spacing: 28

            Text {
                text: qsTr("Delete")
                color: "#8a9298"
                font.pixelSize: 12
                opacity: 0.6
            }
            Text {
                text: qsTr("Format")
                color: controller.selectedDisk.can_format
                       && controller.selectedDisk.target_kind === "partition"
                       ? "#0067b1" : "#8a9298"
                font.pixelSize: 12
                font.underline: formatMouse.containsMouse && formatMouse.enabled
                MouseArea {
                    id: formatMouse
                    anchors.fill: parent
                    enabled: controller.selectedDisk.can_format
                             && controller.selectedDisk.target_kind === "partition"
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: controller.useSelectedPartition()
                }
            }
            Text {
                text: qsTr("New")
                color: controller.selectedDisk.target_kind === "free" ? "#0067b1" : "#8a9298"
                font.pixelSize: 12
                font.underline: newMouse.containsMouse && newMouse.enabled
                MouseArea {
                    id: newMouse
                    anchors.fill: parent
                    enabled: controller.selectedDisk.target_kind === "free"
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: controller.useSelectedFreeSpace()
                }
            }
            Text {
                text: qsTr("Shrink")
                color: controller.selectedDisk.can_shrink
                       && controller.selectedDisk.target_kind === "partition"
                       ? "#0067b1" : "#8a9298"
                font.pixelSize: 12
                font.underline: shrinkMouse.containsMouse && shrinkMouse.enabled
                MouseArea {
                    id: shrinkMouse
                    anchors.fill: parent
                    enabled: controller.selectedDisk.can_shrink
                             && controller.selectedDisk.target_kind === "partition"
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: shrinkPanel.visible = true
                }
            }
            Text { text: qsTr("Extend"); color: "#8a9298"; font.pixelSize: 12; opacity: 0.6 }
        },

        Rectangle {
            id: shrinkPanel
            visible: false
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 309
            height: 60
            color: "#f4f8fb"
            border.color: "#aeb8bf"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9
                Text {
                    text: qsTr("Space to release for Aero7 (GiB):")
                    color: "#27343d"
                    font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
                AeroTextField {
                    id: shrinkAmount
                    width: 72
                    text: "24"
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator { bottom: 17; top: 2048 }
                }
                AeroButton {
                    width: 80
                    text: qsTr("Apply")
                    enabled: shrinkAmount.acceptableInput
                    onClicked: {
                        controller.prepareSelectedNtfsShrink(parseInt(shrinkAmount.text))
                        if (controller.diskSelectionReady)
                            shrinkPanel.visible = false
                    }
                }
                AeroButton {
                    width: 80
                    text: qsTr("Cancel")
                    onClicked: shrinkPanel.visible = false
                }
            }
        }
    ]
}
