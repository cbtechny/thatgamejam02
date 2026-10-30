# Development scene index

These scenes are prototypes and comparison tests. `Main.tscn` remains the
project's default launch path.

| Scene | Purpose |
| --- | --- |
| `winder_test_1_time_scroll/winder_test_1_time_scroll.tscn` | Interactive music-box playback, crank, and level-flow test; this is what `Main.tscn` currently runs. |
| `shader test/music_box_surreal_test.tscn` | Playback test with the isolated blue/forward-gold/return-red shader. Run directly with F6. |
| `panorama_window_test/panorama_window_test.tscn` | Standalone panorama crop and music-box window alignment test. |
| `movable_object_test/movable_object_test.tscn` | Editable line paths and point rotations driven by 0-270 degree winding progress, collision blocking, two independent controllers, and return/keep-position behavior. Run directly with F6. |
| `winder_test_1_time_scroll/music_box_visuals_with_winder.tscn` | Reusable music-box artwork scene used by playback and the title menu. |
| `winder_test_1_time_scroll/music_box_visuals_without_winder.tscn` | Artwork-only comparison variant without an interactive winder. |

The playback folder keeps its scripts and test media beside the playable test.
The shader folder keeps its shader, test-only timeline, and README together.
The descriptive `music_box_visuals_*` names distinguish artwork scenes from
the runnable playback test.

Reusable movable objects live in `Level/objects/`. See
[`docs/movable-objects.md`](../docs/movable-objects.md) for editing, collision
setup, controller wiring, and automated checks.

`addons/winding_debug/` provides the **Winding Debug** bottom dock in Godot's
editor. Preview all or individual winding-key groups at 0..270 degrees without
running the game. `dev/global_debug/` contains its editor validation tools.
Selecting a movable also exposes **Edit Path Rotation** in the 2D toolbar;
drag its orange handles or edit **Path Rotations** in the Inspector.
See [`docs/global-debug.md`](../docs/global-debug.md).
