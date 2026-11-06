# thatgamejam #02

> A small, visual game inspired by the feeling of a piece of music.

This is our in-progress entry for [thatgamejam #02](https://itch.io/jam/thatgamejam02). We are still choosing the final game idea, so this repository begins with a reliable Godot foundation and a deliberately small scope.

## Current status

- **Project:** Minimal Godot project is ready and shared.
- **Platform target:** Desktop Windows or macOS build for itch.io.
- **Display target:** 1920×1080, with Godot canvas stretching enabled.
- **Engine:** Godot 4.7.2-stable, standard GDScript edition.
- **Next decision:** Pick one small idea to turn into a playable test.

## The brief

**Theme:** “Hear it. Feel it. Turn it into play.”

The jam asks us to turn the emotions, contrasts, and transformations suggested by the theme music into gameplay, interactions, or a world. It does not have to be a rhythm game.

Our north star is a short, complete experience: one clear idea, one satisfying interaction, and room for the art and sound to carry the feeling.

## Start here

1. Install **Godot 4.7.2-stable** (standard/GDScript build).
2. Clone this repository and import `project.godot` in Godot.
3. Run the project. It currently opens an intentionally empty startup scene.
4. Listen to the [official theme track](https://www.youtube.com/watch?v=z71a6UtZ6GY), then share one feeling, image, or small interaction it suggests.
5. Keep changes focused, testable, and committed so the team always has a safe starting point.

## Team

| Person | Focus | Contact |
| --- | --- | --- |
| **Lilith** | Writing, concept, and hand-drawn art | Discord: `Anthropo7874` · Threads: [@uanranu](https://www.threads.com/@uanranu) |
| **Chris** | Code and technical setup | Discord: `ninjapiraterobotalien` · [GitHub](https://github.com/cbtechny) · [itch.io](https://ninjapiraterobotalien.itch.io/) |
| **Packy** | Producer, coordination, technical art, and animation | Discord: `Packy` · [GitHub](https://github.com/n374500601) |

## Working direction

Nothing is locked yet. The strongest ideas so far lean toward a dreamy, nostalgic, visually driven experience with a simple interaction—for example, a wind-up music box that rewinds part of its world, or a compact visual puzzle.

Before building deeply, agree on:

- the player’s one main action;
- what changes when that action succeeds or fails; and
- the smallest complete version we can play in a day.

## Jam essentials

- **Jam dates:** October 24–November 7, 2026. Submissions close November 7 at 23:59 PT.
- **Team size:** Three people, within the five-person limit.
- **Final submission:** One game, through one platform, with a Windows or macOS build.
- **Credits:** Add every contributor to the final itch.io submission.
- **Assets:** Use work we own or assets with appropriate licenses.

Read the full, current [official jam rules and FAQ](https://itch.io/jam/thatgamejam02) before submission.

## AI and asset disclosure

AI-assisted research, translation, or coding may be used where helpful. If AI-generated material appears in the final game, we will clearly disclose what was generated and how it was used on the game’s description page.

The supplied theme recording is optional. If used, it must stay unmodified and be used only inside this jam entry—no remixing, sampling, or rearranging.

## Project structure

```text
Main.tscn       Title menu; Play opens dev/Level 1 - Alt/level_1.tscn
project.godot   Godot project and desktop display settings
dev/            Fan level, winding prototype, curtain and movable-object tools
tests/          Surreal shader and panorama manual comparison scenes
```

See [the development scene index](dev/README.md) and
[the manual test index](tests/README.md) for runnable scenes.

## Working agreement

- Keep the scope small enough to test quickly.
- Check in before replacing another teammate’s work.
- Preserve editable source files alongside exported game assets.
- Before final upload, test the intended build and confirm the credits, roster, licenses, and any required AI disclosure.

## Rights and licensing

No license is granted for this repository. Code and team-created assets remain the property of their respective creators unless the team later publishes a license.
