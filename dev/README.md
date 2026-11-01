# Development scene index

These are reusable prototype assets. `Main.tscn` is the configured project
entry point and currently instances the playback prototype. Standalone manual
test scenes are organized under `tests/`.

| Scene | Purpose |
| --- | --- |
| `winder_test_1_time_scroll/winder_test_1_time_scroll.tscn` | Interactive music-box playback, crank, and level-flow prototype; also used by `Main.tscn`. |
| `winder_test_1_time_scroll/music_box_visuals_with_winder.tscn` | Reusable music-box artwork scene used by playback and the title menu. |
| `winder_test_1_time_scroll/music_box_visuals_without_winder.tscn` | Artwork-only comparison variant without an interactive winder. |

The playback folder keeps its prototype scripts and media beside the playable
scene. Dedicated manual test scenes and their test-only resources live under
`tests/`.
