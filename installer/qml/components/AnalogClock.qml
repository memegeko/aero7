import QtQuick

Item {
    id: root

    implicitWidth: 142
    implicitHeight: 142
    property date now: new Date()
    onNowChanged: face.requestPaint()

    Canvas {
        id: face
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            var w = width
            var h = height
            var cx = w / 2
            var cy = h / 2
            var radius = Math.min(w, h) / 2 - 4
            ctx.reset()

            var rim = ctx.createRadialGradient(cx - radius * .25, cy - radius * .3, radius * .12, cx, cy, radius)
            rim.addColorStop(0, "#ffffff")
            rim.addColorStop(.72, "#dbe4e8")
            rim.addColorStop(1, "#718692")
            ctx.beginPath()
            ctx.arc(cx, cy, radius, 0, Math.PI * 2)
            ctx.fillStyle = rim
            ctx.fill()
            ctx.lineWidth = 1.5
            ctx.strokeStyle = "#526c79"
            ctx.stroke()

            ctx.beginPath()
            ctx.arc(cx, cy, radius - 7, 0, Math.PI * 2)
            ctx.fillStyle = "#edf4f6"
            ctx.fill()
            ctx.strokeStyle = "#a8bcc5"
            ctx.lineWidth = 1
            ctx.stroke()

            for (var i = 0; i < 60; ++i) {
                var a = (i / 60) * Math.PI * 2 - Math.PI / 2
                var major = i % 5 === 0
                var r1 = radius - (major ? 17 : 13)
                var r2 = radius - 9
                ctx.beginPath()
                ctx.moveTo(cx + Math.cos(a) * r1, cy + Math.sin(a) * r1)
                ctx.lineTo(cx + Math.cos(a) * r2, cy + Math.sin(a) * r2)
                ctx.strokeStyle = major ? "#3c5c69" : "#829ba6"
                ctx.lineWidth = major ? 2 : 1
                ctx.stroke()
            }

            var hour = root.now.getHours() % 12 + root.now.getMinutes() / 60
            var minute = root.now.getMinutes() + root.now.getSeconds() / 60
            var second = root.now.getSeconds()

            function hand(value, divisions, length, lineWidth, color) {
                var angle = value / divisions * Math.PI * 2 - Math.PI / 2
                ctx.beginPath()
                ctx.moveTo(cx - Math.cos(angle) * 8, cy - Math.sin(angle) * 8)
                ctx.lineTo(cx + Math.cos(angle) * length, cy + Math.sin(angle) * length)
                ctx.strokeStyle = color
                ctx.lineWidth = lineWidth
                ctx.lineCap = "round"
                ctx.stroke()
            }

            hand(hour, 12, radius * .48, 4, "#314b56")
            hand(minute, 60, radius * .68, 3, "#314b56")
            hand(second, 60, radius * .72, 1, "#2f7e9c")
            ctx.beginPath()
            ctx.arc(cx, cy, 5, 0, Math.PI * 2)
            ctx.fillStyle = "#4e6a75"
            ctx.fill()
            ctx.beginPath()
            ctx.arc(cx - 1, cy - 1, 1.5, 0, Math.PI * 2)
            ctx.fillStyle = "#dcebed"
            ctx.fill()
        }
    }
}
