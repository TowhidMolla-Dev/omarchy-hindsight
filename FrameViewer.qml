import QtQuick
import Quickshell

FloatingWindow {
  id: root

  property var frame: null

  title: frame
    ? "Hindsight image viewer · " + frame.day + " " + frame.time + " · " + (frame.app || "unknown")
    : "Hindsight image viewer"
  visible: false
  implicitWidth: 1440
  implicitHeight: 900
  minimumSize: Qt.size(640, 400)
  color: "#101010"

  onClosed: visible = false
  onFrameChanged: {
    visible = frame !== null
  }

  Image {
    anchors.fill: parent
    anchors.margins: 12
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    cache: false
    source: {
      if (!root.frame || !root.frame.path) return ""
      var parts = String(root.frame.path).split("/")
      var encoded = []
      for (var i = 0; i < parts.length; i++)
        encoded.push(encodeURIComponent(parts[i]))
      return "file://" + encoded.join("/")
    }
    sourceSize.width: width
  }
}
