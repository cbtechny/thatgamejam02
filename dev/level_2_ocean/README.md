# Level 2: Tidal Ferries

Open `level_2_ocean.tscn` and press **F6** to play the music-box entrance and
puzzle. `ocean_room.tscn` opens the room directly.

Drag the crank or hold **Left / Right** to adjust the water continuously.
The two ferries run on independent loops, including while the crank is still.
**Space / Press fan** fires the fan mounted on the current deck. The fading
dots show the start of the shot. The next deck needs to catch the fragment
when it arrives. A high shot continues down after the initial fan arc.
A miss ends the attempt. **R** retries from shore, and **Esc** opens pause.

```powershell
godot --headless --path . --script res://tests/level_2_ocean/run_ocean_tests.gd
godot --path . --resolution 1920x1080 --script res://tests/level_2_ocean/run_ocean_tests.gd -- --capture
```

The regression checks continuous mouse release, tide independence, timed
landings, misses, reset and the four-shot route. Captures are saved under
`.godot/ocean_qa/`.
