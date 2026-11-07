# Release integration handoff — November 7, 2026

Base revision: `3ba7860471c67d169fcea031443298a2f5d3a664` on `main`.
This change is local work on top of that revision. It has not been agreed with
Packy as a final shared release commit, pushed, uploaded or submitted.

## Implemented

- Existing title → key → day ocean → night ocean → ending progression retained.
- Mute and Exit available in pause, failure, success, title and ending menus.
  Mute controls Master audio and persists for the current run.
- Level 1 can pause during released-key flight; repeated Retry is guarded.
- Help and contributor/music/AI/engine credits are accessible from title and ending.
- One original theme recording player survives scene changes. Pause suspends its
  playhead, resume continues it, and the whole track repeats only after finishing.
  No recording edits, sampling, pitch changes or per-stage copies were introduced.
- Night landing-edge/label and crank markers preserve the authored lighting and
  anchor geometry while keeping interaction readable outside the moving light.
- Windows x86_64 export preset, reproducible build script, player instructions,
  engine notices and a build/source manifest added. Export dependencies include
  code-loaded resources, not just scene-attached resources.

## Verification and artifacts

Use `dev/release/build_windows.ps1` for current verification; its logs are under
`.godot/release-logs`. A successful package is
`builds/ClocksInOrange-Windows-candidate.zip`, with BUILD.json inside.
The source snapshot is identified by `builds/source-files.sha256`.

- Baseline: Level 1 47/47, Ocean 1007/1007, Night Ocean 1116/1116.
- Release behavior: 56 checks passed, including real mouse menu actions,
  mute across scenes, pause during flight/hops, both rock traps and repeated Retry.
- A scripted complete solve passed with real mouse/key input, physics and timed
  hops: Main → all puzzles → ending → replay → title, including both rock retries.
- Rendered captures of the full route are under `builds/screenshots/`; title,
  menus and ending were also checked at 1280×720. Scripted runs are reproducible
  integration tests and do not constitute an uncoached human playtest.
- The initial standalone export exposed missing code-loaded dependencies;
  these were added to the preset. Final package launch/packed-resource checks
  are recorded against the packaged candidate in `builds/verification.json`.
- Some older regression scripts quit without stopping the new music singleton,
  so their logs can contain an MP3 playback/resource warning at engine shutdown.
  The new release harness stops audio before quitting; normal Exit/window-close
  now drains the mixer before shutdown. Script/runtime errors still fail the build.

Original theme file SHA256:
`49b64f420c7426cbbdfc6771d0f87de648ba692988f24811128c015f4557806f`.
The recording is unchanged from the base revision.

## Deferred artwork — explicit user decision

Lilith's new curtains, wood planks and rocks have **not** been imported. The user
said they are still in the team's chat and requested skipping them now for a
future polish pass. Do not treat these deliveries as integrated or block this
technical candidate on them. Recheck silhouettes against actual landing anchors
when that later import happens. No replacement artwork was drawn here.

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
