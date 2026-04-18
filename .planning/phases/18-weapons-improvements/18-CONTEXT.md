# Phase 18: Weapons Improvements - Context

**Gathered:** 2026-04-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Six improvements across all player weapons: fix the recoil bug, add distinct charged/spooled/homing mechanics per weapon, add visual effects to all weapons, tune balance against v3.0-buffed enemies, and add a weapon HUD. Phase ends when all six weapons have their new mechanic, visuals are in, HUD is live, and the recoil bug is gone.

No new weapons, no inventory rework, no enemy changes.

</domain>

<decisions>
## Implementation Decisions

### Recoil Fix
- **D-01:** Investigate `mountable-body.gd` line 44–47. Current code calls `apply_impulse(vector, sender.global_position / 100)` — the second argument passes global world coordinates where Godot expects a LOCAL offset from the ship's center of mass. This creates unintended torque (lateral forces, ship spin). Fix by switching to `apply_central_impulse(vector)` or by converting to local space: `apply_impulse(vector, to_local(sender.global_position))`. Fix the root cause — do NOT add a force filter unless investigation reveals no clear bug.
- **D-02:** Recoil direction is already correct (`-Vector2.from_angle(sender.global_rotation) * meta`) — only the impulse application point needs fixing.

### Gausscannon — Charged Shot
- **D-03:** Hold fire button to charge (0–2 seconds). Releasing fires the shot at whatever charge fraction was reached.
- **D-04:** Charge scales: damage, projectile velocity, and recoil magnitude — all proportional to charge fraction (0.0–1.0).
- **D-05:** Visual during charge: PointLight2D energy on the gun scales from base brightness to a bright maximum as charge builds.
- **D-06:** At full charge (2s): CPUParticles2D burst fires from the barrel (sparks/energy discharge).
- **D-07:** Quick tap = base stats (current behavior). Full charge = significantly higher damage, velocity, recoil.

### RPG — Homing Lock
- **D-08:** Lock acquisition: scan a ~30° cone ahead of the barrel for enemies within weapon range. One locked target per gun.
- **D-09:** Lock-on takes time (suggest 1.5s). Visual indicator: red double-square brackets shrink toward the target during acquisition; fully closed brackets = target locked.
- **D-10:** Fire without lock = normal non-homing rocket (current behavior). Fire with full lock = homing rocket steers toward locked target every physics frame.
- **D-11:** If locked target dies before rocket arrives, lock clears; rocket continues in current direction (no new lock mid-flight). Player must re-acquire for the next shot.
- **D-12:** Lock does NOT require holding fire — it builds passively while aiming at an enemy in the cone. Fire button still fires when ready.

### Minigun — Spooling Fire Rate
- **D-13:** Continuous fire ramps fire rate from base rate to maximum rate over 2 seconds. Rate increases continuously (not stepped).
- **D-14:** Releasing fire → rate drops back to base in ~0.5 seconds.
- **D-15:** At max spool rate: damage increases (suggest 1.5× base) AND glow effect scales with current rate (PointLight2D energy or CPUParticles2D emission rate on the gun scene).

### Laser — Bouncing Bullets
- **D-16:** Laser bullets bounce off all physics bodies (asteroids, enemies, player ship). Maximum 3 bounces per original bullet.
- **D-17:** Each bounce: the bullet spawns 2 new bullet instances at the impact point, each travelling in a reflected + slightly spread direction. Result chain: 1 → 2 → 4 → 8 bullets at max bounces.
- **D-18:** Each hit (initial + each bounce) deals full damage.
- **D-19:** Green flash effect (CPUParticles2D burst or flash sprite) at each bounce contact point.
- **D-20:** Spawned bounce-bullets inherit the remaining bounce count (decremented). Bounce count is tracked per bullet, not globally.

### Gravity Gun — Charging
- **D-21:** Hold fire to charge (0–1.5 seconds). Releasing fires.
- **D-22:** Both shockwave impulse force AND Area2D radius scale with charge fraction (0.0–1.0). Claude sets specific multipliers based on existing `strength` and `area` export values.
- **D-23:** Visual: PointLight2D on the barrel pulses faster (increase `pulse_period` decreasing over charge time) as charge builds.

### Visual Effects — All Weapons
- **D-24:** Muzzle flash at barrel on every fire event (CPUParticles2D one-shot or AnimatedSprite2D). Each weapon can have a distinct flash color/style.
- **D-25:** Bullet trail / tracer behind bullets as they travel (Line2D trail node on the bullet scene updating each frame, or CPUParticles2D trail emitter).
- **D-26:** Impact effect (sparks / debris) when any bullet hits any physics body.
- **D-27:** Screen shake on fire for heavy weapons: Gausscannon, RPG, GravityGun. Light weapons (Minigun, Laser) do not shake.

### Balance Pass
- **D-28:** Goal: both increase damage to counter the v3.0 HP buff (enemies at 2× base HP) AND give each weapon a distinct role. Claude proposes specific stat numbers for each weapon after reading enemy HP values from their scripts. Researcher should check enemy HP constants in `components/beeliner.gd`, `sniper.gd`, `flanker.gd`, `swarmer.gd`, `suicider.gd`.

### Weapon HUD
- **D-29:** Always visible while in-game: ammo counter (magazine / total remaining) for the currently active weapon.
- **D-30:** Reload progress bar shows during reload (hidden otherwise).
- **D-31:** Active weapon icon or name text displayed alongside ammo counter.
- **D-32:** Chargeable weapons (Gausscannon, GravityGun) and spooling Minigun: also show charge/spool percentage as a fill bar or value.
- **D-33:** Claude decides exact layout and placement within the bottom area of the screen, following the style of the existing `score-hud.tscn` / `wave-hud.tscn` pattern.

### Claude's Discretion
- Exact muzzle flash color and particle count per weapon
- Specific balance numbers for damage, fire rate, spread, ammo per weapon (informed by enemy HP research)
- Bounce bullet spread angle on reflection
- HUD node structure and exact screen position
- Laser bounce reflection calculation (angle of incidence = angle of reflection, or slightly randomized)
- Whether Minigun spool state persists briefly between short burst gaps or fully resets on release

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Weapon Base Class
- `components/mountable-weapon.gd` — Base class for all mountable weapons. Manages rate, magazine, ammo, reload timer, shot timer, and the fire/reload/recoil action dispatch. All weapon mechanics build on top of this.

### Recoil Bug
- `components/mountable-body.gd` — Line 44–47: `apply_impulse(vector, sender.global_position / 100)` is the likely bug site. The impulse position argument must be in local space.

### Individual Weapon Scripts / Scenes
- `prefabs/gausscannon/gausscannon.tscn` — Gausscannon scene (charge mechanic added here or in a new script extending MountableWeapon)
- `prefabs/rpg/rpg.tscn` — RPG scene (homing lock system added here)
- `prefabs/minigun/minigun.tscn` — Minigun scene (spool rate logic added here)
- `prefabs/laser/laser.tscn` — Laser scene; `components/bullet.gd` — Laser bullet that needs bounce behavior
- `prefabs/gravitygun/gravitygun-script.gd` — GravityGun custom script (charge + area scaling added here)

### Area Effect Pattern
- `components/explosion.gd` — Distance-falloff impulse + damage using Area2D. Pattern for GravityGun charge scaling.

### HUD
- `prefabs/ui/hud.tscn` + `prefabs/ui/hud.gd` — Existing HUD (health, coins, weapon debug). Weapon HUD panel added here or as a sibling CanvasLayer.
- `prefabs/ui/score-hud.tscn` + `prefabs/ui/score-hud.gd` — Style/pattern reference for new HUD elements.
- `prefabs/ui/status-bar.tscn` — Existing bar UI component; may be reusable for reload/charge bars.

### World Dispatch
- `world.gd` — Keyboard firing shortcuts (KEY_SPACE, Q/W/E) and how fire actions are dispatched to weapons. Charge input handling will need integration here.

### Enemy HP Values (for balance)
- `components/beeliner.gd`, `components/sniper.gd`, `components/flanker.gd`, `components/swarmer.gd`, `components/suicider.gd` — Check `max_health` export values to calibrate weapon damage.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `apply_impulse` / `apply_central_impulse` on RigidBody2D — fix is a one-line change in `mountable-body.gd`.
- `GravityGun.apply_kickback()` — existing `area.get_overlapping_bodies()` loop; charge scaling wraps the `strength` and `area` size before this call.
- `Bullet.collision()` — fires `body.damage(attack)` then calls `die()`. Bounce bullets need to NOT die on first hit — override or restructure this.
- `CPUParticles2D` — already used on propellers and gem lights; consistent visual pattern.
- `PointLight2D` — used on gem lights (enemy sprites phase) and propellers; scaling energy is an established pattern.
- `status-bar.tscn` — inspect this scene; it may already be a reusable fill bar for reload/charge display.

### Established Patterns
- Per-weapon custom scripts extend `MountableWeapon` (e.g., GravityGun extends MountableWeapon). New mechanics should follow the same pattern — create `GausscannonWeapon`, `RpgWeapon`, `MinigunWeapon`, `LaserWeapon` scripts if needed.
- Action dispatch via `do(sender, action, where, meta)` — existing FIRE, RELOAD, RECOIL actions. New charge input may need a CHARGE_START / CHARGE_RELEASE action pair, or handled entirely in `_input()` on the weapon script.
- `Timer` nodes added in `_ready()` — pattern used for shot_timer and reload_timer. Charge timer and spool timer follow this.

### Integration Points
- `world.gd` `_input()` — currently calls `do(self, FIRE, "")` on KEY_SPACE. Charge weapons need HOLD detection (`is_action_pressed` vs `is_action_just_pressed`). This may move charge logic into the weapon scripts rather than world.gd.
- `MountableWeapon.fire()` — entry point for all shooting. Gausscannon and GravityGun charge wraps or overrides this.
- `Bullet._ready()` — connects `body_entered` signal. Bounce bullets need a bounce counter before connecting die().

</code_context>

<specifics>
## Specific Ideas

- Recoil: user confirmed the direction is already correct; only the impulse application point is wrong (`global_position / 100` instead of local offset or central).
- Gausscannon glow: both PointLight2D energy scaling AND CPUParticles2D burst at max — user wants both combined.
- RPG lock visual: "red double square shrinking around the target" — two concentric square outlines in red that animate from large to tight as lock progresses. This is a UI element drawn over the 3D world (CanvasLayer or Node2D child following target screen position).
- Minigun: glow scales with rate, additional damage at max — user specifically said glowing + more damage at max.
- Laser: "green flash occurs while bouncing" — green particle burst at each contact point.
- Gravity Gun: user specifically confirmed both force AND area scale.

</specifics>

<deferred>
## Deferred Ideas

- None from this discussion — all stated ideas are within Phase 18 scope.

</deferred>

---

*Phase: 18-weapons-improvements*
*Context gathered: 2026-04-19*
