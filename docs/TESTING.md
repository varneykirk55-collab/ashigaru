# Current validation

Godot 4.6.3 Standard on Linux, Xorg dummy display, Mesa llvmpipe OpenGL renderer. `DISPLAY=:9 ./tools/test.sh` runs the production scene, physics, input routing and combat systems: **52 checks passed, 0 failed, 0 skipped**.

The suite verifies menus, both factions, first-person movement/mouse look, jump/gravity, musket damage and ammunition, five-second automatic reload while the katana is selected, recoil/reload/switch/swing motion, melee damage/cooldown, friendly-fire rules, crouch camera/collision transitions, physical headshot/body classification, hit reaction, visible death motion and completion, no combat or movement while dead, delayed body recycling, respawn, pause, navigation, timer/score results, restart and return to menu.

A fresh 90-second autonomous simulation uses normal bots, normal spawns and unmodified damage. Both sides score independently (31–33 in this run). The same match then continues to a score limit through normal combat and reaches its results screen without forced kills. Earlier controlled assertions reposition/freeze actors to isolate individual systems; they are not used as evidence of autonomous bot behavior.

[Raw integration output](integration-output.txt). Headless runs explicitly skip two mouse-capture checks and are not equivalent to the display-backed run.

The Windows x86-64 release is built using the retained, officially SHA-512-verified Godot templates. It has not been run natively on Windows (no Windows runner/Wine). The Linux x86-64 export is additionally smoke-tested with `--headless --fixed-fps 60 -- --smoke-match`; see [export output](export-smoke-output.txt). Both build ZIPs are CRC-checked and checksummed in `dist/SHA256SUMS.txt`.

Footage and screenshots are rendered by the actual game, not mockups. The capture is scripted and labels its staged and autonomous segments. No human mouse-and-keyboard playtest was performed. See the [animation report](ANIMATION.md) for the status of all requested states and the missing Claude asset.

## Remaining limitations

Character art, hands, scenery and synthesized audio remain provisional. Procedural poses and fall reactions are not authored skeletal animation or physics ragdolls. No foot/finger IK, detailed flintlock loading choreography, scene-aware corpse collisions, squad tactics, controller support or networking were introduced. Bot routing/targeting, arena geometry, weapon models and audio assets are retained.

Melee remains a physical centre ray rather than a blade-volume sweep. The UI targets 1280×720; unusual aspect ratios, long-session resource profiling and native Windows behavior remain untested. The virtual display reports unsupported VSync changes. Short forced shutdowns can report still-active audio resources; normal test teardown stops audio explicitly.
