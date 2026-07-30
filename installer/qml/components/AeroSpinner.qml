import QtQuick

Image {
    id: root

    property int frame: 0
    property bool running: true

    width: 20
    height: 20
    source: "qrc:/assets/loading/spinner_" + frame + ".png"
    fillMode: Image.PreserveAspectFit
    smooth: true
    cache: true

    Timer {
        interval: 55
        repeat: true
        running: root.running && root.visible
        onTriggered: root.frame = (root.frame + 1) % 18
    }
}
