# Level 3: Night Ocean

Open `dev/level_3_ocean/level_3_ocean.tscn` and press **F6** for the same
music-box entrance as Level 2. `ocean_room.tscn` runs the room directly.
Drag the crank, press **Space** to fire the fan, and press **R** to reset.

The seven anchors are start, log1, log2, rockA, log3, rockB, goal.
All three logs float with the original tide and waves. Start is fixed at
y=150, both dead-end rocks at y=140, and the high goal at y=90.
At low tide each rock catches the fragment; at high tide it can pass the
rocks via log3 to the goal. Reach limits, first-reachable targeting, locked
hop destinations, controls, fan behavior and sounds match Level 2.

`Darkness` supplies ambient color `(0.05, 0.06, 0.12)`.
`SweepLight` uses a soft radial gradient (radius about 122 reference units).
Its x is `lerpf(30, 330, 0.5 + 0.5 * sin(_crank_angle * 0.5))`.
The crank keeps Level 2's angle wrapping. `Fragment/FragmentLight` moves
with the key and only illuminates its z layer, preserving nearby darkness.
All sprites retain default lit materials. Only GUI controls are unshaded
for readability. CanvasModulate also darkens the surrounding music-box art.
No Level 2 files or shared resources are modified.

Run from the project root:

```powershell
godot --headless --path . --script res://tests/level_3_ocean/run_level3_tests.gd
godot --path . --resolution 1920x1080 --script res://tests/level_3_ocean/run_level3_tests.gd -- --capture
```

Checks cover a full wave cycle, both rock traps, the complete route, repeated
fan activation, reset, light positions, default sprite materials and the
music-box entrance. The rendered run also compares key pixels with its light
on and off, and saves screenshots under `.godot/level3_qa/`.
