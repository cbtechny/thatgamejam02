# Winder Test 1: Time Scroll

Run the project with **F5**, or open `winder_test_1_time_scroll.tscn` and run it with **F6**.

- Hold the left mouse button on the winder and drag clockwise to add coins.
- Drag counterclockwise to remove coins.
- Release to play the song from its beginning. Coins drain as it plays; a partial balance plays that fraction of the song.
- If the song ends with coins left, it starts again until the balance is empty.
- At zero, reverse music plays while the background smoothly returns to its starting point.
- Cranking pauses playback. During a return, adding coins turns the background forward from its current position and starts the song from the beginning.

The scene and its scripts and test-only media live in this folder. The cabinet artwork is shared from `res://Art/Textures/`.
