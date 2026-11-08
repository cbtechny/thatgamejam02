# Clocks in Orange

### A music-box puzzle in three movements.

**Wind a music box, guide a key across the tide, and find your way through the night.**

Step inside a hand-painted music box for three small puzzles about timing, tides, and finding a way forward. Lift and release the key, cross the tidal ferries, then guide its final journey through the night beneath a sweeping lighthouse beam.

**[Play / download on itch.io](https://ninjapiraterobotalien.itch.io/clockwork-orange)** · Windows · Made for [thatgamejam #02](https://itch.io/jam/thatgamejam02)

To play, extract the ZIP and run `ClocksInOrange.exe`. Keep `ClocksInOrange.pck` beside the executable. No Godot installation needed.

---

## A game made between time zones

This little music box came together a few hours at a time.

Three collaborators—Lilith, Chris, and Packy—brought different languages, different time zones, and different skills to the same game jam. There was no single room where everyone could gather around a screen. The shared workspace was a Discord conversation, a GitHub repository, and the next message someone would read when they came back online.

A sketch could start a conversation. A playable experiment could give that sketch motion. A screenshot, a clip, or a GitHub comment could reveal what still needed work. Someone would leave a question or propose a change; the others would respond when their schedules allowed. We discussed ideas, voted on changes, and worked toward agreement about what belonged in the game. Those decisions became the next small set of things to build.

AI helped us communicate across languages and assisted the programming work. It helped translate messages, explain technical ideas, and turn a limited evening of work into something the next teammate could pick up. The people on the team supplied the ideas, artwork, judgment, and decisions that gave the game its direction.

That rhythm shaped the project: make something, share it, listen, adjust. A few hours on the crank. Another session on the key and fan. Hand-drawn scenery, animation, water, drifting platforms, a lighthouse. Then the quieter work of bringing everything together—clearer instructions, retries, pauses, transitions, credits, and an ending.

The result is a small journey from a mechanical puzzle to open water and finally into darkness. Its three movements also carry a record of how we worked: separate contributions, passed back and forth, gradually finding a shared rhythm.

## Three movements

### Ⅰ — The Music Box

Turn the crank. Lift the key. Release it at the right moment to meet the moving piece—and watch the pieces join.

### Ⅱ — Tidal Ferries

Set the tide with the crank and fire the fan. Time each shot onto the drifting ferries, then cross the pier to the keyhole.

### Ⅲ — Lighthouse

Carry the journey into the dark, beneath a sweeping lighthouse beam. Cross the breakwater and reach the final keyhole.

## How to play

| Control | Action |
| --- | --- |
| **Mouse** | Drag the crank |
| **Space** | Release the key / fire the ocean fan |
| **R** | Retry after a miss / reset the stage |
| **Esc** | Pause / resume |
| **Tab or arrows + Enter** | Navigate menus |

Clickable on-screen keycaps mirror the keys. A missed landing ends the run—press **R** or choose **Retry** to start again.

Every stage supports pause, retry, return to title, mute, and exit. Mute carries across stages for the current run. Find **How to Play** and **Credits** on the title screen, with full credits again at the ending.

## The team

| Person | Contribution | Find them |
| --- | --- | --- |
| **Lilith** | Writing, concept, and hand-drawn art | [GitHub](https://github.com/Anthropo7874) · [itch.io](https://anthrop0.itch.io/) · Threads: @uanranu |
| **Chris · Ninja Pirate Robot Alien** | Programming and technical setup | [GitHub](https://github.com/cbtechny) · [itch.io](https://ninjapiraterobotalien.itch.io/) |
| **Packy** | Production, coordination, technical art, and animation | [GitHub](https://github.com/n374500601) · [itch.io](https://pac-k.itch.io/) |

**Theme music composed by Jason Grace.** The supplied theme recording is included unmodified, for this jam entry only. It is not licensed for reuse in other projects or future releases.

## AI disclosure

Lilith created the game's original hand-drawn artwork and contributed its writing and concept. AI tools assisted with translation, some UI components, and coding. Team members worked across different time zones and languages, and AI was essential to real-time communication. AI-assisted visual work was limited, including background ornament cutouts adapted from contributor-supplied hand-painted artwork.

## Rights

Team-created code and assets remain the property of their respective creators. No general repository or asset reuse license is granted. The supplied theme recording has the separate restrictions described above.

Made with **Godot Engine**, licensed under the MIT license. See [Godot's license and third-party notices](https://godotengine.org/license/).

---

## Open the project

**Godot 4.7.2-stable · GDScript · GL Compatibility**

Import `project.godot` in Godot 4.7.2-stable and press **F5**.

**Title → The Music Box → Tidal Ferries → Lighthouse → Music-box ending and credits**

The game is a complete three-stage prototype with restart and return-to-title controls. One theme player persists across scenes and pauses with the game. The project includes regression checks and scripted full-game playthroughs; these complement human playtesting and validation of the actual exported package.

### Project guide

| Document | What you will find |
| --- | --- |
| [Current game design](docs/game-design.md) | The shared creative and gameplay direction |
| [Current gameplay loop](docs/core-loop.md) | How the mechanisms and stage flow fit together |
| [Full-game completion plan](docs/completion-plan.md) | The completion checklist |
| [Implementation status and limitations](docs/implementation-status.md) | Implemented behavior and known limits |
| [Release handoff](docs/release/status.md) | Recorded validation and remaining acceptance |
| [Windows build instructions](dev/release/README.md) | Exporting and checking the downloadable package |
| [Scene index](dev/README.md) | Standalone experiments and development scenes |
| [Test index](tests/README.md) | Regression scenes and commands |

The delivery target is desktop Windows on itch.io, with a 1920×1080 reference presentation. Before publishing a new build, test the actual exported package.

When contributing, keep changes focused, preserve editable sources and resource UIDs, and coordinate before replacing a teammate's work. Keep `.godot/` caches and exported builds out of source control.
