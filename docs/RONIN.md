# Rōnin integration and animation validation

The rōnin faction now uses the supplied **actual skinned character**, rather than the procedural placeholder. Samurai retain their existing armored placeholder. This is the same ASHIGARU project, palace, match system and canonical `main` branch.

## Asset inspection

| Item | Verified result |
|---|---|
| Geometry | **93,590 triangles**, 14 meshes, 16 material surfaces; no mesh decimation |
| Skeleton | 58 bones, including spine, neck/head, arms/hands/fingers, legs/feet and weapon controls |
| Skin | All 14 meshes skinned; 68,331 exported vertices audited; largest weight-sum error 0.000000134; joint indices 0–57 |
| Materials | 12 materials, 26 embedded images; albedo, roughness/metallic and normal-map inputs retained where supplied |
| Transparency | Original hair/brow/lash alpha masks and eye alpha blending retained |
| World scale | Source metre scale retained: approximately 1.87 m including hair, soles at source Y=0; +Z-facing asset turned 180° to match gameplay -Z |
| Source files | GLB and Blender files retained byte-for-byte; [audit with SHA-256 hashes](RONIN_IMPORT.json) |
| Blender source | Zstandard-compressed `BLENDER17-01v0502` header. Installed Blender 4.3.2 cannot open this newer source; it was not modified or re-exported. Integration uses the supplied GLB. |

The GLB contains all nine claimed clips. Godot removes redundant/static channels during its standard import: 174 source channels become 56 imported tracks per clip. Tests compare every imported key value, key time, path, track type and duration against a fresh, unmodified import. Runtime copies alter looping metadata, not animation keyframes or source assets.

## Animation mapping

| Gameplay | Supplied clip | Runtime treatment |
|---|---|---|
| Idle | `Idle` — 3.967 s | Loops; supported carry arms when holding a musket |
| Walk | `Walk` — 1.033 s | Loops, cadence follows movement |
| Run/sprint | `Run` — 0.633 s | Loops, cadence follows movement |
| Aim | `Musket_Aim` — 1.5 s | Loops; torso/neck aiming correction keeps the weapon axis aligned |
| Fire | `Musket_Fire` — 1.2 s | Playback retimed to a short firing reaction |
| Reload | `Musket_Reload` — 11.133 s | Playback retimed to the existing **five-second** ammunition timer; background reload remains functional |
| Katana ready/attack | `Katana_Slash` — 1.733 s | Start pose provides ready arms; slash retimed to the existing 0.8 s attack cadence; repeat attacks restart the clip |
| Damage | `Hit_React` — 0.733 s | Short authored flinch; existing hit sounds and feedback preserved |
| Death | `Death` — 2.667 s | Full clip plays and holds before the existing three-second respawn; crouched entry is blended to the authored ground plane |
| Crouch/crouch-walk | **Not supplied** | Temporary additive hip/knee/ankle poses with ground-height correction, over the existing clip. This is provisional, not an authored crouch animation. |

`RoninPresentation` is a non-destructive adapter beneath `CharacterAnimator`. Manual animation playback prevents a second ammunition/physics clock. Lower-body locomotion continues under moving reloads, firing and hit reactions, rather than showing planted feet while the actor moves. Walk/run cadence is calibrated from source grounded-foot movement (approximately 0.839 and 2.085 m/s at original playback speed). Clips crossfade and upper-body presentation is smoothed. There is no new root-motion movement controller.

Weapons remain the existing musket and katana models. Animated palm transforms drive the weapon socket. Imported third-person motion uses authored poses rather than adding first-person offsets twice. A visual-only offset matches the palace hard-floor render surfaces; physical movement/collision geometry is unchanged. The head hitbox follows the animated head position. The rōnin player has an external body on a separate rendering layer; their existing first-person camera excludes that body while retaining the original first-person weapons. Other/default observation cameras see the full body. No playable third-person camera or controller support was added.

## Gameplay preservation and tests

**114 checks pass**: 52 combat/animation regressions, 28 palace/navigation checks, and 34 rōnin-specific checks. See [rōnin output](ronin-output.txt), [combat output](integration-output.txt), and [palace output](palace-output.txt).

Checks include exact imported mesh/skin/clip retention, textured hair/materials, skeleton motion, idle/walk/run selection, aiming axis, grounded crouch fallback, moving reload legs, five-second background reload, repeated slashes, hit reaction, completed death before respawn, crouched-death ground recovery, own-body camera exclusion, distinguishable Samurai, physical palace traversal and complete mixed-faction 5v5 matches.

Damage was **not rebalanced**. The existing musket still applies 100 damage to body and head hits; headshot indication is separate. Two-shot body/one-shot head balance is **not implemented or claimed**. First-person movement, sprint/crouch/auto-sprint, aiming, weapon mechanics, bot decisions/navigation, spawn protection, health, scoring, audio and palace geometry remain in place.

The Linux release export is additionally smoke-tested. The Windows release is built but **has not been run natively** in this Linux environment. A successful import is not being used as gameplay validation.

## Actual Godot visual evidence

- [Full-body rōnin with musket](ronin-musket.png)
- [Face, hair and material close-up](ronin-face.png)
- [Katana grip/ready pose](ronin-katana.png)
- [Temporary crouch pose](ronin-crouch.png)
- [Rōnin first-person view without own-body obstruction](ronin-first-person.png)
- [Animation and live-match footage](../dist/ASHIGARU-Ronin-Integration.mp4)

The footage is an actual fixed-rate Godot render with audio. The first 22 seconds are labeled **staged animation showcase**: walk/run, aim/fire/reload, katana attacks, damage, death and respawn. The remaining 22 seconds observe a fresh **live 5v5 match** with production AI. Actor paths and kills are not scripted in the live segment. It is automated capture, not a human playtest or a real-time performance benchmark.

## Performance and remaining issues

[Measured performance](ronin-performance.txt), 1280×720 overview with ten active actors including five full-quality rōnin instances: approximately **3.18 FPS** on Mesa llvmpipe CPU rendering, 311.0 ms median and 341.4 ms p95 frame times. The sampled frame reported 881 draws and about 2.90 million rendered primitives including the environment and passes. This is **not smooth real-time play on this cloud CPU renderer**. It does not establish gaming-GPU/Windows performance.

Geometry/textures remain full quality and shared by instances. Godot automatic mesh LOD generation is explicitly disabled for the release character. No character decimation or texture downsampling was introduced. For a later target-GPU optimization pass, suitable options are separately validated ~40k/~15k character LODs, reduced distant shadow detail, and compatible material atlases; retain the current full-resolution model as the close-up LOD. Native hardware profiling should precede choosing those tradeoffs.

Remaining visual work:

- Crouch has no authored source clip. The compatible fallback keeps the feet grounded, but hakama bunching and occasional cloth/arm intersections remain visible. It needs authored crouch/crouch-walk clips.
- There is no finger IK or weapon-surface contact solver. Fine support-hand/finger contact, particularly at reload extremes, needs a further fitting pass. No source mesh or skin was edited to hide this.
- Run is reused for high-speed sprint. Cadence follows world movement; high-speed stride polish and uneven-ground foot IK remain unfinished.
- Hair cards and some facial/cloth seams remain visible in close-up renders. The imported geometry/materials are retained; no geometry replacement was used to hide these issues.
- Samurai art and first-person hands remain provisional. No new Samurai asset was supplied.
- Native Windows execution, gaming-GPU performance and long-session resource profiling remain unverified. The virtual display reports unsupported VSync changes; short forced shutdowns may report active audio resources.
