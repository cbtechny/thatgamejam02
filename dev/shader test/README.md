# Music Box Surreal Shader Test

This isolated comparison scene instances the existing music box prototype and
adds a full-screen marbled `ColorRect` behind its artwork. The shader is an
original implementation for this project; it uses two fixed, inexpensive
coordinate warp passes and no texture samples or external dependencies.

Open `music_box_surreal_test.tscn` and run it with **F6**. Compare it with
`dev/winder_test_1_time_scroll/winder_test_1_time_scroll.tscn`, also run with
**F6**. The project default (`Main.tscn`) is unchanged.

The shader timeline extends the main playback timeline. Both use circular
dragging around the winding key center, the 270-degree limit, proportional object travel, and the 2-second
input delay after the key reaches zero. See
[Winding Keys and Movable Objects](../../docs/movable-objects.md).

The shader has three phase palettes: blue at rest and while winding; blue mixed
with yellow (`forward_yellow`) and orange (`forward_orange`) during forward
transit; and red (`return_ink_red`, `return_violet_red`, and `return_paper_red`)
during return. `motion_speed` controls slow idle motion;
`forward_speed_scale` controls the speed multiplier for both forward playback
and return. `warp_strength`, `motion_intensity`, `focal_offset`, and `quality`
control marbling strength, playback deformation, centering, and one or two warp
passes. The test-only timeline eases the palette and warp between these three
states. Forward and return share the fast, strongly warped motion; winding
returns to slow blue idle.

The inset `TextureRect` uses the existing day/night panorama. Its original
wide-canvas mapping is preserved inside a clipped viewport sized to the visible
music-box opening. It stays still while resting or winding, pans forward with
level progress, and pans backward as the level returns.
