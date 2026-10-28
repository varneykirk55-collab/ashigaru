# Validation and limitations

Validated with Godot 4.6.3 Standard on Linux. Rendering used Xorg's dummy display and Mesa llvmpipe OpenGL 4.5. Tests are automated gameplay tests; no human keyboard-and-mouse playtest or native Windows test was performed.

## Evidence

`DISPLAY=:9 ./tools/test.sh`: **29 checks passed, 0 failed, 0 skipped**. The suite loads the actual game scene, dispatches a real mouse input event through the viewport, steps collision physics, and exercises production weapon and match systems.

Covered: launch menu, faction UI selection, four-versus-four match, first-person camera, WASD movement, mouse yaw/pitch, jump/gravity, GUI input routing, musket ray damage and team score, single-shot lockout, ten-second reload timing and ammunition consumption, katana range/damage/cooldown, friendly-fire protection, player death/respawn, paused clock, grid routing, score-limit results, faction-switching restart, timer results, and return to menu.

The last portion is a 90-second autonomous simulation using normal spawns, normal damage, and no forced kills or target teleporting. At least five bots moved more than two metres; both sides independently scored. The latest validated run ended with Samurai 33, Rōnin 36. Controlled tests earlier in the suite freeze/reposition bots to isolate weapon damage and respawn assertions; the autonomous phase starts a fresh match.

Headless runs explicitly skip the two captured-mouse checks because the headless display cannot capture a mouse. They do not substitute for the full display run.

Windows x86-64 and Linux x86-64 release exports were built using the official 4.6.3 templates, verified with the release's SHA-512 list. The Windows artifact was confirmed to be a PE32+ x86-64 executable. Native Windows execution is **unverified** (no Windows runner/Wine available).

The exported Linux binary launched headlessly and ran its own 60-second match smoke check: `--headless --fixed-fps 60 -- --smoke-match`. Both teams scored (23–20). Export smoke checks run production gameplay, not the source integration script.

Screenshots `menu.png`, `gameplay.png`, `reload.png`, and `katana.png` were captured from the running OpenGL game, not mockups. Weapon screenshots use a reproducible central-lane starting position. No gameplay video was recorded.

## Known limitations

- **The brief's realistic visual target is not met.** Character meshes are original provisional assembled silhouettes, with armor/helmet or dark cloth identifying factions. There are no rigged humanoid walk/death animations or first-person hands. They remain replaceable in `Geometry.warrior`.
- Arena architecture and materials are original procedural prototype art. The courtyard has tiled halls, colonnades, cover, gates, lanterns, trees, side passages, and open lanes, but needs a dedicated environment-art pass.
- Weapon motion is procedural recoil/tilt/swing, not a detailed flintlock loading animation. Reload progress and the complete ten-second timing are functional. The supplied Flintlock model is used as the musket.
- Melee uses a centre ray with physical range, not blade-volume sweep detection. Bots use grid A*, direct sight rays, simple targeting and movement, and body collisions; no squad tactics or crowd avoidance beyond collision are implemented. Pathological crowding may need tuning.
- Sound is original synthesized placeholder audio, not production foley. Settings support volume, mouse sensitivity, and fullscreen; there is no key-rebinding UI or controller support.
- UI targets 1280×720 with canvas scaling. Very unusual aspect ratios and high-DPI Windows behavior have not been tested.
- No networking, dedicated server, save-game progression, installers, code signing, or realistic asset production was added.
- The virtual display reports unsupported VSync changes; short forced `--quit-after` runs can report audio playback resources still alive at shutdown. Normal integration cleanup explicitly stops audio. These do not establish a gameplay failure, but long-session resource profiling remains unperformed.

This deliverable establishes a tested combat loop. It should not be presented as a finished realistic commercial game.
