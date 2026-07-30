import QtQuick

Item {
    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        color: "#020304"
    }

    Column {
        anchors.centerIn: parent
        spacing: 26

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Setup is checking video performance")
            color: "#f4f7f9"
            font.pixelSize: 24
            font.weight: Font.Light
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 330
            height: 38

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#00162a3c" }
                    GradientStop { position: 0.38; color: "#326c9cb5" }
                    GradientStop { position: 0.5; color: "#f6fbffff" }
                    GradientStop { position: 0.62; color: "#326c9cb5" }
                    GradientStop { position: 1.0; color: "#00162a3c" }
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 28
                height: 28
                radius: 14
                color: "#efffffff"
                opacity: 0.72
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 550; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.82; duration: 550; easing.type: Easing.InOutSine }
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 10
                height: 10
                radius: 5
                color: "#ffffff"
            }
        }
    }
}
