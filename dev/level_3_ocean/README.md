# Level 3: Lighthouse

Open `level_3_ocean.tscn` and press **F6** to play the music-box entrance
and stage. `ocean_room.tscn` opens the room directly.

The lighthouse sweeps across the water on its own clock. The beam reveals
the key, platform artwork and jump dots as it passes. Dim landing edges,
platform captions and the crank ring stay visible outside the beam. Drag the crank or hold
**Left / Right** to adjust the tide, then press **Space** to fire the fan
mounted on the current platform. Watch the motion of the three drifting
boards, cross the stone breakwater and reach the keyhole. **R** retries
from shore, and **Esc** opens pause.

```powershell
godot --headless --path . --script res://tests/level_3_ocean/run_level3_tests.gd
godot --path . --resolution 1920x1080 --script res://tests/level_3_ocean/run_level3_tests.gd -- --capture
```

The regression checks the full timed route, misses, retry and the independent
beam sweep. The rendered run samples the lit and dark sides of the room and
saves captures under `.godot/level3_qa/`.
