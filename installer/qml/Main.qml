pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: window
    readonly property bool blackTransition: [
        "ApplyingSettingsScreen",
        "VideoPerformanceScreen",
        "FinalizingScreen"
    ].indexOf(controller.screenId) >= 0

    visible: true
    visibility: captureMode ? Window.Windowed : Window.FullScreen
    width: captureMode ? captureWidth : 1024
    height: captureMode ? captureHeight : 768
    color: blackTransition ? "#000000" : "#020915"
    title: controller.oobeMode ? qsTr("Set Up Aero7") : qsTr("Install Aero7")

    Image {
        anchors.fill: parent
        visible: !window.blackTransition
        source: "qrc:/assets/aero7-background.png"
        fillMode: Image.PreserveAspectCrop
        smooth: true
    }

    Rectangle {
        anchors.fill: parent
        visible: !window.blackTransition
        color: "#071d4a"
        opacity: 0.08
    }

    Item {
        id: designCanvas
        width: 1024
        height: 768
        anchors.centerIn: parent
        scale: Math.min(window.width / width, window.height / height)

        Loader {
            id: screenLoader
            anchors.fill: parent
            source: "screens/" + controller.screenId + ".qml"
            focus: true
        }

        // QXL and wlroots can otherwise preserve pixels from transparent
        // regions of the previous Loader item. Cover two render frames with
        // the canonical background, then remove the cover so the complete
        // replacement screen is damaged and repainted in one pass.
        Item {
            id: fullFrameRepaintGuard
            anchors.fill: parent
            visible: false
            z: 900

            Rectangle {
                anchors.fill: parent
                color: window.blackTransition ? "#000000" : "#020915"
            }

            Image {
                anchors.fill: parent
                visible: !window.blackTransition
                source: "qrc:/assets/aero7-background.png"
                fillMode: Image.PreserveAspectCrop
                smooth: true
            }

            Rectangle {
                anchors.fill: parent
                visible: !window.blackTransition
                color: "#071d4a"
                opacity: 0.08
            }
        }

        Connections {
            target: controller

            function onScreenChanged() {
                fullFrameRepaintGuard.visible = true
                releaseFullFrameRepaint.restart()
            }
        }

        Timer {
            id: releaseFullFrameRepaint
            interval: 34
            repeat: false
            onTriggered: fullFrameRepaintGuard.visible = false
        }

        Rectangle {
            visible: controller.demoMode && !documentationMode && !window.blackTransition
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 18
            radius: 3
            color: "#d9efffff"
            border.color: "#78a8c9"
            width: demoLabel.implicitWidth + 22
            height: 28
            z: 20

            Text {
                id: demoLabel
                anchors.centerIn: parent
                text: qsTr("SIMULATION — disks are untouched")
                color: "#174668"
                font.pixelSize: 13
                font.bold: true
            }
        }

        Rectangle {
            visible: controller.statusText.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            width: 760
            height: Math.min(92, Math.max(38, statusLabel.implicitHeight + 18))
            radius: 5
            color: "#e8fff4f2"
            border.color: "#b9473b"
            clip: true
            z: 30

            Text {
                id: statusLabel
                anchors.fill: parent
                anchors.margins: 9
                text: controller.statusText
                color: "#8c231c"
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: controller.desktopHandoff ? 1 : 0
        visible: opacity > 0
        z: 1000

        Behavior on opacity {
            NumberAnimation {
                duration: 900
                easing.type: Easing.InOutQuad
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: controller.canGoBack
        onActivated: controller.goBack()
    }
}
