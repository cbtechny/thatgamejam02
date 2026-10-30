# Editor Winding Debug Validation

The editor plugin lives in `res://addons/winding_debug/`. Open the
**Winding Debug** bottom dock to preview angles and bound movable positions
without running the game. See [Winding Debug in the Editor](../../docs/global-debug.md).

Run validation from the project directory:

```powershell
.\dev\global_debug\validate_editor_debug.ps1
.\dev\global_debug\validate_editor_debug.ps1 -Capture
```

`validate_editor_debug.ps1` imports a disposable copy under
`.godot/editor_winding_validation/project/`, then enables the real plugin and
`editor_validation.gd` in that editor. It does not modify source scenes.

The runner checks controls, preview poses, live path edits, point rotation
handles and undo/redo, scene switching, plugin lifecycle, pre-play restoration,
and saving authored angles without preview transforms.
`-Capture` also checks real mouse dragging with Shift snapping and captures the
debug dock and rotation handles at 1920 x 1080. Logs and the optional
`editor-winding-debug.png` and `editor-path-rotation.png` are kept under the
validation directory.
`editor_validation.cfg` is enabled only in the disposable copy.
