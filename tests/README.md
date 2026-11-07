# Manual scene tests

For current release checks and Windows packaging, see
[release tools](../dev/release/README.md). The release behavior regression is
`godot --headless --path . --script res://tests/campaign/run_release_tests.gd`.
The real-input scripted solve is `tests/campaign/run_playthrough.gd`; it is not
an uncoached human acceptance test.

These Godot scenes are manual visual and interaction tests, not automated test
scripts. Open a scene and run it with **F6**. The project default remains
`Main.tscn`, which launches the title menu; Play opens the fan level.

| Scene | Purpose |
| --- | --- |
| `panorama_window/panorama_window_test.tscn` | Check panorama cropping and music-box window alignment. |
| `music_box_surreal/music_box_surreal_test.tscn` | Compare the playback prototype with an animated surreal shader background. |

The surreal test's shader and timeline script are kept beside its scene. The
playback prototype and shared artwork remain under `dev/`.

## Ocean automated regression

Run `godot --headless --path . --script res://tests/level_2_ocean/run_ocean_tests.gd`.
Use the same command without `--headless` and append `-- --capture` to save
rendered input checks under `.godot/ocean_qa/`. See
[the Ocean README](../dev/level_2_ocean/README.md) for coverage and manual controls.

## Level 1 presentation regression

Run `godot --headless --path . --script res://tests/level_1_polish/run_level_1_polish.gd`.
Omit `--headless` and append `-- --capture` for rendered gameplay and assembly
captures under `.godot/level1_polish_qa/`. Checks use real crank/release physics,
phase-specific guidance, assembly alignment, pause/resume, miss/retry, and exit cleanup.

## Connected campaign regression

`godot --headless --path . --script res://tests/campaign/run_campaign_tests.gd`

Checks Level 1 continuation, Level 2/3 pause freezing tide, completion transitions,
ending, and returning to Main. It invokes completion states directly; it does not
replace solving all puzzles or visual/audio acceptance.

Level 1 mouse regression:
`godot --headless --path . --script res://tests/campaign/run_level1_input_tests.gd`
Checks left-fan displacement across physics frames during forward/reverse winding,
and an actual mouse click on Continue while the victory screen pauses gameplay.

Ocean background presentation:
`godot --headless --path . --script res://tests/campaign/run_ocean_ornaments.gd`
Checks both modes, shared assets, motion, pause and reset. Run without headless
for 1920x1080 captures in `.godot/level2-ornaments-preview.png` and
`.godot/level3-ornaments-preview.png`.

Level 1 unified music-box entrance:
`godot --headless --path . --script res://tests/campaign/run_level1_presentation.gd`
Checks entrance input lock, transformed mouse picking and winding, pause/resume,
retry, viewport bounds at three sizes and an actual victory Continue click.
Run without headless for wide/zoom/ready captures under `.godot/`.
The playable campaign entry is `res://Level/level_1_music_box.tscn`; the original
`dev/Level 1 - Alt/level_1.tscn` remains a standalone mechanics test scene.

Full-screen composition regression:
`godot --path . --script res://tests/campaign/run_fullscreen_scale.gd`
Compares all three stages' wide/midpoint/final camera transforms and playable bounds
at three viewport sizes, plus real fullscreen framing. Headless skips the real fullscreen switch.

Full-screen modal overlays:
`godot --path . --script res://tests/campaign/run_fullscreen_menus.gd`
Checks pause and win overlays render in the main viewport, cover three
window sizes, resume correctly and accept a real Continue mouse click. Saves
`.godot/fullscreen-PauseMenu.png`, `fullscreen-WinScreen.png`.

Level 1 quiet failure and curtain restart:
`godot --headless --path . --script res://tests/campaign/run_level1_restart.gd`
Checks unpaused misses, continued visible fragment flight, the R prompt, repeated
input, standalone/campaign restarts, preserved framing, resize, and session audio.
Run without headless and append `-- --capture` for miss/closing/closed/reopened
captures at 1920x1080 and 1280x720 under `.godot/level1-restart-qa/`.
For an isolated exported-PCK run, append `-- --campaign-only` to omit the
standalone development scene, which is intentionally excluded from the export.

## Ocean key fragments and failure restart cues

`godot --headless --path . --script res://tests/campaign/run_ocean_fragments.gd`
checks collection on successful landings, missed landings, dim/filled HUD states,
pause and entrance locks, Reset, Retry and completion in both ocean stages.
Omit `--headless` and append `-- --capture` for both window sizes in
`.godot/fragments-*.png`.

`godot --headless --path . --script res://tests/campaign/run_restart_cues.gd`
checks failure-only restart glow, stable input bounds, very quiet beep settings,
paused Retry cues and restart cleanup across all three stages. Omit `--headless`
for captures at both window sizes in `.godot/restart-*.png`.
