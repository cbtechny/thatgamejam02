# Core Loop

## Core Gameplay Loop

Observe the scene → Wind up and release the crank → Trigger special objects at the right moment → Check whether the fragments fit together → Adjust and retry → Collect the key → Move to the next level.

## Starting the Game

The player clicks PLAY. The curtains of the music box open, revealing the first level. When the player enters for the first time, the crank glows to indicate that it can be interacted with. If the player hasn't started winding it after 30 seconds, a dragging gesture hint appears.

## Observation and Experimentation

The player observes the positions and movement paths of the key fragments, as well as the special objects in the scene. Hold the crank with the left mouse button and drag around its center. Clockwise movement winds it; counterclockwise movement reduces the angle. The angle stays between 0° and 270°. Movable objects stay still until release.

The crank then unwinds to its starting angle. A 270° wind advances each unobstructed object along its full path; 135° advances it along half the full path. All objects use normalized crank progress, with no separate object Speed setting. The default full unwind lasts 4 seconds. Input stays locked during unwind and for 2 seconds after the crank reaches its starting angle.

While the objects are moving, the player can press an action key to activate special objects. For example, temporarily moving a barrier out of the way to let a key fragment pass through. The player needs to find the correct winding angle and the right timing for using the action key.

The crank keeps unwinding while an object is blocked. That blocked travel is lost. When the path clears, the object continues using the winding progress that remains.

## Checking Results and Retrying

Once the movable objects stop, the game checks whether the three key fragments have assembled correctly. If they haven't, the player can adjust their next attempt based on where the fragments stopped.

When Crank 1 reaches its starting angle, its objects hold for 1.5 seconds, then return along their paths in 0.5 seconds if clear. A blocked return waits for clearance. Objects controlled by Crank 2 remain where they stopped. A later winding adds travel from their actual kept positions, capped at the path endpoint.

The player can also select "Retry" from the pause menu to reset the entire level to its initial state. This also resets the usage limits and cooldowns of special objects.

## Completing a Level

The level is completed when all three key fragments come together and remain assembled for 1 second. Upon success, all movable objects stop, and the completed key begins to glow. The player clicks the key to collect it.

The newly collected key unlocks the next level and becomes its crank. The curtains transition to a new scene, beginning the next gameplay loop.

## Completing the Game

After completing all levels, the music box is fully assembled. The curtains open completely, revealing the finished music box as the full theme song plays.
