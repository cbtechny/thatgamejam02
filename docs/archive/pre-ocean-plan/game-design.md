# Game Design

## Game Overview

The player turns a winding key to move Movable Objects inside a box. Movable Objects include key fragments, decorative objects, and functional objects. Assemble the key fragments into a complete key to complete the level. The new key opens the next level. It also serves as the winding key for that level. Use the mouse and keyboard to play. Each Movable Object follows its winding key's progress along an authored path. Later levels add barriers that the player can move aside for a short time. A second winding key becomes available after Level 3.

## Controls

- Hold the left mouse button on the winding key and drag around its center. Clockwise movement winds the key.
- While holding the key, drag counterclockwise around its center to reduce its winding angle.
- Release the left mouse button after winding: Release the key and move the Movable Objects.
- Click the completed key: Collect the key and open the next level.
- Press Space: Move special objects aside for a short time. This action key may have more functions later.
- Press Esc: Pause or resume the game.

## How Winding Keys Work

- Movable Objects stay still while you wind the key. When you release the key, the Movable Objects move along set paths.
- The winding angle stays between 0° and 270°. The more you wind the key, the farther its Movable Objects travel after release.
- A full 270° wind advances each unobstructed object by one full path. A 135° wind advances it by half its full path length. Objects do not have a separate Speed setting. Different path lengths use the same normalized winding progress.
- On release, the key turns back smoothly from its wound angle to its starting angle. The default full unwind takes 4 seconds; a 135° unwind takes 2 seconds. This duration is set per winding key.
- You cannot operate the winding key while it unwinds. Wait until the key returns to its starting position. Then wait 2 seconds before you use it again.
- The same actions must always produce the same results.
- Collisions stop an object without stopping its winding key. Blocked winding travel is lost. If the obstacle clears before the key reaches zero, the object continues with the remaining winding progress without catching up.

### Winding Key 1

This is the starting winding key. When the key finishes unwinding, the Movable Objects it controls stay still for 1.5 seconds. These Movable Objects then return to their starting positions in 0.5 seconds.

Return movement also checks collisions. A blocked return waits for the obstacle to clear and can take longer than 0.5 seconds. The winding key's 2-second input delay still starts when the key reaches its starting angle.

### Winding Key 2

You get this winding key after Level 3. When the key finishes unwinding, the Movable Objects it controls stay in place. When you use this key again, these Movable Objects continue from those positions.

### Rules for Both Winding Keys

The first three levels use only Winding Key 1. Later levels use both winding keys. Each winding key controls a different set of Movable Objects. Each Movable Object responds to only one winding key. After you assemble a complete key, the active winding key disappears. *We still need to decide how to show the winding key disappear.*

## Completing a Level and Retrying

1. Make the key fragments form a complete key after the Movable Objects stop.
2. Keep the key assembled for 1 second to trigger success.
3. Click the key.

Assembly does not count while the Movable Objects move or return to their starting positions. This rule prevents automatic success each time the player fully winds the key. After success, all Movable Objects stop. You can collect the key at any time.

To retry:

1. Press Esc to open the pause menu.
2. Select **Retry** to restart the current level.
