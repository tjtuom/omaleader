import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Omaleader: which-key style leader menu. A Hyprland bind to the global
// shortcut "omaleader:toggle" opens it; then single keys walk the keymap in
// ~/.config/omarchy/omaleader.jsonc (keymap.example.jsonc beside this file
// when that doesn't exist). While open, Hyprland sits in the "omaleader"
// submap, so a still-held Super doesn't turn the next key into a Super bind.
Item {
  id: root

  property var shell: null
  property var manifest: null
  readonly property string pluginId: (root.manifest && root.manifest.id) || "tjtuom.omaleader"

  property bool opened: false
  property var keymap: ({})
  property string loadError: ""
  // Keys pressed so far, e.g. ["w", "r"].
  property var path: []
  readonly property var node: root.nodeAt(root.path)
  readonly property var entries: root.sortedEntries(root.node)

  readonly property color background: Commons.Color.menu.background
  readonly property color foreground: Commons.Color.menu.text
  readonly property color accent: Commons.Color.menu.selectedText
  readonly property color chip: Commons.Color.menu.selectedBackground
  readonly property var borderSpec: Border.surfaceSpec("menu", "border", Commons.Color.menu.border, Math.max(1, Style.space(2)))
  readonly property string fontFamily: Style.font.menuFamily
  readonly property int columnWidth: Style.space(250)
  readonly property int rowHeight: Math.max(Style.space(28), Style.font.body + Style.spacing.controlPaddingY * 2)

  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
  readonly property string userKeymapPath: root.configHome + "/omarchy/omaleader.jsonc"
  readonly property string exampleKeymapPath: decodeURIComponent(String(Qt.resolvedUrl("keymap.example.jsonc")).replace(/^file:\/\//, ""))
  // Set when the user keymap is missing and the bundled example is in use.
  property bool usingExample: false

  // ---- keymap -------------------------------------------------------------

  function stripJsonc(raw) {
    return String(raw || "")
      .replace(/^\s*\/\/[^\n]*(\n|$)/gm, "")
      .replace(/,(\s*[}\]])/g, "$1")
  }

  function loadKeymap(raw) {
    try {
      var parsed = JSON.parse(root.stripJsonc(raw))
      if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error("top level must be an object")
      root.keymap = parsed
      root.loadError = ""
    } catch (e) {
      root.loadError = (root.usingExample ? "keymap.example.jsonc" : "omaleader.jsonc") + ": " + e.message
      console.warn("[omaleader] " + root.loadError)
    }
    // Drop a path the new keymap no longer has.
    if (!root.nodeAt(root.path)) root.path = []
  }

  function isGroup(entry) {
    return !!entry && typeof entry.keys === "object" && entry.keys !== null
  }

  function nodeAt(keys) {
    var node = root.keymap
    for (var i = 0; i < keys.length; i++) {
      var entry = node ? node[keys[i]] : null
      if (!root.isGroup(entry)) return null
      node = entry.keys
    }
    return node
  }

  // which-key order: by letter, lowercase before uppercase, named keys last.
  function sortedEntries(node) {
    if (!node) return []
    var out = []
    for (var key in node) {
      var entry = node[key]
      if (!entry || typeof entry !== "object") continue
      out.push({ key: key, label: String(entry.label || key), group: root.isGroup(entry), entry: entry })
    }
    function rank(k) { return k.length > 1 ? 2 : 0 }
    out.sort(function(a, b) {
      var ra = rank(a.key), rb = rank(b.key)
      if (ra !== rb) return ra - rb
      var la = a.key.toLowerCase(), lb = b.key.toLowerCase()
      if (la !== lb) return la < lb ? -1 : 1
      return a.key === la ? -1 : 1
    })
    return out
  }

  function displayKey(key) {
    var names = { space: "␣", tab: "⇥", enter: "⏎", left: "←", right: "→", up: "↑", down: "↓" }
    return names[key] || key
  }

  // ---- keys ---------------------------------------------------------------

  function keyName(event) {
    var k = event.key
    var modifierKeys = [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_AltGr, Qt.Key_Meta,
                        Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_Hyper_L, Qt.Key_Hyper_R, Qt.Key_CapsLock]
    if (modifierKeys.indexOf(k) >= 0) return ""
    if (k === Qt.Key_Space) return "space"
    if (k === Qt.Key_Tab) return "tab"
    if (k === Qt.Key_Return || k === Qt.Key_Enter) return "enter"
    if (k === Qt.Key_Left) return "left"
    if (k === Qt.Key_Right) return "right"
    if (k === Qt.Key_Up) return "up"
    if (k === Qt.Key_Down) return "down"
    var t = event.text
    if (t && t.length === 1 && t.charCodeAt(0) > 32 && t.charCodeAt(0) !== 127) return t
    // Ctrl or Super held: no usable text, fall back to the key code.
    if (k >= Qt.Key_A && k <= Qt.Key_Z) {
      var c = String.fromCharCode(k)
      return (event.modifiers & Qt.ShiftModifier) ? c : c.toLowerCase()
    }
    if (k >= Qt.Key_0 && k <= Qt.Key_9) return String.fromCharCode(k)
    return ""
  }

  function handleKey(event) {
    if (event.key === Qt.Key_Escape) { root.dismiss(); return }
    if (event.key === Qt.Key_Backspace) {
      if (root.path.length > 0) root.path = root.path.slice(0, -1)
      else root.dismiss()
      return
    }
    var key = root.keyName(event)
    if (!key || !root.node) return
    var entry = root.node[key]
    if (!entry || typeof entry !== "object") return
    if (root.isGroup(entry)) { root.path = root.path.concat([key]); return }
    root.run(entry)
  }

  function run(entry) {
    if (!entry.stay) root.dismiss()
    if (entry.dispatch) Hyprland.dispatch(String(entry.dispatch))
    if (entry.exec) Util.execDetached(String(entry.exec))
  }

  // ---- open / close ---------------------------------------------------------

  function open(payloadJson) {
    root.path = []
    root.opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    if (!root.opened) return
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
  }

  function toggle() {
    if (root.opened) { root.dismiss(); return }
    if (root.shell && typeof root.shell.summon === "function" && root.shell.summon(root.pluginId, "{}")) return
    root.open("{}")
  }

  onOpenedChanged: Hyprland.dispatch('hl.dsp.submap("' + (root.opened ? "omaleader" : "reset") + '")')
  // A reload or disable while open would otherwise strand Hyprland in the submap.
  Component.onDestruction: if (root.opened) Hyprland.dispatch('hl.dsp.submap("reset")')

  GlobalShortcut {
    appid: "omaleader"
    name: "toggle"
    description: "Toggle the leader menu"
    onPressed: root.toggle()
  }

  IpcHandler {
    target: "omaleader"
    function toggle(): string { root.toggle(); return root.opened ? "shown" : "hidden" }
    function hide(): string { root.dismiss(); return "hidden" }
    function isOpen(): string { return root.opened ? "true" : "false" }
  }

  // The user's keymap, watched so saved edits apply at once. When it doesn't
  // exist, fall back to the bundled example.
  FileView {
    path: root.userKeymapPath
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      root.usingExample = false
      root.loadKeymap(text())
    }
    onLoadFailed: function(error) {
      root.usingExample = true
      exampleKeymap.reload()
    }
  }

  FileView {
    id: exampleKeymap
    path: root.exampleKeymapPath
    preload: false
    onLoaded: if (root.usingExample) root.loadKeymap(text())
    onLoadFailed: function(error) { if (root.usingExample) root.loadError = "Can't read " + root.exampleKeymapPath }
  }

  // ---- UI -----------------------------------------------------------------

  component Label: Text {
    textFormat: Text.PlainText
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    color: root.foreground
    verticalAlignment: Text.AlignVCenter
  }

  OverlayWindow {
    id: panel
    shown: root.opened
    WlrLayershell.namespace: "omaleader"

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      readonly property int innerWidth: width - contentLeftInset - contentRightInset
      readonly property int columns: Math.max(1, Math.floor(innerWidth / root.columnWidth))

      width: Math.min(Style.space(1040), panel.width - Style.gapsOut * 4)
      height: content.implicitHeight + contentTopInset + contentBottomInset
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.gapsOut * 4
      radius: Style.cornerRadius
      color: root.background
      borderSpec: root.borderSpec
      padding: Style.spacing.panelPadding

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          root.handleKey(event)
          event.accepted = true
        }
      }

      Column {
        id: content
        x: card.contentLeftInset
        y: card.contentTopInset
        width: card.innerWidth
        spacing: Style.spacing.md

        // Breadcrumb: Leader › Window › Resize
        Item {
          width: parent.width
          height: root.rowHeight

          Label {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: {
              var crumbs = ["Leader"]
              var node = root.keymap
              for (var i = 0; i < root.path.length; i++) {
                var entry = node ? node[root.path[i]] : null
                crumbs.push(entry && entry.label ? entry.label : root.path[i])
                node = entry ? entry.keys : null
              }
              return crumbs.join("  ›  ")
            }
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Label {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.path.length > 0 ? "⌫ back   esc close" : "esc close"
            opacity: 0.55
          }
        }

        Label {
          visible: root.loadError !== ""
          width: parent.width
          text: root.loadError
          color: Commons.Color.urgent
          wrapMode: Text.Wrap
        }

        Grid {
          id: grid
          width: parent.width
          columns: card.columns
          flow: Grid.TopToBottom
          rows: Math.max(1, Math.ceil(root.entries.length / card.columns))
          columnSpacing: Style.spacing.md
          rowSpacing: Style.space(2)

          Repeater {
            model: root.entries

            Row {
              required property var modelData
              width: (grid.width - grid.columnSpacing * (grid.columns - 1)) / grid.columns
              height: root.rowHeight
              spacing: Style.spacing.md

              Rectangle {
                width: Math.max(root.rowHeight, keyText.implicitWidth + Style.spacing.md * 2)
                height: root.rowHeight - Style.space(4)
                anchors.verticalCenter: parent.verticalCenter
                radius: Style.cornerRadius
                color: root.chip

                Label {
                  id: keyText
                  anchors.centerIn: parent
                  text: root.displayKey(modelData.key)
                  color: root.accent
                  font.bold: true
                }
              }

              Label {
                height: parent.height
                width: parent.width - x
                text: (modelData.group ? "+" : "") + modelData.label
                color: modelData.group ? root.accent : root.foreground
                elide: Text.ElideRight
              }
            }
          }
        }

        Label {
          visible: root.entries.length === 0 && root.loadError === ""
          text: "No keys here yet: add some to ~/.config/omarchy/omaleader.jsonc"
          opacity: 0.6
        }
      }
    }
  }
}
