import QtQuick
import "../components"

SetupPage {
    id: root
    anchors.fill: parent
    title: qsTr("Confirm the installation")
    description: qsTr("Review the exact disk and partition changes before setup begins.")
    showBack: true
    nextText: controller.demoMode && !documentationMode ? qsTr("Simulate install") : qsTr("Install now")

    readonly property string targetKind: controller.selectedDisk.target_kind || "disk"

    function selectedDisplayName() {
        const name = controller.selectedDisk.display_name
                     || controller.selectedDisk.model
                     || qsTr("Selected target")
        return documentationMode ? name.replace(" (simulation)", "") : name
    }

    function warningTitle() {
        if (targetKind === "free")
            return qsTr("Aero7 will use only the selected unallocated space")
        if (targetKind === "reuse_partition")
            return qsTr("The selected partition will be erased")
        if (targetKind === "shrink_ntfs")
            return qsTr("The selected Windows partition will be shrunk")
        return qsTr("Everything on this disk will be erased")
    }

    function warningDetail() {
        if (targetKind === "free")
            return qsTr("Setup will preserve all existing partitions and create a separate Aero7 EFI partition and root partition inside this unallocated region.")
        if (targetKind === "reuse_partition")
            return qsTr("Setup will erase only the selected partition, split its region into Aero7 EFI and root partitions, and preserve the other partitions on this disk.")
        if (targetKind === "shrink_ntfs")
            return qsTr("Setup will first run a read-only NTFS resize test, shrink Windows, and create Aero7 in the released space. Back up Windows and disable Fast Startup before continuing.")
        return qsTr("Setup will create a new Aero7 installation on the selected disk. This operation cannot be undone.")
    }

    body: [
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 202
            color: "#fffdf6"
            border.color: "#e3b45a"

            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 19
                spacing: 16

                Image {
                    width: 52
                    height: 52
                    source: "qrc:/assets/icons/warning.svg"
                    fillMode: Image.PreserveAspectFit
                }

                Column {
                    width: parent.width - 68
                    spacing: 8
                    Text {
                        width: parent.width
                        text: root.warningTitle()
                        color: "#4b340b"
                        font.pixelSize: 16
                    }
                    Text {
                        width: parent.width
                        text: root.warningDetail()
                        color: "#4f4b42"
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.bottomMargin: 18
                height: 78
                color: "#ffffff"
                border.color: "#c4c8ca"

                Image {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 43
                    height: 43
                    source: "qrc:/assets/icons/harddisk.svg"
                    fillMode: Image.PreserveAspectFit
                }
                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 64
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text { text: root.selectedDisplayName(); color: "#1d2b34"; font.pixelSize: 13 }
                    Text {
                        text: qsTr("Capacity: %1     Disk: %2")
                              .arg(controller.selectedDisk.size || controller.selectedDisk.free_space || "—")
                              .arg(controller.selectedDisk.disk_device || controller.selectedDisk.device || "—")
                        color: "#536069"
                        font.pixelSize: 12
                    }
                }
            }
        },
        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 224
            text: controller.demoMode && !documentationMode
                  ? qsTr("Simulation mode is active. Setup will show the complete flow without executing disk commands.")
                  : qsTr("For safety, setup will verify the disk, partition UUIDs, sizes, and sector boundaries again immediately before making any changes.")
            color: controller.demoMode && !documentationMode ? "#18772d" : "#7c2a18"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
    ]
}
