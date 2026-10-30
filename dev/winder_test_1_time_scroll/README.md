# Music Box Playback Test

Run the project with **F5**, or open `winder_test_1_time_scroll.tscn` and run it with **F6**.

- Hold the left mouse button on the winder and drag around its center. Clockwise movement winds it; counterclockwise movement reduces the angle. The range is 0 to 270 degrees.
- Release to start the theme and unwind the key smoothly to its exact starting angle. A full wind takes 4 seconds by default; a half wind takes 2 seconds.
- Three key fragments follow separate editable line paths. A full 270-degree wind advances each clear path by 100%; 135 degrees advances it by 50%. Objects have no separate Speed setting.
- The energy bar shows the remaining winding amount. Audio length does not drive gameplay timing.
- Input is locked during unwind and for 2 seconds after the key reaches zero. A zero-charge click does not start a cooldown.
- At zero, the fragments and background hold for 1.5 seconds, then return in 0.5 seconds. Reverse audio accompanies the return. Obstacles can delay an object's return.
- A blocked object loses that part of its travel. Opening the barrier lets it use the winding progress that remains, without catching up.

The scene and its scripts and test-only media live in this folder. The cabinet artwork is shared from `res://Art/Textures/`.

See [Movable Objects](../../docs/movable-objects.md) to edit the paths, replace
fragment artwork, set collision shapes, or run the barrier sandbox.
