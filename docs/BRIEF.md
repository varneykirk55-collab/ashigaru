# CODEX — SAMURAI WITH MUSKETS: PLAYABLE FOUNDATION

## Project objective

Build a standalone, playable first-person combat game in Godot 4 for Windows PC.

Working title: **Samurai with Muskets**.

The game is fictional and combines samurai, rōnin, muskets, and katanas. Historical accuracy is not a requirement.

The visual target is grounded, realistic 3D, not primitive blocks or a low-poly cartoon aesthetic.

The gameplay structure is inspired by compact arena combat games such as Hood Warfare 2, but all code, environments, characters, and assets must be original or appropriately licensed.

## Scope and development rules

You are the sole foundation developer for this stage.

Build one complete playable vertical slice before adding secondary features.

Do not modify Arena Mortis, Iron Crowns, or any other existing game.

Create a standalone project with organized, modular systems.

Do not create unnecessary Git branches. Use a single canonical development branch where permitted and preserve commits.

## Core gameplay

### 1. First-person player controller

Implement:
- Mouse-look camera.
- WASD movement.
- Sprinting and jumping.
- Collision and gravity.
- Mouse capture and release.
- Responsive first-person controls.

### 2. Musket combat

Implement:
- Aim and fire.
- Projectile or hitscan damage.
- Muzzle flash and firing sound.
- Smoke effects.
- Approximately 10-second reload with visible progress.
- One shot per reload.
- Appropriate firing and reload animations.
- Ammo tracking.

Use the user's supplied musket reference as the visual target.

If the previous weapon model is inaccessible, use a temporary functional model and make replacement straightforward.

### 3. Katana combat

Implement:
- Switch between musket and katana.
- Melee attack input.
- Attack animation.
- Range and hit detection.
- Damage and cooldown.
- Clear hit feedback.

Use the supplied katana reference as the visual target.

### 4. Two factions

Create two opposing factions:

**Samurai**
- Armored Japanese warrior appearance.
- Visually recognizable armor and helmet.

**Rōnin**
- Black kimono-style top.
- Black hakama trousers.
- No heavy armor.

Both factions have identical gameplay statistics for the foundation.

Do not reproduce the primitive-looking character from the previous Blender experiment.

Realistic character appearance remains the target, but do not let character-asset production prevent completion of the playable foundation.

### 5. Enemy and allied bots

Implement functioning combat bots that:
- Navigate the arena.
- Detect enemies.
- Aim and shoot muskets.
- Reload.
- Approach enemies for katana attacks.
- Take damage and die.
- Respawn according to match rules.
- Distinguish allies from enemies.

Bots must fight one another as well as the player.

Do not use stationary targets as a substitute for functional bots.

### 6. Match system

Implement a basic team deathmatch:
- Samurai versus rōnin.
- Player selects a faction.
- Bots populate both teams.
- Kills contribute to team score.
- Configurable score limit or match timer.
- Match-end screen.
- Restart and return-to-menu options.

### 7. Arena

Create one compact Japanese-inspired battlefield suitable for ranged and melee combat.

Include:
- Multiple routes.
- Cover and obstacles.
- Clear spawn locations.
- A mixture of open firing lanes and close-range fighting spaces.
- Navigation suitable for bots.

Avoid an empty flat plane or an arena made entirely from obvious cubes.

Use appropriate modular environment geometry and materials. Visual polish can be refined after gameplay works.

### 8. User interface

Implement:
- Main menu.
- Play button.
- Faction selection.
- Basic settings.
- Health display.
- Ammunition and reload indicator.
- Team scores.
- Match timer.
- Death and respawn feedback.
- Match results screen.

### 9. Audio

Include appropriately licensed or original:
- Musket firing sound.
- Reload sounds.
- Katana swing and impact sounds.
- Footsteps.
- Hit and death feedback.
- Basic ambient audio.

Document the source and license of any third-party audio.

## Engineering requirements

Use modular Godot scenes and scripts for:

- PlayerController
- WeaponController
- Musket
- Katana
- BotController
- HealthComponent
- DamageSystem
- MatchManager
- SpawnManager
- HUD
- MainMenu

Design the architecture to make future multiplayer support possible, but do not implement networking during this foundation stage.

Avoid unnecessary dependencies.

## Visual requirements

Do not present primitive 3D shapes as finished visual assets.

Use believable silhouettes, properly shaped meshes, sensible materials, and consistent scale.

Do not spend the entire development session on realistic character modeling. Gameplay completion takes priority during this foundation pass.

Keep all major assets replaceable so higher-quality Blender models can be integrated later.

## Required validation

Before reporting completion, verify:

1. The game launches into the main menu.
2. The player can select a faction.
3. A match begins successfully.
4. The player can move and aim.
5. The musket fires and reloads.
6. The katana damages enemies.
7. Bots navigate and fight.
8. Both teams score kills.
9. Death and respawn function.
10. A match can end and restart cleanly.

Run automated checks where possible and perform an actual gameplay test if the environment supports it.

A successful project import or compilation alone is not sufficient evidence of a playable game.

## Deliverables

Provide:
- Complete Godot project.
- Source code and assets.
- Setup instructions.
- Windows playable build if the environment supports exporting.
- Screenshots or gameplay video.
- Testing report.
- Known limitations.

Use a permanent GitHub repository if one is connected and authorized.

Do not provide inaccessible workspace paths as though they were downloadable files.

## Completion standard

The foundation is complete when I can launch the game, choose Samurai or Rōnin, enter a match, fight functioning bots using a musket and katana, score kills, die and respawn, and finish or restart the match.

Do not claim completion if any of these essential gameplay systems are nonfunctional.

Prioritize a complete, testable gameplay loop over optional features or visual embellishments.