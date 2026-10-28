> Clean-barrel ADS correction: **87 current checks passed**, zero failures/skips (35 first-person + 52 combat). Windows rebuilt; hip-fire/ADS screenshots refreshed. See [current report](FIRST_PERSON.md). Counts below describe the earlier overhaul.

> The first-person branch passes **147 Godot checks**: 33 new first-person, 52 combat, 28 palace and 34 rōnin checks. See [current report](FIRST_PERSON.md). Earlier observations below remain historical context.

> Current character integration adds 34 rōnin-specific checks to the 80 gameplay/palace checks: **114 checks total, zero failures**. See [rōnin validation and limitations](RONIN.md), [rōnin raw output](ronin-output.txt) and [five-model performance](ronin-performance.txt). The palace-only observations below are retained as map-pass context.

# Current validation

The palace pass runs 80 checks: the existing 52 combat/animation regressions and 28 palace-specific checks. Both display-backed suites passed with zero failures or skips. See [combat output](integration-output.txt), [palace output](palace-output.txt), and the [palace report](PALACE.md) for scope, footage and limitations.

Palace checks cover the baked engine navmesh, expanded route grid, ten combatants, non-overlapping spawns, damage protection, auto-sprint movement, physical player traversal through connected rooms/gardens/courtyard, reachable sight-blocking cover, distinct flanks, real bot visits inside the palace, cover selection and a full autonomous match. All nine bots visited the palace and the observed match ended 11–12.

The regression suite retains movement, crouch, musket/katana damage, five-second background reload, weapon animation, headshot classification, hit feedback, visible death completion, no attacks while dead, respawn and complete score-ended matches. Headless runs explicitly skip two mouse-capture checks and are not equivalent to the display-backed run.

[Performance output](palace-performance.txt) measures 300 actual rendered frames after warm-up at 1280×720 with ten actors. Mesa llvmpipe is a CPU renderer, so these results do not establish dedicated-GPU or Windows performance. The benchmark is run separately from capture/tests to avoid competing game windows.

Windows and Linux exports use the already SHA-512-verified Godot 4.6.3 templates. The Linux binary is additionally smoke-tested; see [export output](export-smoke-output.txt). Native Windows execution is unverified. ZIP contents are CRC-checked and checksummed in `dist/SHA256SUMS.txt`.

Screenshots and navigation footage are real Godot output. Capture observes an idle player plus nine autonomous bots, not a human playtest. Earlier animation footage predates this palace overhaul and is retained as historical evidence.

The virtual display warns about unsupported VSync changes. Short forced exits may report active audio resources at shutdown. Normal integration teardown explicitly stops audio. Long-session leak profiling remains unperformed.
