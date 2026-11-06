# Manual scene tests

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
