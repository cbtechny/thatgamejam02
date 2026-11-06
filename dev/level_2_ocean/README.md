# Ocean prototype

Open `level_2_ocean.tscn` and press **F6**, or run from the project root:

```powershell
godot --path . "res://dev/level_2_ocean/level_2_ocean.tscn"
```

Drag the crank knob, press **Space** or **Press fan**, and use **R** or **Reset**
to restart. **Return to Title** opens the existing title screen; its Play
button continues to open Level 1.

The scene first shows the existing music box, holds briefly, then smoothly zooms
into the Ocean room. The box frame and stage lip remain visible during play.
The room is clipped inside the artwork's opening; zooming never changes gameplay
coordinates. Crank/fire/reset input unlocks after the entrance. Return to Title
works during the entrance, and puzzle reset keeps the view inside the room.
Tune the establishing hold, zoom duration, and room screen fraction on the
`level_2_ocean.tscn` root. The nested `ocean_room.tscn` owns the puzzle controls
and gameplay tuning.

The world uses 360 x 200 reference units with uniform scaling inside the box. The
controller exposes initial crank angle, reach limits, hop duration, and feedback
duration in the Inspector. Fixed layout and the tide formula live in the script.
The crank is directly dragged, so it does not advance automatically when held.

The shared crank, animated fan and first key fragment are reused from Level 1.
Crank angle wrapping and synthesized action sounds are adapted locally from
Level 1, including its mechanical fan whirr at the same volume and loop settings.
Fan start and whirr follow the spinning blades; the whirr stops on landing or
after a failed-action burst. Crank ticks, stranded feedback and completion use
the same click/miss/win sounds. Reset and scene exit stop all Ocean audio.
Level 1's controller and shared assets are unchanged. Platforms and ocean are
simple drawn placeholders. Movement uses scripted anchors, not physics.

Run deterministic gameplay and Level 1 input smoke checks:

```powershell
godot --headless --path . --script res://tests/level_2_ocean/run_ocean_tests.gd
```

For a rendered automated input run at the project viewport resolution:

```powershell
godot --path . --script res://tests/level_2_ocean/run_ocean_tests.gd -- --capture
```

Captures are saved under ignored `.godot/ocean_qa/`. These checks cover both
routes across a wave cycle, reach boundaries, bobbing, locked moving targets,
repeated activation, resets during hops, scene exit, and Level 1 crank/release.
They also check entrance input locking, nested mouse coordinates, viewport
resizing, GUI controls after zoom, and exiting during the entrance. Rendered
captures include the full-box establishing shot and zoom midpoint.
They do not replace human playtesting or listening to the audio.
