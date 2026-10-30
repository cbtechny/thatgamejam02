# Game Implementation Status

Date: 31 October 2026. Base code: `299e792`, with local winding-control and movable-object changes.

The project has a music box test and three movable key fragments. The game has no key assembly system or level completion system.

## Technical Terms

- Winding key: The control that the player turns.
- Key fragment: One of three parts of the complete key.
- Complete key: The object that the three key fragments form.
- Movable object: A key fragment, a decoration, or an object with a game function.
- Energy: The remaining winding amount, from 0 to 270 degrees, shown by the bar.
- Shader: A program that changes an image.

## Completed Work

| Item | Current function |
| --- | --- |
| Input | Hold the left mouse button and drag around the key center. Clockwise movement winds the key; counterclockwise movement reduces the angle. The key stays between 0 and 270 degrees. Release starts the unwind. |
| Winding control | The key returns smoothly from its wound angle to its exact start. Input is locked during unwind and for 2 seconds after zero. A zero-charge release has no cooldown. |
| Movement | A 270-degree release advances a full unobstructed path; 135 degrees advances half a full path. A full unwind takes 4 seconds by default, set on each controller. |
| Movable objects | Three key fragments follow separate editable paths with the same normalized winding progress. Each responds to one controller. There is no per-object Speed setting. |
| Path editing | Select an object and drag its line points in the 2D editor. Set each point's angle under Path Rotations, or use the Edit Path Rotation toolbar button and orange handles. The sprite and collider interpolate their rotation along each segment. |
| Editor debug | The Winding Debug bottom dock previews all winding keys or one controller at 0..270 degrees without running the game. Zero is the path start; 270 is the end. Preview follows position and angle edits, is not saved, and clears before play. |
| Collision | Objects stop at solid obstacles and other objects. They continue when the path clears. Blocked time does not add travel distance. Return movement also checks collision. |
| Object stop modes | When Key 1 reaches its starting angle, its objects hold for 1.5 seconds, then return in 0.5 seconds if clear. Key 2 mode keeps objects in place and adds travel on later releases. |
| Sound | The scene plays theme music, a winding sound, and a return sound. |
| Display | The scene has music box artwork and an energy bar. |
| Shader test | A separate test uses blue at rest, gold during forward movement, and red during return. |
| Title menu | The title menu has buttons. The buttons do not start the game. |

## Required Work

Do the P0 work first, then P1, then P2.

| Priority | Item | Required change |
| --- | --- | --- |
| P0 | Key assembly | Count correct assembly only when all movable objects stop. Require 1 second of correct assembly. Do not count movement or return. Stop all objects after success. |
| P0 | Level completion | Let the player collect the complete key and open the next level. |
| P0 | Pause and retry | Use Esc to pause or continue the game. Add Retry to reset the full level. |
| P0 | Repeat test | Fixed-tick winding and object tests pass. Check repeated full-level input after assembly and level systems are complete. |
| P1 | Levels | Use only Winding Key 1 in Levels 1–3. Use both winding keys after Level 3. Use each collected key as the next level's winding key. |
| P1 | Winding Key 2 | Object stop and continue behavior, and separate controller groups, are complete. Add the second interactive winding key to later levels. |
| P1 | Special objects | Use Space to move barriers aside for a set time. Add use limits and delays. Make Retry reset these values. |
| P2 | Game entry | Connect Play to Level 1. Add curtains that open on entry and change between levels. |
| P2 | Hints | Make the winding key glow on first entry. Show a drag hint if the player does not turn the winding key for 30 seconds. |
| P2 | Success display | Make the complete key glow. Remove the active winding key. |
| P2 | Game end | Show the complete music box. Open the curtains fully. Play the full theme song. |

## Differences from the Design

| Item | Design requirement | Current operation |
| --- | --- | --- |
| Game entry | Click Play to open the curtains and enter Level 1. | The project starts the winding key test directly. |

## Open Decisions

Set these values:

- Key assembly tolerance.
- Final object paths and each winding key's full unwind duration.
- Barrier movement time, use limits, and delays.
- The visual effect that removes the winding key.

## Checks

The main, title, shader, panorama, and movable-object test scenes each ran for 30 frames without a window.
The winding and movable-object runner passed 68 checks with real 2D physics at 60 fixed frames per second. Checks include the 270-degree limit, circular drag directions, radial motion, center crossing, pointer angle wrapping, visual unwind, 2-second input lock, proportional path travel, partial ticks, collisions, per-point rotation and full turns, reverse rotation during return, rotated collider blocking and reopening, return from contact between rotated movers, separate controllers, reset, freeze, repeated input, and shader playback.
The authored return regression passed 30 checks in Main and the edited music-box scene, with 270/135/270-degree releases and restored position and rotation after every cycle. Rendered validation passed 32 checks with actual mouse winding and 1920 x 1080 captures. A rotation precheck that previously stopped touching fragments from retreating now tests translation and rotation together.
The editor debug runner passed 40 checks inside the Godot editor without starting the game. Checks include global and individual controls, immediate preview positions and rotations, clamping, live path and transform edits, point rotation handles, undo/redo/cancel, new point fields, separate groups, collision bypass, scene switching, plugin disabling, pre-play restoration, and saving authored angles without preview transforms. Validation uses a disposable project copy.
The rendered editor run passed 44 checks, including real mouse dragging with Shift snapping after editor pan and zoom, and 1920 x 1080 captures of the debug dock and rotation handles. The runtime debug overlay and autoload have been removed.
Rendered mouse checks passed for clockwise winding to the 270-degree limit, counterclockwise reduction, release, automatic unwind, input lock, timed object return, and three repeated 135-degree circular drags with matching results. Rendered keyboard checks passed for separate sandbox keys, collision blocking, barrier reopening, reset, and two half windings reaching a kept object's endpoint. Main, sandbox, and shader screenshots were checked at 1920 x 1080.
The final validation logs contain no script errors.

Full-level input tests and repeated full-level input tests are not complete.
See [Winding Keys and Movable Objects](movable-objects.md) for use, editing, collision setup, and test commands.
See the [270-degree winding screenshot](images/winding-270-degrees.png) and [collision screenshot](images/movable-object-blocking.png).
See the [point rotation editor screenshot](images/editor-path-rotation.png).
See the [authored fragments after return](images/movable-object-return.png).
See [Winding Debug in the Editor](global-debug.md) for the preview controls and screenshot.

## Sources

- [ASD-STE100 Issue 9](https://www.asd-ste100.org/assets/files/ASD-STE100_ISSUE9.pdf)
- [Game Design](game-design.md)
- [Core Loop](core-loop.md)
- [Mouse input](../dev/winder_test_1_time_scroll/winder_drag.gd)
- [Movement and sound](../dev/winder_test_1_time_scroll/music_box_timeline.gd)
- [Movable object](../Level/objects/movable_object.gd), [controller](../Level/objects/winding_object_controller.gd), and [collision test](../dev/movable_object_test/movable_object_test.tscn)
- [Winding Debug editor plugin](../addons/winding_debug/plugin.gd) and [editor validation](../dev/global_debug/validate_editor_debug.ps1)
- [Shader test](../dev/shader%20test/music_box_surreal_test.tscn)
- [Game entry](../Main.tscn) and [title menu](../Level/title_menu.tscn)
