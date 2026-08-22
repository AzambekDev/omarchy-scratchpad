import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "azambekdev.scratchpad"

  // User Settings
  property string defaultTab: setting("defaultTab", "todos")
  property bool showTaskCount: setting("showTaskCount", true) !== false
  property bool compactView: setting("compactView", false) === true

  // State
  property bool popupOpen: false
  readonly property bool opened: popupOpen
  property string activeTab: defaultTab // "todos" | "notes" | "snippets"
  property int cursorIndex: 0
  property bool keyboardActive: false
  property string toastMessage: ""
  property string searchFilter: ""

  // Persistence Paths
  readonly property string dataDir: Quickshell.env("HOME") + "/.local/share/omarchy/scratchpad"
  readonly property string notesPath: dataDir + "/notes.md"
  readonly property string todosPath: dataDir + "/todos.json"
  readonly property string snippetsPath: dataDir + "/snippets.json"
  readonly property string actionScriptPath: Qt.resolvedUrl("scripts/action.sh").toString().replace(/^file:\/\//, "")

  // Data Models
  property var todosList: []
  property string notesContent: ""
  property var snippetsList: []

  readonly property int pendingCount: {
    var c = 0
    for (var i = 0; i < todosList.length; i++) {
      if (todosList[i] && !todosList[i].done) c++
    }
    return c
  }

  readonly property int totalCount: todosList.length

  readonly property int wordCount: {
    var t = notesContent.trim()
    return t.length > 0 ? t.split(/\s+/).length : 0
  }

  readonly property int charCount: notesContent.length

  // Filtered snippets
  readonly property var filteredSnippets: {
    if (!searchFilter.trim()) return snippetsList
    var q = searchFilter.toLowerCase().trim()
    var out = []
    for (var i = 0; i < snippetsList.length; i++) {
      var s = snippetsList[i]
      if (s && ((s.title && s.title.toLowerCase().indexOf(q) !== -1) ||
                (s.code && s.code.toLowerCase().indexOf(q) !== -1) ||
                (s.tag && s.tag.toLowerCase().indexOf(q) !== -1))) {
        out.push(s)
      }
    }
    return out
  }

  function showToast(msg) {
    toastMessage = msg
    toastTimer.restart()
  }

  Timer {
    id: toastTimer
    interval: 2000
    onTriggered: root.toastMessage = ""
  }

  // Lifecycle
  function open() {
    popupOpen = true
    cursorIndex = 0
    keyboardActive = false
    Qt.callLater(function() {
      if (keyCatcher) keyCatcher.forceActiveFocus()
    })
  }

  function close() {
    popupOpen = false
    keyboardActive = false
  }

  function toggle() {
    if (popupOpen) close()
    else open()
  }

  // Action Dispatcher
  function runAction(action, param, param2) {
    actionProc.command = ["/bin/bash", root.actionScriptPath, action, param || "", param2 || ""]
    actionProc.running = true
  }

  Process {
    id: actionProc
  }

  function copyToClipboard(text, label) {
    if (!text) return
    runAction("copy", text)
    showToast("Copied " + (label || "to clipboard") + "! ✓")
  }

  function openInEditor() {
    runAction("open-notes", root.notesPath)
    close()
  }

  function openDataDir() {
    runAction("open-dir")
  }

  // ==========================================
  // TODOS MANAGEMENT
  // ==========================================
  function addTodo(text) {
    var str = String(text || "").trim()
    if (!str) return
    var next = todosList.slice()
    next.unshift({
      id: Date.now(),
      text: str,
      done: false,
      createdAt: Math.floor(Date.now() / 1000)
    })
    todosList = next
    saveTodos()
    cursorIndex = 0
    showToast("Task added! 󰄲")
  }

  function toggleTodo(index) {
    if (index < 0 || index >= todosList.length) return
    var next = todosList.slice()
    next[index].done = !next[index].done
    todosList = next
    saveTodos()
  }

  function deleteTodo(index) {
    if (index < 0 || index >= todosList.length) return
    var next = []
    for (var i = 0; i < todosList.length; i++) {
      if (i !== index) next.push(todosList[i])
    }
    todosList = next
    saveTodos()
    if (cursorIndex >= next.length) cursorIndex = Math.max(0, next.length - 1)
    showToast("Task deleted")
  }

  function clearCompleted() {
    var next = []
    var removed = 0
    for (var i = 0; i < todosList.length; i++) {
      if (!todosList[i].done) next.push(todosList[i])
      else removed++
    }
    if (removed === 0) return
    todosList = next
    saveTodos()
    cursorIndex = 0
    showToast("Cleared " + removed + " completed tasks")
  }

  function saveTodos() {
    todosFile.setText(JSON.stringify(todosList, null, 2) + "\n")
  }

  function loadTodos(raw) {
    var txt = String(raw || "").trim()
    if (!txt) {
      todosList = [
        { id: 1, text: "Welcome to Omarchy Scratchpad!", done: false, createdAt: Math.floor(Date.now() / 1000) },
        { id: 2, text: "Press 'j/k' to navigate, 'Space' to toggle", done: false, createdAt: Math.floor(Date.now() / 1000) },
        { id: 3, text: "Try Super + Alt + N to toggle anytime", done: true, createdAt: Math.floor(Date.now() / 1000) }
      ]
      saveTodos()
      return
    }
    try {
      var parsed = JSON.parse(txt)
      if (Array.isArray(parsed)) todosList = parsed
    } catch (e) {
      console.warn("Scratchpad: todos.json parse error:", e)
    }
  }

  // ==========================================
  // NOTES MANAGEMENT
  // ==========================================
  function saveNotes(text) {
    notesContent = text
    notesFile.setText(text)
  }

  function appendTimestamp() {
    var now = new Date()
    var stamp = "\n\n## " + now.toLocaleDateString() + " " + now.toLocaleTimeString() + "\n- "
    notesContent += stamp
    saveNotes(notesContent)
    showToast("Timestamp added 󰃰")
  }

  function loadNotes(raw) {
    var txt = String(raw || "")
    if (!txt && !notesFile.exists) {
      var starter = "# Quick Scratchpad\n\n- Instant scratchpad saved directly to `~/.local/share/omarchy/scratchpad/notes.md`.\n- Auto-saves in real time as you type.\n- Press `Ctrl+T` or button to append timestamp."
      notesContent = starter
      saveNotes(starter)
      return
    }
    notesContent = txt
  }

  // ==========================================
  // SNIPPETS MANAGEMENT
  // ==========================================
  function addSnippet(title, code, tag) {
    var t = String(title || "").trim()
    var c = String(code || "").trim()
    if (!t || !c) return
    var next = snippetsList.slice()
    next.unshift({
      id: Date.now(),
      title: t,
      code: c,
      tag: tag || "custom"
    })
    snippetsList = next
    saveSnippets()
    showToast("Snippet saved! 📋")
  }

  function deleteSnippet(index) {
    if (index < 0 || index >= snippetsList.length) return
    var target = filteredSnippets[index]
    var next = []
    for (var i = 0; i < snippetsList.length; i++) {
      if (snippetsList[i].id !== target.id) next.push(snippetsList[i])
    }
    snippetsList = next
    saveSnippets()
    if (cursorIndex >= filteredSnippets.length) cursorIndex = Math.max(0, filteredSnippets.length - 1)
    showToast("Snippet deleted")
  }

  function saveSnippets() {
    snippetsFile.setText(JSON.stringify(snippetsList, null, 2) + "\n")
  }

  function loadSnippets(raw) {
    var txt = String(raw || "").trim()
    if (!txt) {
      snippetsList = [
        { id: 1, title: "Git Undo Last Commit", code: "git reset --soft HEAD~1", tag: "git" },
        { id: 2, title: "Arch Clean Orphans", code: "sudo pacman -Rns $(pacman -Qtdq)", tag: "arch" },
        { id: 3, title: "Kill Port Process", code: "fuser -k 3000/tcp", tag: "dev" },
        { id: 4, title: "SSH Local Port Forward", code: "ssh -L 8080:localhost:8080 user@host", tag: "ssh" },
        { id: 5, title: "Hyprland Reload Config", code: "hyprctl reload", tag: "hypr" }
      ]
      saveSnippets()
      return
    }
    try {
      var parsed = JSON.parse(txt)
      if (Array.isArray(parsed)) snippetsList = parsed
    } catch (e) {
      console.warn("Scratchpad: snippets.json parse error:", e)
    }
  }

  // ==========================================
  // FILE WATCHERS
  // ==========================================
  FileView {
    id: notesFile
    path: root.notesPath
    watchChanges: true
    printErrors: false
    onLoaded: root.loadNotes(text())
    onLoadFailed: root.loadNotes("")
    onFileChanged: reload()
  }

  FileView {
    id: todosFile
    path: root.todosPath
    watchChanges: true
    printErrors: false
    onLoaded: root.loadTodos(text())
    onLoadFailed: root.loadTodos("")
    onFileChanged: reload()
  }

  FileView {
    id: snippetsFile
    path: root.snippetsPath
    watchChanges: true
    printErrors: false
    onLoaded: root.loadSnippets(text())
    onLoadFailed: root.loadSnippets("")
    onFileChanged: reload()
  }

  // ==========================================
  // KEYBOARD NAVIGATION HELPERS
  // ==========================================
  function moveCursor(dy) {
    keyboardActive = true
    var max = activeTab === "todos" ? todosList.length : (activeTab === "snippets" ? filteredSnippets.length : 0)
    if (max <= 0) return
    cursorIndex = Math.max(0, Math.min(max - 1, cursorIndex + dy))
  }

  function switchTab(dir) {
    var tabs = ["todos", "notes", "snippets"]
    var curr = tabs.indexOf(activeTab)
    var next = (curr + dir + tabs.length) % tabs.length
    activeTab = tabs[next]
    cursorIndex = 0
    keyboardActive = true
  }

  function setTab(tabName) {
    activeTab = tabName
    cursorIndex = 0
    keyboardActive = true
  }

  function toggleFocusedItem() {
    if (activeTab === "todos") {
      toggleTodo(cursorIndex)
    } else if (activeTab === "snippets") {
      if (cursorIndex >= 0 && cursorIndex < filteredSnippets.length) {
        copyToClipboard(filteredSnippets[cursorIndex].code, filteredSnippets[cursorIndex].title)
      }
    }
  }

  function deleteFocusedItem() {
    if (activeTab === "todos") {
      deleteTodo(cursorIndex)
    } else if (activeTab === "snippets") {
      deleteSnippet(cursorIndex)
    }
  }

  function focusInput() {
    if (activeTab === "todos") {
      todoInputField.forceActiveFocus()
    } else if (activeTab === "notes") {
      noteTextEdit.forceActiveFocus()
    } else if (activeTab === "snippets") {
      snippetTitleField.forceActiveFocus()
    }
  }

  // IPC target
  IpcHandler {
    target: "azambekdev.scratchpad"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function clearDone(): void { root.clearCompleted() }
    function copyNotes(): void { root.copyToClipboard(root.notesContent, "notes") }
  }

  // ==========================================
  // BAR PILL PRESENTATION
  // ==========================================
  readonly property string pillLabel: {
    if (root.compactView) return "󰏫"
    if (root.pendingCount > 0) return "󰄲 " + root.pendingCount + (root.totalCount > 0 ? "/" + root.totalCount : "")
    if (root.totalCount > 0) return "󰄲 Done"
    return "󰏫 Notes"
  }

  readonly property color pillColor: {
    if (root.pendingCount > 0) return Color.accent
    if (root.totalCount > 0) return "#10b981"
    return root.bar ? root.bar.foreground : Color.foreground
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? "" : root.pillLabel
    tooltipText: "Scratchpad: " + root.pendingCount + " pending tasks · " + root.wordCount + " words — Left: Panel · Right: Add Task · Middle: Copy Notes"
    active: root.popupOpen || root.pendingCount > 0
    activeColor: root.pillColor
    useActiveColor: true

    onPressed: function(b) {
      if (b === Qt.RightButton) {
        root.open()
        root.setTab("todos")
        Qt.callLater(root.focusInput)
      } else if (b === Qt.MiddleButton) {
        root.copyToClipboard(root.notesContent, "notes")
      } else {
        root.toggle()
      }
    }
  }

  // ==========================================
  // POPUP CARD
  // ==========================================
  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(430))
    contentHeight: popup.fittedContentHeight(mainColumn.implicitHeight + Style.space(16))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      blocked: todoInputField.activeFocus || noteTextEdit.activeFocus || snippetTitleField.activeFocus || snippetCodeField.activeFocus

      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.moveCursor(dy)
        else if (dx !== 0) root.switchTab(dx)
      }
      onActivateRequested: root.toggleFocusedItem()
      onCloseRequested: root.close()
      onTabRequested: function(dir) { root.switchTab(dir) }
      onDeleteRequested: root.deleteFocusedItem()

      onTextKey: function(t) {
        if (t === "1") root.setTab("todos")
        else if (t === "2") root.setTab("notes")
        else if (t === "3") root.setTab("snippets")
        else if (t === "a" || t === "A" || t === "i" || t === "I") root.focusInput()
        else if (t === "c" || t === "C") root.clearCompleted()
        else if (t === "y" || t === "Y") {
          if (root.activeTab === "notes") root.copyToClipboard(root.notesContent, "notes")
          else root.toggleFocusedItem()
        }
        else if (t === "e" || t === "E") root.openInEditor()
        else if (t === "q" || t === "Q") root.close()
        else if (t === "x" || t === "X" || t === "d" || t === "D") root.deleteFocusedItem()
        else if (t === "h" || t === "H") root.switchTab(-1)
        else if (t === "l" || t === "L") root.switchTab(1)
      }

      Column {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(10)

        // ==========================================
        // HEADER BAR
        // ==========================================
        Item {
          width: parent.width
          height: Style.space(34)

          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)

            Text {
              text: "󰏫"
              color: Color.accent
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.title
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              spacing: 0

              Row {
                spacing: Style.space(6)

                Text {
                  text: "Scratchpad"
                  color: root.bar ? root.bar.foreground : Color.foreground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.subtitle
                  font.bold: true
                }

                // Toast or storage pill
                BorderSurface {
                  height: Style.space(16)
                  radius: height / 2
                  color: root.toastMessage ? "#064e3b" : Style.normalFillFor(Color.accent, Color.accent)
                  borderSpec: Border.controlSpec("normal", root.toastMessage ? "#10b981" : Color.accent, Color.accent)
                  anchors.verticalCenter: parent.verticalCenter
                  leftPadding: Style.space(5)
                  rightPadding: Style.space(5)

                  Text {
                    anchors.centerIn: parent
                    text: root.toastMessage ? root.toastMessage : (root.pendingCount + " pending")
                    color: root.toastMessage ? "#10b981" : Color.accent
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }
            }
          }

          // Header action buttons
          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            Button {
              width: Style.space(26)
              height: Style.space(26)
              iconText: "󰈔"
              tooltipText: "Open in terminal editor [e]"
              onClicked: root.openInEditor()
            }

            Button {
              width: Style.space(26)
              height: Style.space(26)
              iconText: "󰉋"
              tooltipText: "Open notes folder"
              onClicked: root.openDataDir()
            }

            Button {
              width: Style.space(26)
              height: Style.space(26)
              iconText: "✕"
              tooltipText: "Close [q / Esc]"
              onClicked: root.close()
            }
          }
        }

        // ==========================================
        // TAB SELECTOR
        // ==========================================
        Row {
          width: parent.width
          spacing: Style.space(4)

          Button {
            width: (parent.width - Style.space(8)) / 3
            text: "Todos (" + root.pendingCount + ") [1]"
            iconText: "󰄲"
            selected: root.activeTab === "todos"
            accent: Color.accent
            onClicked: root.setTab("todos")
          }

          Button {
            width: (parent.width - Style.space(8)) / 3
            text: "Notes [2]"
            iconText: "📝"
            selected: root.activeTab === "notes"
            accent: Color.accent
            onClicked: root.setTab("notes")
          }

          Button {
            width: (parent.width - Style.space(8)) / 3
            text: "Snippets [3]"
            iconText: "📋"
            selected: root.activeTab === "snippets"
            accent: Color.accent
            onClicked: root.setTab("snippets")
          }
        }

        // ==========================================
        // TAB 1: TODOS VIEW
        // ==========================================
        Column {
          visible: root.activeTab === "todos"
          width: parent.width
          spacing: Style.space(8)

          // Quick Add Input Box
          Row {
            width: parent.width
            spacing: Style.space(6)

            TextField {
              id: todoInputField
              width: parent.width - Style.space(76)
              placeholderText: "Add new task... (press Enter)"
              onAccepted: {
                root.addTodo(todoInputField.text)
                todoInputField.text = ""
              }
              Keys.onEscapePressed: {
                todoInputField.focus = false
                keyCatcher.forceActiveFocus()
              }
            }

            Button {
              width: Style.space(70)
              text: "+ Add"
              accent: Color.accent
              onClicked: {
                root.addTodo(todoInputField.text)
                todoInputField.text = ""
              }
            }
          }

          // Todos List Header & Clear Completed
          Item {
            visible: root.todosList.length > 0
            width: parent.width
            height: Style.space(20)

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: root.pendingCount + " pending · " + (root.totalCount - root.pendingCount) + " completed"
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }

            Button {
              visible: (root.totalCount - root.pendingCount) > 0
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: "Clear Done [c]"
              fontSize: Style.font.caption * 0.9
              verticalPadding: Style.space(2)
              horizontalPadding: Style.space(6)
              onClicked: root.clearCompleted()
            }
          }

          // Empty state
          BorderSurface {
            visible: root.todosList.length === 0
            width: parent.width
            height: Style.space(90)
            radius: Style.cornerRadius
            color: Style.normalFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)

            Column {
              anchors.centerIn: parent
              spacing: Style.space(4)

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰄲"
                color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.title
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No tasks yet! Type above to add your first todo."
                color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.3)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.bodySmall
              }
            }
          }

          // Scrollable Task Items
          ScrollView {
            width: parent.width
            implicitHeight: Math.min(Style.space(240), taskColumn.implicitHeight)
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: taskColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

            Column {
              id: taskColumn
              width: parent.width
              spacing: Style.space(4)

              Repeater {
                model: root.todosList

                BorderSurface {
                  required property var modelData
                  required property int index
                  readonly property bool isSelected: (root.keyboardActive && root.cursorIndex === index) || taskHover.containsMouse
                  width: parent.width
                  height: Style.space(38)
                  radius: Style.cornerRadius
                  color: isSelected ? Style.hoverFillFor(Color.accent, Color.accent) : Style.normalFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)
                  borderSpec: Border.controlSpec(isSelected ? "hover-cursor" : "normal", root.bar ? root.bar.foreground : Color.foreground, Color.accent)

                  MouseArea {
                    id: taskHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: {
                      root.cursorIndex = index
                      root.keyboardActive = false
                    }
                    onClicked: root.toggleTodo(index)
                  }

                  Row {
                    anchors.fill: parent
                    anchors.margins: Style.space(6)
                    spacing: Style.space(8)

                    // Checkbox button
                    Text {
                      text: modelData.done ? "󰄲" : "󰄱"
                      color: modelData.done ? "#10b981" : (isSelected ? Color.accent : (root.bar ? root.bar.foreground : Color.foreground))
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.body
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    // Task text
                    Text {
                      width: parent.width - Style.space(64)
                      text: modelData.text || ""
                      color: modelData.done ? Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.6) : (root.bar ? root.bar.foreground : Color.foreground)
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.bodySmall
                      font.strikeout: modelData.done
                      elide: Text.ElideRight
                      maximumLineCount: 1
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    // Delete button
                    Button {
                      width: Style.space(22)
                      height: Style.space(22)
                      anchors.verticalCenter: parent.verticalCenter
                      iconText: "✕"
                      tooltipText: "Delete [d]"
                      onClicked: root.deleteTodo(index)
                    }
                  }
                }
              }
            }
          }
        }

        // ==========================================
        // TAB 2: SCRATCHPAD NOTES VIEW
        // ==========================================
        Column {
          visible: root.activeTab === "notes"
          width: parent.width
          spacing: Style.space(6)

          BorderSurface {
            width: parent.width
            height: Style.space(220)
            radius: Style.cornerRadius
            color: Style.normalFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)
            borderSpec: Border.controlSpec(noteTextEdit.activeFocus ? "focus" : "normal", root.bar ? root.bar.foreground : Color.foreground, Color.accent)

            ScrollView {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              clip: true

              TextArea {
                id: noteTextEdit
                text: root.notesContent
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.bodySmall
                color: root.bar ? root.bar.foreground : Color.foreground
                selectionColor: Style.selectionFillFor(Color.foreground, Color.accent)
                selectedTextColor: Color.foreground
                placeholderText: "Type thoughts, code snippets, or notes here...\n(Auto-saves instantly to ~/.local/share/omarchy/scratchpad/notes.md)"
                placeholderTextColor: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.6)
                wrapMode: TextEdit.Wrap
                background: null

                onTextChanged: {
                  if (text !== root.notesContent) {
                    root.saveNotes(text)
                  }
                }

                Keys.onEscapePressed: {
                  noteTextEdit.focus = false
                  keyCatcher.forceActiveFocus()
                }
              }
            }
          }

          // Notes stats & actions
          Item {
            width: parent.width
            height: Style.space(26)

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: root.wordCount + " words · " + root.charCount + " chars · Auto-saved ✓"
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }

            Row {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(4)

              Button {
                text: "+ Timestamp"
                fontSize: Style.font.caption
                verticalPadding: Style.space(2)
                horizontalPadding: Style.space(6)
                onClicked: root.appendTimestamp()
              }

              Button {
                text: "Copy All [y]"
                iconText: "󰅍"
                fontSize: Style.font.caption
                verticalPadding: Style.space(2)
                horizontalPadding: Style.space(6)
                onClicked: root.copyToClipboard(root.notesContent, "notes")
              }
            }
          }
        }

        // ==========================================
        // TAB 3: CODE SNIPPETS VIEW
        // ==========================================
        Column {
          visible: root.activeTab === "snippets"
          width: parent.width
          spacing: Style.space(6)

          // Add / Search row
          Row {
            width: parent.width
            spacing: Style.space(6)

            TextField {
              id: snippetTitleField
              width: (parent.width - Style.space(6)) * 0.4
              placeholderText: "Title / Tag..."
              Keys.onEscapePressed: {
                snippetTitleField.focus = false
                keyCatcher.forceActiveFocus()
              }
            }

            TextField {
              id: snippetCodeField
              width: (parent.width - Style.space(6)) * 0.4
              placeholderText: "Command / Code..."
              onAccepted: {
                root.addSnippet(snippetTitleField.text, snippetCodeField.text, "custom")
                snippetTitleField.text = ""
                snippetCodeField.text = ""
              }
              Keys.onEscapePressed: {
                snippetCodeField.focus = false
                keyCatcher.forceActiveFocus()
              }
            }

            Button {
              width: (parent.width - Style.space(6)) * 0.2
              text: "+ Add"
              accent: Color.accent
              onClicked: {
                root.addSnippet(snippetTitleField.text, snippetCodeField.text, "custom")
                snippetTitleField.text = ""
                snippetCodeField.text = ""
              }
            }
          }

          // Snippets list
          ScrollView {
            width: parent.width
            implicitHeight: Math.min(Style.space(220), snippetColumn.implicitHeight)
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: snippetColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

            Column {
              id: snippetColumn
              width: parent.width
              spacing: Style.space(4)

              Repeater {
                model: root.filteredSnippets

                BorderSurface {
                  required property var modelData
                  required property int index
                  readonly property bool isSelected: (root.keyboardActive && root.cursorIndex === index) || snipHover.containsMouse
                  width: parent.width
                  height: Style.space(48)
                  radius: Style.cornerRadius
                  color: isSelected ? Style.hoverFillFor(Color.accent, Color.accent) : Style.normalFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)
                  borderSpec: Border.controlSpec(isSelected ? "hover-cursor" : "normal", root.bar ? root.bar.foreground : Color.foreground, Color.accent)

                  MouseArea {
                    id: snipHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: {
                      root.cursorIndex = index
                      root.keyboardActive = false
                    }
                    onClicked: root.copyToClipboard(modelData.code, modelData.title)
                  }

                  Row {
                    anchors.fill: parent
                    anchors.margins: Style.space(6)
                    spacing: Style.space(6)

                    Column {
                      width: parent.width - Style.space(60)
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(1)

                      Row {
                        spacing: Style.space(4)

                        Text {
                          text: modelData.title || ""
                          color: Color.accent
                          font.family: root.bar ? root.bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }

                        BorderSurface {
                          height: Style.space(14)
                          radius: height / 2
                          color: Style.normalFillFor(Color.accent, Color.accent)
                          borderSpec: Border.controlSpec("normal", Color.accent, Color.accent)
                          leftPadding: Style.space(3)
                          rightPadding: Style.space(3)

                          Text {
                            anchors.centerIn: parent
                            text: modelData.tag || "code"
                            color: Qt.darker(Color.accent, 1.2)
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: Style.font.caption * 0.8
                          }
                        }
                      }

                      Text {
                        width: parent.width
                        text: modelData.code || ""
                        color: root.bar ? root.bar.foreground : Color.foreground
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption * 0.9
                        elide: Text.ElideRight
                        maximumLineCount: 1
                      }
                    }

                    // Copy button
                    Button {
                      width: Style.space(24)
                      height: Style.space(24)
                      anchors.verticalCenter: parent.verticalCenter
                      iconText: "󰅍"
                      tooltipText: "Copy [y / Enter]"
                      onClicked: root.copyToClipboard(modelData.code, modelData.title)
                    }

                    // Delete button
                    Button {
                      width: Style.space(22)
                      height: Style.space(22)
                      anchors.verticalCenter: parent.verticalCenter
                      iconText: "✕"
                      tooltipText: "Delete [d]"
                      onClicked: root.deleteSnippet(index)
                    }
                  }
                }
              }
            }
          }
        }

        // ==========================================
        // KEYBOARD HINTS RIBBON
        // ==========================================
        BorderSurface {
          width: parent.width
          height: Style.space(22)
          radius: Style.cornerRadius
          color: Style.normalFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)

          Row {
            anchors.centerIn: parent
            spacing: Style.space(8)

            Text {
              text: "󰌌"
              color: Color.accent
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption * 0.9
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: "j/k: nav · Space/↵: toggle/copy · 1-3: tabs · a/i: add · c: clear · q: close"
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption * 0.85
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }
      }
    }
  }
}
