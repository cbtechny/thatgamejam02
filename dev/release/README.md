# Windows release tools

Run from the repository root in PowerShell with Godot 4.7.2 and matching Windows
export templates installed. The build script uses the editor path already in
`.vscode/settings.json`; `-GodotPath` can override it.

```powershell
& .\dev\release\build_windows.ps1
# If templates were extracted to a custom folder:
& .\dev\release\build_windows.ps1 -TemplatesDirectory .godot\release-tools
```

The script isolates editor/user caches under `.godot/release-runtime`, runs the
level/campaign/release regressions, exports the selected campaign resources,
includes player instructions and engine notices, and creates
`builds/ClocksInOrange-Windows-candidate.zip`. Logs live under
`.godot/release-logs`. `-SkipTests` is for packaging an already tested revision;
the resulting BUILD.json explicitly records that tests were skipped.

BUILD.json records the base commit, whether local changes were present, the
hash of `builds/source-files.sha256`, and the original theme-file hash. It never
claims an uncommitted candidate is a shared release commit.

`tests/campaign/run_playthrough.gd` solves the puzzles using generated mouse/key
events, real physics and real-time hops. It takes a rock dead end and retries in
both ocean stages, reaches the ending, replays and returns to title. A rendered
run can save screenshots to an absolute folder supplied after `--`:

```powershell
godot --path . --script res://tests/campaign/run_playthrough.gd -- C:/absolute/capture/folder
```

For package dependency checks, run the same test with the editor executable's
`--main-pack builds/windows/ClocksInOrange.pck --script <absolute-script-path>`.
The release template does not run the external script harness; separately launch
the exported EXE from an extracted ZIP. Scripted tests do not replace a human
playthrough, audio listening, or upload/download verification.
