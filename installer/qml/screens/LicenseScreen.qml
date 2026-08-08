import QtQuick
import QtQuick.Controls
import "../components"

SetupPage {
    anchors.fill: parent
    title: qsTr("Please read the license terms")
    description: ""
    showBack: true
    nextEnabled: controller.licenseAccepted

    body: [
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 300
            color: "white"
            border.color: "#88949d"

            ScrollView {
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                TextArea {
                    readOnly: true
                    wrapMode: TextArea.Wrap
                    selectByMouse: true
                    color: "#15191d"
                    font.pixelSize: 13
                    text: qsTr("AERO7 SOFTWARE AND OPEN-SOURCE LICENSE NOTICE\n\nABOUT AERO7\nAero7 is an independent Linux distribution and desktop project built from Arch Linux, the Linux kernel, KDE Plasma, Qt, Cage, and Aero7 components. It is not Microsoft Windows and contains no licensed copy of Windows. Aero7 is not affiliated with or endorsed by Microsoft Corporation. Product names and trademarks belong to their respective owners.\n\nOPEN-SOURCE SOFTWARE\nMost software installed by Aero7 is free and open-source software. Each component remains governed by its own license, including licenses such as the GNU General Public License, GNU Lesser General Public License, MIT License, BSD licenses, and other approved terms. Those licenses may give you rights to inspect, use, modify, and redistribute source code. Accepting this notice does not remove or limit any rights granted by an individual open-source license.\n\nSOURCE CODE AND NOTICES\nCopyright notices, license texts, package metadata, and source references are provided in /usr/share/licenses, /usr/share/aero7, and the Aero7 project documentation. Third-party Arch Linux, KDE, Qt, Cage, Plymouth, theme, icon, font, and application packages retain their original authorship and licenses.\n\nINSTALLATION AND DATA LOSS\nErase-disk repartitions and formats the complete disk and permanently removes every operating system, application, account, and file on it. Advanced options can preserve existing partitions when you select unallocated space, erase only one explicitly selected partition, or shrink an NTFS partition and install into the released space. Formatting a selected partition destroys everything on that partition. Shrinking or modifying any partition can still cause data loss if the operation is interrupted or the filesystem is damaged. Back up important data, disable Windows Fast Startup, fully shut Windows down, and verify the disk model, size, serial number, and selected region before continuing. Windows may check its filesystem on the first boot after a shrink.\n\nNETWORK AND UPDATES\nSetup may contact configured Arch Linux and Aero7 package mirrors to retrieve signed packages and updates. Aero7 does not require product activation and this installer does not intentionally collect personal information or enable project telemetry. Mirror operators and installed network software may have their own policies.\n\nNO WARRANTY\nAero7 is beta software supplied without warranty, to the extent permitted by applicable law. The authors and distributors are not liable for lost data, downtime, hardware incompatibility, or other damage resulting from installation or use. Test this release in a disposable virtual machine before installing it on physical hardware.\n\nBy selecting the checkbox below, you acknowledge this notice, accept the Aero7 project terms, and agree that each included component remains subject to its own license.")
                }
            }
        },
        AeroCheckBox {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 316
            width: parent.width
            text: qsTr("I accept the Aero7 and third-party license terms")
            checked: controller.licenseAccepted
            onToggled: controller.licenseAccepted = checked
        }
    ]
}
