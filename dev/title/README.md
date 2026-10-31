# Curtain animation

Open `curtain.tscn` to animate the curtain. The rig has seven independent rows,
each with two `Bone2D` controls running from left to right (14 bones total).
Rows run from top to bottom, and their lengths follow the curtain's right edge.
Each row's two joints sit at 0% and 100% of its width, so the second control
is directly on the curtain edge. The last bone's short gizmo
extends outward only to keep this edge control visible in the editor.
The mesh and UVs map to the original texture at one source pixel per unit;
their outer bounds are limited to the PNG's actual 960x1080 size. The scene UID
and texture are preserved.

The scene now includes a subdivided `Polygon2D` mesh (835 vertices and 1556
triangles), matching UVs, the skeleton link, normalized vertex weights, saved
bone rest poses, and explicit bone lengths. All setup is stored in the
scene; no runtime rigging script is needed.

The seven row roots are direct children of `Skeleton2D`. Names use
`Row01_Bone01` through `Row07_Bone02`: the first number is the row, the second
is the control. `Bone01` is at the left edge; `Bone02` is on the right edge.
Every segment is a child of the preceding one within its own row. Different
rows are independent, with smooth vertex-weight blending between them.

The mesh uses approximately 36-pixel spacing, including its outline. Only the
third row's indentation receives rounded weight transitions: the blend has
zero slope at row three and unit slope at rows two and four. Other spans,
especially rows four through seven, use linear weight blending to keep the
edge close to straight spans instead of repeated S-shaped waves. The existing
silhouette and UV mapping remain unchanged. Intermediate bone motions have
been merged into each row's right-edge control using editable Bezier curves.
The left-root motion, non-bone tracks, animation duration and loop settings are
preserved. A 181-frame comparison found at most 0.12 pixels of edge-position
difference from the five-control version. Each vertex uses at most four bone influences, with normalized
weights. No runtime deformation script is used.

## Animate

The authored motion timing and deceleration are retained. Right-edge curves
combine the previous chain's motion; intermediate keys preserve that trajectory.
RESET has been rebuilt for the two-control rig.

`res://Level/title_menu.tscn` uses this curtain on both sides behind the menu
content. The right copy has a mirrored parent anchored to the menu's right
edge, so animation tracks moving the curtain root also move in the correct
mirrored direction. Both copies start and finish together. Each starts
paused at the authored first frame. Clicking **Play** runs the animation once
and holds the final pose; the button is disabled during playback and can replay
it afterwards. The menu duplicates the animation library at runtime to disable
looping locally, preserving the original looping animation for editing.

Run `godot --headless --path . --script res://dev/title/validate_menu_curtain.gd`
to check menu startup, the Play signal, single playback, repeated-click handling,
the held final pose, replay, and isolation of the original looping animation.

1. Select `AnimationPlayer` and choose **curtain**. The authored
   looping animation is preserved; edit its keys as needed.
2. Select a `Bone2D` and add position/rotation keys to the timeline. Rotate the
   horizontal bones for cloth bending; start with small rotations.
3. To keep the left edge fixed, leave each row's `Bone01` in its rest pose and
   animate `Bone02`. Animate a root to move its entire row.
   To keep the top edge fixed too, leave every bone in `Row01` at rest.
4. Preview in the animation panel. Select/play **RESET** to restore every bone's
   original position, rotation, and scale. Return to **curtain** to keep editing.
5. Enable autoplay for **curtain** if it should play when the scene runs (F6).
   Autoplay is initially off; preview the animation before enabling it.

Do not overwrite the rest pose while posing an animation. To fine-tune a region,
select `Polygon2D`, open its UV editor, and edit weights under **Bones**. The
bone list is already synchronized; adding/removing bones requires updating it.

Setup follows Godot's [2D skeleton workflow](https://docs.godotengine.org/en/stable/tutorials/animation/2d_skeletons.html).
Validation in Godot 4.7.2 covered seven rows with two right-facing controls,
complete normalized weights with at most four influences per vertex, unchanged
mesh/UVs/texture, and valid RESET tracks. Render checks at 1920x1080 included
up/down bends of three degrees per child bone, a five-degree isolated-row bend,
and a ten-degree terminal-bone bend, with no flipped triangles. The left edge
stays fixed when roots are not animated; RESET restores an identical rendered
image. Extreme poses may need weight adjustment.

## Texture regression check

Run `godot --path . --minimized --script res://dev/title/validate_curtain_texture.gd`
from the project directory, using the executable in the parent directory if
needed. This requires rendering, so do not use `--headless`.

The check compares the skinned rest pose against a plain Sprite2D, including
transparent space outside the PNG. It catches texture distortion, missing
opaque pixels, and repeated edge pixels outside the original image. Previously,
the mesh extended to x=968 while the PNG was only 960 pixels wide, stretching
its last pixel column into a visible band. Limiting geometry and UVs to the
image bounds removes this band without scaling the artwork or changing bones.
