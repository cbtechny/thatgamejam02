# Painted background ornaments

Sources: `E:/Project/gamejam/art/IMG_9995.jpg` through `IMG_9998.jpg`.
Transparent cutouts created with imagegen from the supplied hand-painted artwork.
Source JPG files are preserved. These cutouts are AI-assisted edits; include this
in the existing final-submission AI disclosure. Asset ownership remains with the
original contributors; no new license is granted here.

Used by `Level/background_ornaments.tscn` in Level 1's clipped BoxWindow.
Positions and scales are authored in that scene; rotation speeds (degrees/second)
are exported on its root. Rotation inherits game pause.

Levels 2 and 3 reuse all four textures through `Level/ocean_ornaments.gd`.
Day: tide-coupled rise, gentle horizontal drift and rocking.
Night: elliptical orbits, slow spin, scale and opacity breathing with cool tint.
Decorations draw behind the water/platforms and inherit pause. Their animation
uses each room's elapsed time so Reset restores the starting pose.
