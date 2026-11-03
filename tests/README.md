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
