import QtQuick

Item {
    id: control

    property string buttonType: "minimize"
    signal clicked

    readonly property int naturalWidth: buttonType === "close" ? 49
                                      : buttonType === "maximize" ? 27 : 29
    readonly property string stateSuffix: mouse.pressed ? "-active"
                                               : mouse.containsMouse ? "-hover" : ""

    implicitWidth: naturalWidth
    implicitHeight: 20
    width: implicitWidth
    height: implicitHeight
    opacity: enabled ? 1 : 0.55

    Image {
        anchors.fill: parent
        source: "qrc:/assets/smod/" + control.buttonType + control.stateSuffix + ".png"
        fillMode: Image.Stretch
        smooth: false
    }

    Image {
        anchors.centerIn: parent
        source: "qrc:/assets/smod/" + control.buttonType + control.stateSuffix + "-glyph.png"
        smooth: false
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: control.enabled
        hoverEnabled: true
        onClicked: control.clicked()
    }
}
