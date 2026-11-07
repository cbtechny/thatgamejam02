# Clocks in Orange — thatgamejam #02

A music-box puzzle game built with Godot 4.7.2-stable (GDScript, GL Compatibility).

## Current direction

Three stages: a crank-and-fan mechanism, a daytime ocean puzzle, and a night ocean puzzle. The goal is a complete game with finished visuals, guidance, transitions, audio, ending, and credits.

- [Current game design](docs/game-design.md)
- [Full-game completion plan](docs/completion-plan.md)
- [Implementation status and limitations](docs/implementation-status.md)
- [Current gameplay loop](docs/core-loop.md)
- [Release handoff and remaining acceptance](docs/release/status.md)
- [Windows build instructions](dev/release/README.md)

These documents replace the earlier design. Old documents are retained under `docs/archive/pre-ocean-plan/` for historical reference only.

## Run

Import `project.godot` in Godot 4.7.2-stable and press F5. Main opens the title menu. Play starts Level 1 through `Level/level_1_music_box.tscn` with the same wide-to-room entrance as the ocean stages; completion continues to the day ocean, night ocean, and a music-box ending with credits and restart/title controls. All stages support pause, retry, return to title, mute and exit. How to Play and Credits are available from the title; full credits also appear at the ending. One theme player persists across scenes and pauses with the game. Human playtesting and listening remain separate acceptance steps.

Drag the crank; press **Space** to release the key/fire the ocean fan. Ocean **R** resets a stage; **Esc** pauses/resumes. Rocks are dead ends: use Reset or Retry. Level 1 pieces join automatically when their ends meet. Mute affects all audio and persists for the current application run.

Game page: [anthrop0.itch.io/clockwork-orange](https://anthrop0.itch.io/clockwork-orange).
New curtain, plank and rock artwork has explicitly been deferred to a future polish pass; it is not part of this release-integration change.

From this repository in the supplied Windows workspace:

```powershell
& "..\Godot_v4.7.2-stable_win64.exe" --path .
```

See the [scene index](dev/README.md) and [test index](tests/README.md) for standalone scenes and regression commands. Test scripts and reported passes do not replace human playtesting or final-build validation.

## Team

| Person | Focus |
| --- | --- |
| Lilith | Writing, concept, hand-drawn art |
| Chris | Code and technical setup |
| Packy | Production, coordination, technical art, animation |

## Delivery and asset requirements

Target: desktop Windows or macOS for itch.io, with 1920×1080 reference presentation. Confirm export configuration and test the actual exported package before release.

Keep changes focused, preserve editable sources and resource UIDs, and coordinate before replacing teammates' work. Exclude `.godot/` caches and builds from source control. Record asset rights and contributor credits. Disclose AI-generated material used in the final game on the submission page. If the supplied theme recording is used, preserve it unmodified and only use it within the jam entry; verify the current official terms before submission.

Official brief, submission timing and rules: [thatgamejam #02](https://itch.io/jam/thatgamejam02).

No repository license is granted. Team-created code and assets remain the property of their respective creators unless a license is later published.
