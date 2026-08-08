import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import "../components"

SetupPage {
    id: root
    anchors.fill: parent
    title: qsTr("Where do you want to install Aero7?")
    description: ""
    showBack: true
    nextEnabled: controller.diskSelectionReady
    property string pendingAction: ""
    property string pendingTitle: ""
    property string pendingMessage: ""
    property url pendingDriver: ""

    function closeEditors() {
        newPanel.visible = false
        shrinkPanel.visible = false
        extendPanel.visible = false
    }

    function confirmAction(action, title, message) {
        pendingAction = action
        pendingTitle = title
        pendingMessage = message
        confirmationOverlay.visible = true
    }

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
                            root.closeEditors()
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
            spacing: 34

            DriveAction {
                text: qsTr("Refresh")
                iconSource: "qrc:/assets/icons/refresh.svg"
                toolTipText: qsTr("Rescan all disks and partitions and update the list.")
                onTriggered: {
                    root.closeEditors()
                    controller.refreshDisks()
                }
            }
            DriveAction {
                text: qsTr("Load Driver")
                iconSource: "qrc:/assets/icons/load-driver.svg"
                toolTipText: qsTr("Load an additional storage or controller driver when a disk is not detected.")
                onTriggered: driverDialog.open()
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
                    root.closeEditors()
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
            spacing: 26

            DriveAction {
                text: qsTr("Delete")
                iconSource: "qrc:/assets/icons/delete-partition.svg"
                actionEnabled: controller.selectedDisk.can_delete === true
                toolTipText: qsTr("Delete the selected partition and turn its space into unallocated space.")
                onTriggered: root.confirmAction(
                    "delete",
                    qsTr("Delete this partition?"),
                    qsTr("All files and data on %1 will be permanently lost. This action cannot be undone.")
                        .arg(controller.selectedDisk.display_name || qsTr("the selected partition")))
            }
            DriveAction {
                text: qsTr("Format")
                iconSource: "qrc:/assets/icons/format-partition.svg"
                actionEnabled: controller.selectedDisk.can_format === true
                toolTipText: qsTr("Format the selected partition for Aero7.")
                onTriggered: root.confirmAction(
                    "format",
                    qsTr("Format this partition?"),
                    qsTr("All existing data on %1 will be erased when installation begins.")
                        .arg(controller.selectedDisk.display_name || qsTr("the selected partition")))
            }
            DriveAction {
                text: qsTr("New")
                iconSource: "qrc:/assets/icons/new-partition.svg"
                actionEnabled: controller.selectedDisk.target_kind === "free"
                               && controller.selectedDisk.can_install === true
                toolTipText: qsTr("Create a new Aero7 target from the selected unallocated space.")
                onTriggered: {
                    root.closeEditors()
                    newAmount.text = Math.floor(Number(controller.selectedDisk.region_size_bytes) / 1073741824).toString()
                    newPanel.visible = true
                }
            }
            DriveAction {
                text: qsTr("Shrink")
                iconSource: "qrc:/assets/icons/extend-partition.svg"
                actionEnabled: controller.selectedDisk.can_shrink === true
                toolTipText: qsTr("Shrink the selected NTFS partition to release unallocated space for Aero7.")
                onTriggered: {
                    root.closeEditors()
                    shrinkPanel.visible = true
                }
            }
            DriveAction {
                text: qsTr("Extend")
                iconSource: "qrc:/assets/icons/extend-partition.svg"
                actionEnabled: controller.selectedDisk.can_extend === true
                toolTipText: qsTr("Increase the selected partition using adjacent unallocated space.")
                onTriggered: {
                    root.closeEditors()
                    extendAmount.text = Math.floor(Number(controller.selectedDisk.adjacent_free_size_bytes) / 1073741824).toString()
                    extendPanel.visible = true
                }
            }
        },

        Rectangle {
            id: newPanel
            visible: false
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 319
            height: 64
            color: "#f4f8fb"
            border.color: "#aeb8bf"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9
                Text {
                    text: qsTr("New Aero7 partition size (GiB):")
                    color: "#27343d"
                    font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
                AeroTextField {
                    id: newAmount
                    width: 72
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator {
                        bottom: 17
                        top: Math.max(17, Math.floor(Number(controller.selectedDisk.region_size_bytes || 0) / 1073741824))
                    }
                }
                AeroButton {
                    width: 80
                    text: qsTr("Apply")
                    enabled: newAmount.acceptableInput
                    onClicked: {
                        controller.useSelectedFreeSpace(parseInt(newAmount.text))
                        if (controller.diskSelectionReady)
                            newPanel.visible = false
                    }
                }
                AeroButton { width: 80; text: qsTr("Cancel"); onClicked: newPanel.visible = false }
            }
        },

        Rectangle {
            id: shrinkPanel
            visible: false
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 319
            height: 64
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
        },

        Rectangle {
            id: extendPanel
            visible: false
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 319
            height: 64
            color: "#f4f8fb"
            border.color: "#aeb8bf"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9
                Text {
                    text: qsTr("Space to add from the adjacent unallocated area (GiB):")
                    color: "#27343d"
                    font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
                AeroTextField {
                    id: extendAmount
                    width: 72
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator {
                        bottom: 1
                        top: Math.max(1, Math.floor(Number(controller.selectedDisk.adjacent_free_size_bytes || 0) / 1073741824))
                    }
                }
                AeroButton {
                    width: 80
                    text: qsTr("Apply")
                    enabled: extendAmount.acceptableInput
                    onClicked: root.confirmAction(
                        "extend",
                        qsTr("Extend this partition?"),
                        qsTr("Aero7 will add %1 GiB to %2. Back up important data before changing a partition boundary.")
                            .arg(extendAmount.text)
                            .arg(controller.selectedDisk.display_name || qsTr("the selected partition")))
                }
                AeroButton { width: 80; text: qsTr("Cancel"); onClicked: extendPanel.visible = false }
            }
        },

        Rectangle {
            id: confirmationOverlay
            visible: false
            anchors.fill: parent
            z: 100
            color: "#88000000"

            Rectangle {
                anchors.centerIn: parent
                width: 480
                height: 176
                color: "#ffffff"
                border.color: "#657681"
                border.width: 1

                Image {
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.top: parent.top
                    anchors.topMargin: 22
                    width: 36
                    height: 36
                    source: "qrc:/assets/icons/warning.svg"
                }
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 66
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.top: parent.top
                    anchors.topMargin: 19
                    text: root.pendingTitle
                    color: "#15242d"
                    font.pixelSize: 16
                    font.bold: true
                }
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 66
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.top: parent.top
                    anchors.topMargin: 52
                    text: root.pendingMessage
                    color: "#27343d"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    spacing: 9
                    AeroButton {
                        width: 92
                        text: root.pendingAction === "delete" ? qsTr("Delete") : qsTr("Continue")
                        onClicked: {
                            confirmationOverlay.visible = false
                            if (root.pendingAction === "delete")
                                controller.deleteSelectedPartition()
                            else if (root.pendingAction === "format")
                                controller.useSelectedPartition()
                            else if (root.pendingAction === "extend") {
                                controller.extendSelectedPartition(parseInt(extendAmount.text))
                                extendPanel.visible = false
                            } else if (root.pendingAction === "driver")
                                controller.loadStorageDriver(root.pendingDriver)
                            root.pendingAction = ""
                        }
                    }
                    AeroButton {
                        width: 92
                        text: qsTr("Cancel")
                        onClicked: {
                            confirmationOverlay.visible = false
                            root.pendingAction = ""
                        }
                    }
                }
            }
        }
    ]

    FileDialog {
        id: driverDialog
        title: qsTr("Load a storage driver")
        nameFilters: [qsTr("Linux kernel modules (*.ko *.ko.xz *.ko.zst)")]
        onAccepted: {
            root.pendingDriver = selectedFile
            root.confirmAction(
                "driver",
                qsTr("Load this storage driver?"),
                qsTr("Load only a trusted driver built for this Aero7 kernel. An incompatible kernel module can make the live installer unstable."))
        }
    }
}
