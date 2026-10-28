# First-person combat and true ADS

This pass replaces the player's primitive hands with the supplied rōnin's actual skinned human arms, hands, fingers and kimono sleeves. Both playable factions use this first-person rig. Enemy characters, their animation adapter, the palace, AI, menu and audio systems retain their existing implementation.

The changes are on `feat/first-person-ads`, prepared for review against `main`. The Windows archive is a build of that branch; it has not been merged or run on native Windows.

## Presentation

`FirstPersonViewmodel` selects 11,416 arm/sleeve triangles from the existing imported rōnin mesh. It retains their vertex attributes, skin binds, materials and textures and the original 58-bone skeleton. Only a new triangle index list is created in memory, cached across matches. It does not edit or re-export the supplied GLB or Blender source. Two-bone arm solving follows weapon grips, and the original finger bones articulate around the stock or hilt. The dedicated transparent viewmodel viewport preserves the existing world camera and prevents nearby palace geometry from cutting through hands/weapons. It has its own modest lighting rig.

Right mouse smoothly raises the musket so the open rear notch and front blade top share the camera center line. These small sight additions are first-person attachments to the original gun; its mesh and the bots' guns are unchanged. The normal reticle fades out as ADS settles. Hit/kill markers remain brief confirmation after a hit. Walking sway is heavily reduced in ADS. Crouching retains the same eye-relative sight geometry.

Shots retain the existing eye-origin hitscan. The sight line and shot line coincide; a nearby wall between the eye and target still blocks damage. The visual muzzle flash follows the presented barrel. There is no second barrel ray that silently redirects shots into nearby cover.

Recoil includes a short rearward kick, slight rotation, hand follow-through, muzzle flash and subtle camera roll, followed by recovery. Katana ready, draw and slash poses use the same original weapon and articulated hands. Switching dips the visible weapon and changes it at the existing switch midpoint. Death hides the viewmodel and clears ADS; respawn resets recoil, poses and FOV. A held aim button must be released before aiming again after respawn.

## Reload contract

The existing `Musket.remaining` is the sole reload clock. Presentation never starts, pauses or completes an ammo reload. Its five-second choreography is sampled from elapsed reload progress:

| Portion | Presentation |
| --- | --- |
| 0–20% | Lower and tilt the gun |
| 20–39% | Support hand reaches toward the off-screen pouch |
| 39–62% | Hand returns for a loading gesture near the barrel |
| 62–79% | Brief handling motion near the lock |
| 79–100% | Return support hand and raise to ready |

Switching to katana hides musket handling while the ammo clock continues. Returning samples the current remaining time. Katana attacks remain usable during that reload. The unchanged mechanics are 100 musket damage for body/head, 55 katana damage, 2.7 m melee range, 0.8 s melee cooldown and three-second respawn. No weapons or controller support were added.

## Actual Godot evidence

These are screenshots from the running palace scene, with the HUD hidden for inspection:

| State | Screenshot |
| --- | --- |
| Musket hip ready | [Rest](fp-rest.png) |
| Aligned rear/front iron sights | [ADS](fp-ads.png) |
| Recoil and muzzle flash | [Fire](fp-fire.png) |
| Support hand reaching off the gun | [Pouch](fp-reload-pouch.png) |
| Loading gesture | [Load](fp-reload-load.png) |
| Katana grip | [Ready](fp-katana.png) |
| Slash | [Attack](fp-slash.png) |
| Mid-switch dip | [Switch](fp-switch.png) |

[27-second footage](../dist/ASHIGARU-FirstPerson-Combat.mp4) is a deterministic staged first-person demonstration recorded by Godot Movie Maker at 1280×720, 30 FPS, with existing game audio. It is not a real-time performance benchmark or human playtest.

## Validation

**147 checks passed with zero failures**: [33 first-person checks](first-person-output.txt), [52 combat checks](first-person-combat-output.txt), [28 palace checks](first-person-palace-output.txt), and [34 rōnin checks](first-person-ronin-output.txt). The display-backed suites had no skipped checks. Baseline autonomous combat completed with scores 18–24; the palace match ended 10–12 with all nine bots visiting the interior, and the rōnin match ended 9–10. The [Linux exported-binary smoke](first-person-export-smoke-output.txt) also passed (7–5).

The [Windows build](../dist/ASHIGARU-FirstPerson-Windows.zip) exports successfully with embedded PCK; ZIP CRC and file contents are verified against the build folder. Native Windows execution remains untested. `tests/first_person.gd` exercises the actual running Godot game, input events, physics raycasts, damage and ammunition clock. It covers source geometry/skin, both weapon grips, right-click ADS, both sights projected to center, reticle fade, movement while aiming, aimed hit/score, recoil/flash, articulated reload stages, measured five-second duration, background reload with a working katana, resuming current reload, nearby wall occlusion, crouch/sprint, death/respawn and menu cleanup.

Reproduce with Godot 4.6.3 and a working desktop display:

```sh
source tools/runtime.sh
DISPLAY=:9 ./tools/test.sh
DISPLAY=:9 godot --path . --audio-driver Dummy --fixed-fps 60 --disable-render-loop --script tests/first_person.gd
DISPLAY=:9 godot --path . --audio-driver Dummy --fixed-fps 60 --disable-render-loop --script tests/palace.gd
godot --headless --path . --fixed-fps 60 --script tests/ronin.gd
```

The display is needed for captured mouse movement and real right-click input. Screenshots/footage use normal rendering, not `--disable-render-loop`.

## Remaining limits

The viewmodel is a stylized procedural adaptation of a third-person skin, not a separately authored professional FPS animation set. Fine finger/thumb contact, wrist deformation, sleeve folds and contact during the most extreme slash/reload poses still warrant artist polish. The pouch gesture reaches off-screen; it does not introduce a newly modeled pouch, powder or ramrod. Reload is deliberately abbreviated rather than historically complete. The isolated viewport uses fixed viewmodel lighting rather than following every local palace light. Existing third-person crouch limitations remain as recorded in [the rōnin report](RONIN.md).

The short exported headless smoke reports existing resource-cleanup warnings when it quits during active gameplay; these are retained in its raw log. The full test suites finish without runtime errors, aside from the display driver’s unsupported VSync warning.

Native Windows execution and gaming-GPU performance remain unverified. The cloud display uses llvmpipe CPU rendering, so offline recording speed is not evidence of playable Windows frame rate. No character decimation or new LODs were introduced. Source `.blend` still requires newer Blender than this environment provides.

GitHub API access in this environment is blocked (`gh api ...`: Forbidden), so automatic PR creation is unavailable even though Git branch push is supported. The prepared PR description is [FIRST_PERSON_PR.md](FIRST_PERSON_PR.md).
