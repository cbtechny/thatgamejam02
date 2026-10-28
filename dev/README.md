# Development scene index

These scenes are prototypes and comparison tests. `Main.tscn` remains the
project's default launch path.

| Scene | Purpose |
| --- | --- |
| `winder_test_1_time_scroll/winder_test_1_time_scroll.tscn` | Interactive music-box playback, crank, and level-flow test; this is what `Main.tscn` currently runs. |
| `shader test/music_box_surreal_test.tscn` | Playback test with the isolated blue/forward-gold/return-red shader. Run directly with F6. |
| `panorama_window_test/panorama_window_test.tscn` | Standalone panorama crop and music-box window alignment test. |
| `winder_test_1_time_scroll/music_box_visuals_with_winder.tscn` | Reusable music-box artwork scene used by playback and the title menu. |
| `winder_test_1_time_scroll/music_box_visuals_without_winder.tscn` | Artwork-only comparison variant without an interactive winder. |

The playback folder keeps its scripts and test media beside the playable test.
The shader folder keeps its shader, test-only timeline, and README together.
The descriptive `music_box_visuals_*` names distinguish artwork scenes from
the runnable playback test.
