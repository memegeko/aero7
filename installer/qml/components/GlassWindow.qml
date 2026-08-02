import QtQuick
import QtQuick.Effects

Item {
    id: root

    property string title: "Aero7 Setup"
    property bool showBack: false
    property bool showCaptionButtons: true
    property string captionMode: showCaptionButtons ? "all" : "none"
    property int panelWidth: 780
    property int panelHeight: 560
    property bool useBackdrop: false
    default property alias contentData: content.data

    Item {
        id: frame
        width: root.panelWidth
        height: root.panelHeight
        anchors.centerIn: parent

        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 18
            height: parent.height + 18
            radius: 10
            color: "#62000000"
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 0.55
                blurMax: 32
                autoPaddingEnabled: true
            }
        }

        Item {
            id: glassSurface
            anchors.fill: parent
            clip: true

            Image {
                id: glassBackdrop
                x: -(1024 - root.panelWidth) / 2
                y: -(768 - root.panelHeight) / 2
                width: 1024
                height: 768
                source: "qrc:/assets/aero7-background.png"
                fillMode: Image.PreserveAspectCrop
                smooth: true
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 64
                    brightness: 0.08
                    contrast: -0.08
                    saturation: -0.16
                    autoPaddingEnabled: false
                }
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: "#66eef8fa" }
                    GradientStop { position: 0.12; color: "#51c5d9df" }
                    GradientStop { position: 0.55; color: "#4b7f9dac" }
                    GradientStop { position: 1; color: "#58728d9b" }
                }
            }

            Rectangle {
                x: 2
                y: 2
                width: parent.width - 4
                height: 29
                radius: 4
                gradient: Gradient {
                    GradientStop { position: 0; color: "#b9f2f8f8" }
                    GradientStop { position: 0.42; color: "#86cad9de" }
                    GradientStop { position: 1; color: "#687b94a2" }
                }
            }
        }

        Image {
            anchors.fill: parent
            anchors.margins: 1
            source: "qrc:/assets/smod/reflection.png"
            fillMode: Image.Stretch
            opacity: 0.09
            smooth: true
        }

        Rectangle {
            id: content
            x: 5
            y: 31
            width: parent.width - 10
            height: parent.height - 36
            color: root.useBackdrop ? "transparent" : "#ffffff"
            border.width: root.useBackdrop ? 0 : 1
            border.color: "#b0132632"
            clip: true

            Image {
                anchors.fill: parent
                visible: root.useBackdrop
                source: "qrc:/assets/aero7-background.png"
                fillMode: Image.PreserveAspectCrop
                smooth: true
                z: -1
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 7
            color: "transparent"
            border.width: 1
            border.color: "#d6e8f0f3"
            z: 5
        }

        Item {
            id: titleBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 30
            z: 6

            Image {
                id: backButton
                visible: root.showBack
                width: 29
                height: 27
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.top: parent.top
                anchors.topMargin: 2
                source: "qrc:/assets/smod/back.png"
                sourceClipRect: Qt.rect(0,
                    !controller.canGoBack ? 81
                    : backMouse.pressed ? 54
                    : backMouse.containsMouse ? 27 : 0,
                    29, 27)
                fillMode: Image.Stretch
                smooth: true

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    enabled: controller.canGoBack
                    hoverEnabled: true
                    onClicked: controller.goBack()
                }
            }

            Image {
                id: titleIcon
                width: 17
                height: 17
                anchors.left: parent.left
                anchors.leftMargin: root.showBack ? 43 : 11
                anchors.verticalCenter: parent.verticalCenter
                source: "qrc:/assets/aero7-logo-plain.png"
                smooth: true
            }

            Text {
                anchors.left: titleIcon.right
                anchors.leftMargin: 6
                anchors.right: captionButtons.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: root.title
                color: "#111111"
                style: Text.Raised
                styleColor: "#d9ffffff"
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Row {
                id: captionButtons
                visible: root.captionMode !== "none"
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.top: parent.top
                anchors.topMargin: 1
                spacing: 0

                CaptionButton { visible: root.captionMode === "all"; buttonType: "minimize" }
                CaptionButton { visible: root.captionMode === "all"; buttonType: "maximize" }
                CaptionButton { visible: root.captionMode === "all" || root.captionMode === "close"; buttonType: "close" }
            }
        }
    }
}
