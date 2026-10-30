# Repository Guidelines

## Project Structure & Module Organization

This is a Godot 4.7.2-stable project using standard GDScript and the GL Compatibility renderer. `project.godot` defines the project; `Main.tscn` launches the music-box playback prototype.

- `Level/`: game scenes, including the title menu and music box.
- `Art/Textures/` and `Art/Materials/`: shared artwork and Godot materials.
- `dev/`: self-contained experiments with scripts, scenes, test media, and local READMEs. See `dev/README.md` for the scene index.
- `dev/winder_test_1_time_scroll/`: crank input and playback logic.
- `dev/shader test/` and `dev/panorama_window_test/`: visual comparison scenes.

Keep new experiments in their own `dev/` subdirectory; reuse shared artwork rather than copying it.

## Build, Test, and Development Commands

Run commands from this repository directory. Examples assume `godot` resolves to Godot 4.7.2; in the provided Windows workspace, substitute `& "..\Godot_v4.7.2-stable_win64.exe"`.

```powershell
godot --editor --path .                         # Open the editor
godot --path .                                  # Run Main.tscn
godot --headless --path . --editor --quit        # Import and check editor startup
godot --path . "res://dev/shader test/music_box_surreal_test.tscn"
```

In the editor, use **F5** for the project and **F6** for the current scene. No export presets are checked in; configure a desktop export preset before producing a build.

## Coding Style & Naming Conventions

Match existing GDScript: tabs for indentation, explicit types where practical, `snake_case` functions and variables, `_` prefixes for internal members, and `UPPER_SNAKE_CASE` constants. Use descriptive script names such as `winder_drag.gd`. Follow nearby resource naming (`M_Stage.tres`, `T_Key.png`) and preserve referenced node paths when editing scenes. No formatter or linter is configured.

## Testing Guidelines

Tests currently consist of runnable prototype scenes; there is no automated framework or coverage threshold. After changes, run the affected scene and `Main.tscn`, then inspect Godot's debugger for errors. For playback changes, verify clockwise/counterclockwise winding, release, coin depletion, reverse return, and winding during return. Check visual changes at 1920×1080 and attach screenshots or a short recording.

## Commit & Pull Request Guidelines

History uses plain descriptive subjects such as `Add winding music box audio`; no enforced prefix convention is evident. Keep commits focused. PRs should describe the change, affected scenes, validation performed, and any related issue; include visual evidence for artwork or shader changes.

## Assets & Generated Files

Exclude `.godot/` caches and exported builds. Preserve resource `.uid` files and intentional `.import` settings; review incidental import changes before committing. Keep editable art sources, document asset rights, and follow the README's AI disclosure and theme-recording restrictions.
