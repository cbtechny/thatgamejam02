# Release integration handoff - November 7, 2026

This integration combines `main` at `e196704bee1a49667cee7086af4c95f6abab443f`
with `polish` at `294f22b1b8018bd3f5bd886478d9da02e4b889d6`.
The review branch is `integrate/main-into-polish`, targeting `polish`.
No merge into either shared branch, upload or submission is performed here.

## Combined behavior

- Packy's new curtains/platform artwork, shared ocean mechanics, four-shot day
  crossing and five-shot lighthouse crossing are retained. Board motion, tide,
  landing tolerances, fan placement and lighthouse timing are unchanged.
- Main's persistent original theme player, mute/exit controls, help, credits,
  Level 1 flight pause, guarded retries and Windows export setup are included.
- Night markers follow the current platform anchors/names and render above the
  drawn lighthouse mask. Dim landing edges, captions and the crank ring remain
  legible outside the beam; the scene lighting and mechanics remain intact.
- Release instructions describe timed landings and retries after missed shots.
  The pier and breakwater are crossing platforms, not the old rock traps.
- The release regression and real-input playthrough use the redesigned puzzles.
  No forced completion, target repositioning or puzzle-state shortcuts are used
  by the full playthrough.

## Verification and artifacts

`dev/release/build_windows.ps1` runs the level/campaign/release checks, exports
Windows x86_64 and creates `builds/ClocksInOrange-Windows-candidate.zip`.
Its logs are under `.godot/release-logs`; the source manifest and BUILD.json
identify the candidate. Integration-specific logs are under
`.godot/integration-qa`.

- Level 1: 47 passed; day ocean: 147 passed; lighthouse: 23 passed headless.
- Release behavior: 57 checks passed, including mouse menus, persistent mute/audio,
  flight/hop pause, lighthouse marker ordering and repeated retry after misses.
- Campaign/navigation, Level 1 input/presentation, full-screen layout/menu
  headless checks and both ornament regressions passed.
- Real-time and fixed-step real-input playthroughs: zero failures through Main, all three
  puzzles, both miss retries, ending, replay and title. It uses the stage clocks,
  real input and physics rather than directly setting gameplay state.
- Rendered lighthouse: 29 checks passed, including both beam directions and
  darkness samples and a landing edge outside the beam at 1920x1080.
- Rendered release checks: 57 passed, including title/menu bounds at 1920x1080
  and 1280x720. The rendered full playthrough also completed with zero failures.
- Windows export succeeded. The extracted PCK passed the 57 release checks and
  complete real-input playthrough from an isolated resource directory. Native
  extracted-EXE headless startup also passed; forced test exit leaves the known
  audio shutdown warning. Human playing/listening remain pending.
- The export preset explicitly includes the new shared ocean base scripts and
  platform textures. The build now checks the exported PCK in isolation, and
  allows the longer full playthrough 120 seconds instead of 55.
- Prior main-only pass counts and packaged artifacts do not validate this
  combined source. Use the integration evidence and newly built candidate.
- Some older harnesses leave MP3 playback/resource warnings during engine
  shutdown. Normal Exit/window-close drains the audio mixer. Script/runtime
  errors still fail the build. A sandbox root-certificate-store warning is
  unrelated to this offline game's behavior.

Original theme file SHA256, verified unchanged:
`49b64f420c7426cbbdfc6771d0f87de648ba692988f24811128c015f4557806f`.

## Integrated artwork

The new curtains, wood planks and rocks are included from `polish`. The earlier
main-only deferral no longer describes this integration. Their source assets,
import settings, authored geometry and landing behavior are preserved.

## Remaining release gates

- **Human:** one fresh, uncoached full playthrough; headphones and speaker
  listening through transitions, retries, pause, mute and ending.
- **Team:** agree with Packy on the final commit and title; confirm the complete
  asset-rights/AI inventory. Known AI-assisted painted cutouts are disclosed;
  the repository does not establish provenance for every other shared texture.
- **Itch access:** supplied URL is https://anthrop0.itch.io/clockwork-orange.
  A public request returned 404. This could be a private/unpublished page;
  authenticated admin access and Lilith's invitation remain unverified. The browser
  access host is unavailable in this session. No page edits or uploads were made.
- **Publication:** use `docs/release/itch-page.md` for prepared copy/metadata,
  confirm all three authors/admins, upload the tested ZIP, submit to the jam,
  download that uploaded ZIP into a new folder and launch it. Verify the entry
  appears in the jam and points at the tested file.

Official deadline checked November 7: **November 7 at 23:59 Pacific /
November 8 at 02:59 Eastern**. Rules require a Windows or Mac build, English
default language, contributor credits and disclosure of AI-generated assets.
The provided Jason Grace recording must remain unmodified and stay within the
jam entry. Source: https://itch.io/jam/thatgamejam02
