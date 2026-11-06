# Development scene index

These are reusable prototype assets. `Main.tscn` is the configured project
entry point and launches the title menu; Play opens the fan puzzle at
`dev/Level 1 - Alt/level_1.tscn`. Standalone manual tests live under `tests/`.

| Scene | Purpose |
| --- | --- |
| `title/curtain.tscn` | Curtain with seven horizontal rows of two bones, edge controls, mesh weights, rest poses, RESET, and an editable animation. See `title/README.md`. |
| `Level 1 - Alt/level_1.tscn` | Fan-puzzle level reached from the title menu's Play button. |
| `level_2_ocean/level_2_ocean.tscn` | Ocean room inside the music box, with a zoom entrance. Run with F6; see [controls and checks](level_2_ocean/README.md). |
| `level_3_ocean/level_3_ocean.tscn` | Night Ocean: crank-driven sweep light, three floating logs and two dead-end rocks. Run with F6; see [controls and checks](level_3_ocean/README.md). |
| `winder_test_1_time_scroll/winder_test_1_time_scroll.tscn` | Interactive music-box playback, crank, and level-flow prototype. Run directly with F6. |
| [`../tests/music_box_surreal/music_box_surreal_test.tscn`](../tests/music_box_surreal/music_box_surreal_test.tscn) | Playback test with the isolated blue/forward-gold/return-red shader. Run directly with F6. |
| [`../tests/panorama_window/panorama_window_test.tscn`](../tests/panorama_window/panorama_window_test.tscn) | Standalone panorama crop and music-box window alignment test. |
| `movable_object_test/movable_object_test.tscn` | Editable line paths and point rotations driven by 0-270 degree winding progress, collision blocking, two independent controllers, and return/keep-position behavior. Run directly with F6. |
| `winder_test_1_time_scroll/music_box_visuals_with_winder.tscn` | Reusable music-box artwork scene used by playback and the title menu. |
| `winder_test_1_time_scroll/music_box_visuals_without_winder.tscn` | Artwork-only comparison variant without an interactive winder. |

The playback folder keeps its prototype scripts and media beside the playable
scene. Dedicated manual test scenes and their test-only resources live under
`tests/`. The descriptive `music_box_visuals_*` names distinguish artwork
scenes from the runnable playback prototype.

Reusable movable objects live in `Level/objects/`. See
[`docs/movable-objects.md`](../docs/movable-objects.md) for editing, collision
setup, controller wiring, and automated checks.

`addons/winding_debug/` provides the **Winding Debug** bottom dock in Godot's
editor. Preview all or individual winding-key groups at 0..270 degrees without
running the game. `dev/global_debug/` contains its editor validation tools.
Selecting a movable also exposes **Edit Path Rotation** in the 2D toolbar;
drag its orange handles or edit **Path Rotations** in the Inspector.
See [`docs/global-debug.md`](../docs/global-debug.md).
