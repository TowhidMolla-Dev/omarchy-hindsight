import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root

  moduleName: "dhirajkhanna.hindsight"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property int cursor: 0
  property string mode: "search"
  property var selectedFrame: null
  property string confirmForget: ""

  readonly property var service: bar && bar.shell ? bar.shell.serviceFor("dhirajkhanna.hindsight") : null
  readonly property bool paused: service ? service.paused === true : false
  readonly property bool capturing: service ? service.capturing === true : false
  readonly property int frames: service ? service.frames : 0
  readonly property int today: service ? service.today : 0
  readonly property int pendingOcr: service ? service.pendingOcr : 0
  readonly property string reason: service ? service.reason : ""
  readonly property real bytes: service ? service.bytes : 0
  readonly property real budget: service ? service.budget : 0
  readonly property var results: service ? service.results : []
  readonly property bool searching: service ? service.searching === true : false
  readonly property string query: service ? service.query : ""
  readonly property string blockedBy: service ? service.blockedBy : ""
  readonly property string coverageText: service ? service.coverageText : ""
  readonly property string coverageBasis: service ? service.coverageBasis : ""
  readonly property var budgetOptions: service ? service.budgetOptions : []
  readonly property var timelineDays: service ? service.timelineDays : []
  readonly property var timelineFrames: service ? service.timelineFrames : []
  readonly property string timelineDay: service ? service.timelineDay : ""
  readonly property bool timelineLoading: service ? service.timelineLoading : false
  readonly property int retentionDays: service ? service.retentionDays : 0
  readonly property string controlError: service ? service.controlError : ""

  property bool showStorage: false

  function open() { root.controller.show() }
  function close() { root.controller.hide() }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function sizeText(value) {
    return root.service ? root.service.humanBytes(value) : "0 B"
  }

  function moveCursor(delta) {
    var items = root.mode === "timeline" ? root.timelineFrames : root.results
    var count = items ? items.length : 0
    if (count === 0) return
    root.cursor = Math.max(0, Math.min(count - 1, root.cursor + delta))
    list.positionViewAtIndex(root.cursor, ListView.Contain)
  }

  function frameSource(path) {
    if (!path) return ""
    var parts = String(path).split("/")
    var encoded = []
    for (var i = 0; i < parts.length; i++)
      encoded.push(encodeURIComponent(parts[i]))
    return "file://" + encoded.join("/")
  }

  function selectFrame(frame) {
    root.selectedFrame = frame
    root.confirmForget = ""
  }

  function copyFrame(id) {
    if (!root.service) return
    var frameId = Number(id)
    if (!isFinite(frameId) || frameId <= 0 || Math.floor(frameId) !== frameId) return
    copier.command = [root.service.helperPath, "copy", String(frameId)]
    copier.running = true
  }

  function copyCurrent() {
    if (root.selectedFrame) {
      root.copyFrame(root.selectedFrame.id)
      return
    }
    var items = root.mode === "timeline" ? root.timelineFrames : root.results
    if (items && root.cursor < items.length) root.copyFrame(items[root.cursor].id)
  }

  Process { id: copier; running: false }

  onOpenedChanged: {
    if (root.opened) {
      root.cursor = 0
      if (root.service) {
        root.service.search(searchBox.text)
        root.service.refreshBudget()
        root.service.refreshTimeline()
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: root.mode === "search" ? searchBox : keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(Math.min(Style.space(680), column.implicitHeight))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Column {
        id: column
        width: parent.width
        spacing: Style.space(8)

        // -- what it is doing right now -------------------------------------
        Row {
          width: parent.width
          spacing: Style.space(8)

          Text {
            textFormat: Text.PlainText
            width: parent.width - pauseButton.width - Style.space(8)
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
            text: {
              if (root.paused) return "Paused - nothing is being captured."
              if (root.blockedBy !== "") return "Holding off: this window matches \"" + root.blockedBy + "\"."
              if (!root.capturing && root.reason !== "")
                return "Holding off: " + root.reason + "."
              var parts = [root.today + " captured today", root.sizeText(root.bytes) + " of " + root.sizeText(root.budget)]
              if (root.pendingOcr > 0) parts.push(root.pendingOcr + " still being read")
              return parts.join("  ·  ")
            }
          }

          PanelActionButton {
            id: pauseButton
            iconText: root.paused ? "󰐊" : "󰏤"
            tooltipText: root.paused ? "Resume capturing" : "Pause capturing"
            onClicked: if (root.service) root.service.setPaused(!root.paused)
          }
        }

        PanelSeparator { width: parent.width }

        Row {
          width: parent.width
          spacing: Style.space(6)

          Button {
            text: "Search"
            foreground: Color.foreground
            onClicked: {
              root.mode = "search"
              root.selectedFrame = null
              root.cursor = 0
            }
          }

          Button {
            text: "Timeline"
            foreground: Color.foreground
            onClicked: {
              root.mode = "timeline"
              root.selectedFrame = null
              root.cursor = 0
              if (root.service) root.service.refreshTimeline()
            }
          }
        }

        TextField {
          id: searchBox
          width: parent.width
          visible: root.mode === "search"
          foreground: Color.foreground
          placeholderText: "Search what you have seen"
          onTextChanged: {
            root.cursor = 0
            root.selectedFrame = null
            debounce.restart()
          }
          onAccepted: root.copyCurrent()
          Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Down) { root.moveCursor(1); event.accepted = true }
            else if (event.key === Qt.Key_Up) { root.moveCursor(-1); event.accepted = true }
            else if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
          }
        }

        // OCR text is long; firing a query on every keystroke would spawn a
        // process per character.
        Timer {
          id: debounce
          interval: 180
          repeat: false
          onTriggered: if (root.service) root.service.search(searchBox.text)
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          visible: root.mode === "search"
            && searchBox.text.length > 0 && !root.searching && root.results.length === 0
          color: Color.foreground
          opacity: 0.7
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          text: root.frames === 0
                ? "Nothing captured yet. Leave it running and come back."
                : "No screen you have seen contains that."
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          visible: root.mode === "search" && searchBox.text.length === 0
          color: Color.foreground
          opacity: 0.7
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          text: root.frames === 0
                ? "Nothing captured yet."
                : "Search remembered screens, or switch to Timeline to browse by day."
        }

        Row {
          width: parent.width
          spacing: Style.space(6)
          visible: root.mode === "timeline" && !root.selectedFrame

          Button {
            id: earlierButton
            text: "Earlier"
            foreground: Color.foreground
            enabled: root.service && root.timelineDays.length > 0
              && root.timelineDays.findIndex(function(entry) {
                   return entry.day === root.timelineDay
                 }) < root.timelineDays.length - 1
            onClicked: {
              var index = root.timelineDays.findIndex(function(entry) {
                return entry.day === root.timelineDay
              })
              if (index >= 0 && index + 1 < root.timelineDays.length) {
                root.cursor = 0
                root.service.loadTimeline(root.timelineDays[index + 1].day)
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width - earlierButton.width - laterButton.width - Style.space(12)
            horizontalAlignment: Text.AlignHCenter
            anchors.verticalCenter: parent.verticalCenter
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            text: root.timelineDay === "" ? "No captured days" : root.timelineDay
          }

          Button {
            id: laterButton
            text: "Later"
            foreground: Color.foreground
            enabled: root.service && root.timelineDays.length > 0
              && root.timelineDays.findIndex(function(entry) {
                   return entry.day === root.timelineDay
                 }) > 0
            onClicked: {
              var index = root.timelineDays.findIndex(function(entry) {
                return entry.day === root.timelineDay
              })
              if (index > 0) {
                root.cursor = 0
                root.service.loadTimeline(root.timelineDays[index - 1].day)
              }
            }
          }
        }

        ListView {
          id: list
          width: parent.width
          height: Math.min(Style.space(220), contentHeight)
          visible: !root.selectedFrame
            && (root.mode === "timeline" ? root.timelineFrames.length > 0 : root.results.length > 0)
          clip: true
          model: root.mode === "timeline" ? root.timelineFrames : root.results
          spacing: Style.space(4)
          currentIndex: root.cursor

          delegate: Rectangle {
            width: list.width
            height: entry.implicitHeight + Style.space(10)
            radius: Style.cornerRadius
            color: index === root.cursor ? Style.selectedFill : "transparent"

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onEntered: root.cursor = index
              onClicked: { root.cursor = index; root.selectFrame(modelData) }
            }

            Row {
              id: entry
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(6)
              anchors.rightMargin: Style.space(6)
              spacing: Style.space(8)

              Image {
                id: thumb
                width: Style.space(64)
                height: Style.space(40)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                source: root.frameSource(modelData.path)
                sourceSize.width: Style.space(128)
              }

              Column {
                width: entry.width - thumb.width - Style.space(8)
                spacing: Style.space(2)

                Text {
                  textFormat: Text.PlainText
                  width: parent.width
                  color: Color.foreground
                  opacity: 0.65
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  text: modelData.time + "  ·  " + (modelData.app || "unknown")
                }

                Text {
                  textFormat: Text.PlainText
                  width: parent.width
                  color: Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                  maximumLineCount: 2
                  elide: Text.ElideRight
                  text: root.mode === "search"
                    ? modelData.snippet
                    : (modelData.title || "Captured screen")
                }
              }
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          visible: root.mode === "timeline" && !root.selectedFrame
            && root.timelineLoading
          color: Color.foreground
          opacity: 0.7
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          text: "Loading captures…"
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          visible: root.mode === "timeline" && !root.selectedFrame
            && !root.timelineLoading && root.timelineFrames.length === 0
          color: Color.foreground
          opacity: 0.7
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          text: root.timelineDay === "" ? "No captures in the archive."
            : "No captures on " + root.timelineDay + "."
        }

        Column {
          width: parent.width
          spacing: Style.space(6)
          visible: root.selectedFrame !== null

          Row {
            width: parent.width
            spacing: Style.space(6)

            Button {
              text: "Back to captures"
              foreground: Color.foreground
              onClicked: {
                root.selectedFrame = null
                root.confirmForget = ""
              }
            }

            Button {
              text: "Copy text"
              foreground: Color.foreground
              onClicked: root.copyFrame(root.selectedFrame.id)
            }

            Button {
              text: "Forget frame"
              foreground: Color.foreground
              onClicked: root.confirmForget = "frame"
            }
          }

          Image {
            width: parent.width
            height: Style.space(210)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
            source: root.selectedFrame ? root.frameSource(root.selectedFrame.path) : ""
            sourceSize.width: Style.space(800)
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
            text: root.selectedFrame
              ? root.selectedFrame.day + "  ·  " + root.selectedFrame.time
                + "  ·  " + (root.selectedFrame.app || "unknown")
              : ""
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            visible: root.selectedFrame && root.selectedFrame.title
            text: root.selectedFrame ? root.selectedFrame.title || "" : ""
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            color: Color.foreground
            opacity: 0.7
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            visible: root.selectedFrame
              && root.mode === "search" && root.selectedFrame.snippet
            text: root.selectedFrame ? root.selectedFrame.snippet || "" : ""
          }

          Row {
            width: parent.width
            spacing: Style.space(6)
            visible: root.confirmForget === "frame"

            Text {
              textFormat: Text.PlainText
              width: parent.width - cancelFrameButton.width - deleteFrameButton.width - Style.space(12)
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
              text: "Permanently delete this frame and its indexed text?"
            }

            Button {
              id: cancelFrameButton
              text: "Cancel"
              foreground: Color.foreground
              onClicked: root.confirmForget = ""
            }

            Button {
              id: deleteFrameButton
              text: "Delete"
              foreground: Color.foreground
              onClicked: {
                if (root.service && root.selectedFrame)
                  root.service.forget("frame", root.selectedFrame.id)
                root.selectedFrame = null
                root.confirmForget = ""
              }
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          visible: root.mode === "timeline" && root.selectedFrame === null
            && root.timelineDay !== "" && root.timelineFrames.length > 0
          color: Color.foreground
          opacity: 0.6
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          text: "Select a capture to preview it."
        }

        // -- how far back this reaches, and the one knob that changes it ----
        // Disk is the only limit that matters here, so it is stated in the
        // unit the limit is actually felt in: days, not gigabytes.
        Row {
          width: parent.width
          spacing: Style.space(8)

          Text {
            textFormat: Text.PlainText
            id: coverageLine
            width: parent.width - storageButton.width - Style.space(8)
            color: Color.foreground
            opacity: 0.75
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            text: {
              var size = root.sizeText(root.budget)
              if (root.coverageText === "") return "Storage: " + size
              var line = size + "  ·  holds " + root.coverageText
              if (root.coverageBasis === "default") line += " (estimate)"
              return line
            }
          }

          PanelActionButton {
            id: storageButton
            iconText: "󰋊"
            tooltipText: "Storage, age limit, and deletion controls"
            onClicked: root.showStorage = !root.showStorage
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(6)
          visible: root.showStorage

          Text {
            textFormat: Text.PlainText
            width: parent.width
            color: Color.foreground
            opacity: 0.6
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
            text: root.coverageBasis === "measured"
              ? "Estimated from your own capture rate."
              : "Estimated from this machine; it sharpens after a few days."
          }

          Flow {
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: root.budgetOptions

              Rectangle {
                id: chip
                readonly property bool current: root.budget > 0
                  && Math.abs(root.budget - modelData.mb * 1048576) < 1048576
                width: chipLabel.implicitWidth + Style.space(16)
                height: chipLabel.implicitHeight + Style.space(10)
                radius: Style.space(4)
                color: chip.current ? Color.foreground : "transparent"
                border.width: 1
                border.color: Color.foreground
                opacity: chip.current ? 1.0 : 0.45

                Text {
                  textFormat: Text.PlainText
                  id: chipLabel
                  anchors.centerIn: parent
                  color: chip.current ? Color.background : Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  text: modelData.label
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: if (root.service) root.service.setBudget(modelData.mb)
                  onEntered: hint.text = modelData.label + " holds " + modelData.text
                }
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            id: hint
            width: parent.width
            color: Color.foreground
            opacity: 0.6
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
            text: "Lowering this deletes the oldest frames straight away."
          }

          PanelSeparator { width: parent.width }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            text: "Automatic age limit"
          }

          Flow {
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: [
                { days: 0, label: "Never" },
                { days: 7, label: "7 days" },
                { days: 30, label: "30 days" },
                { days: 90, label: "90 days" }
              ]

              Rectangle {
                id: retentionChip
                readonly property bool current: root.retentionDays === modelData.days
                width: retentionLabel.implicitWidth + Style.space(16)
                height: retentionLabel.implicitHeight + Style.space(10)
                radius: Style.space(4)
                color: retentionChip.current ? Color.foreground : "transparent"
                border.width: 1
                border.color: Color.foreground
                opacity: retentionChip.current ? 1.0 : 0.45

                Text {
                  textFormat: Text.PlainText
                  id: retentionLabel
                  anchors.centerIn: parent
                  color: retentionChip.current ? Color.background : Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  text: modelData.label
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: if (root.service) root.service.setRetention(modelData.days)
                }
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            color: Color.foreground
            opacity: 0.6
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
            text: "Changing the age limit immediately removes older frames."
          }

          Row {
            width: parent.width
            spacing: Style.space(6)

            Button {
              text: "Forget this day"
              foreground: Color.foreground
              enabled: root.timelineDay !== ""
              onClicked: root.confirmForget = "day"
            }

            Button {
              text: "Forget everything"
              foreground: Color.foreground
              enabled: root.frames > 0
              onClicked: root.confirmForget = "all"
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(6)
            visible: root.confirmForget === "day" || root.confirmForget === "all"

            Text {
              textFormat: Text.PlainText
              width: parent.width - cancelHistoryButton.width - deleteHistoryButton.width - Style.space(12)
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
              text: root.confirmForget === "all"
                ? "Permanently delete all captured screens and indexed text?"
                : "Permanently delete every capture from " + root.timelineDay + "?"
            }

            Button {
              id: cancelHistoryButton
              text: "Cancel"
              foreground: Color.foreground
              onClicked: root.confirmForget = ""
            }

            Button {
              id: deleteHistoryButton
              text: "Delete"
              foreground: Color.foreground
              onClicked: {
                if (root.service) root.service.forget(
                  root.confirmForget === "all" ? "all" : root.timelineDay)
                root.selectedFrame = null
                root.confirmForget = ""
              }
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          visible: root.controlError !== ""
          color: Color.foreground
          opacity: 0.8
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          text: root.controlError
        }

        PanelSeparator { width: parent.width; visible: root.frames > 0 }

        Row {
          width: parent.width
          spacing: Style.space(8)
          visible: root.frames > 0

          Text {
            textFormat: Text.PlainText
            color: Color.foreground
            opacity: 0.6
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            text: "Local only. Never leaves this machine."
          }
        }
      }
    }
  }
}
