# Phase 18: Weapons Improvements - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-19
**Phase:** 18-weapons-improvements
**Areas discussed:** Scope, Visual Effects, Balance, Mechanics, HUD

---

## Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Visual polish | Muzzle flash, bullet trails, impact effects, screen shake | ✓ |
| Balance tuning | Adjust damage, fire rate, spread, reload, ammo counts | ✓ |
| New mechanics | Charged shot, burst mode, homing, etc. | ✓ |
| HUD / feedback | Ammo counter, weapon indicator, reload bar | ✓ |

**User's choice:** All four categories selected.
**Notes:** User then clarified all six weapon-specific improvements in freeform: recoil fix, Gausscannon charge, RPG homing, Minigun spool, Laser bounce, GravityGun charge.

---

## Recoil Fix

| Option | Description | Selected |
|--------|-------------|----------|
| Barrel-opposite only | Pure `-barrel_direction * force` impulse | |
| Scaled by shot power | Magnitude scales with charge level | |
| You decide (Claude) | Claude reviews code and proposes fix | |

**User's choice:** Investigate root cause first. Recoil direction is already correct in the code — the bug is likely in how the impulse is applied (wrong coordinate space). Fix root cause; filter only as last resort.
**Notes:** Claude identified `apply_impulse(vector, sender.global_position / 100)` in `mountable-body.gd:46` as the probable bug — global coordinates passed where local expected.

---

## Gausscannon — Charged Shot

| Option | Description | Selected |
|--------|-------------|----------|
| 1–2s, PointLight2D glow | Energy scales dim-to-bright during charge | ✓ |
| 1–2s, particle burst at max | CPUParticles2D fires at 100% charge | ✓ |
| You decide (Claude) | Claude picks timing + visual | |

**User's choice:** Both visual options combined — PointLight2D scaling AND CPUParticles2D burst at max charge.
**Notes:** Charge window: 0–2 seconds. Stats scale with charge fraction.

---

## RPG — Homing Lock

| Option | Description | Selected |
|--------|-------------|----------|
| Cone ahead of barrel | ~30° cone, no cursor needed | ✓ |
| Cursor-nearest enemy | Lock onto enemy closest to mouse | |
| You decide (Claude) | Claude picks targeting method | |

**User's choice:** Cone ahead of barrel. Can lock multiple enemies — one lock per gun. Red double-square brackets shrink around target during acquisition.
**Notes:** User specified the shrinking bracket visual explicitly.

---

## Minigun — Spool

| Option | Description | Selected |
|--------|-------------|----------|
| 2s spool-up, fast spool-down | Max rate in 2s; drops in 0.5s | ✓ |
| 3s spool-up, slow spool-down | Longer wind-up, 2s bleed-off | |
| You decide (Claude) | Claude picks timing | |

**User's choice:** 2s spool-up, ~0.5s spool-down.

---

## Laser — Bounce

| Option | Description | Selected |
|--------|-------------|----------|
| Asteroids only, damage each hit | Enemies + ships are terminal | |
| All physics bodies, damage each hit | Bounces off everything | ✓ |
| You decide (Claude) | Claude picks by collision layers | |

**User's choice:** All physics bodies, damage each hit.

---

## Gravity Gun — Charge

| Option | Description | Selected |
|--------|-------------|----------|
| 1.5s charge, force + area scale | Both shockwave force and radius scale | ✓ |
| 1.5s charge, force only | Only impulse scales | |
| You decide (Claude) | Claude decides from Area2D implementation | |

**User's choice:** 1.5s charge, force + area scale.

---

## Balance Pass

| Option | Description | Selected |
|--------|-------------|----------|
| Faster TTK vs enemies | Bump damage/DPS; Claude proposes numbers | |
| Preserve difficulty, tune feel | Fix spread/reload/ammo, keep damage | |
| Both: damage up + role clarity | Damage increase AND distinct weapon roles | ✓ |

**User's choice:** Both — increase damage to match v3.0 HP buff AND give each weapon a clearer niche.

---

## HUD

| Option | Description | Selected |
|--------|-------------|----------|
| Ammo counter | Magazine / total ammo | ✓ |
| Reload progress bar | Fill bar during reload | ✓ |
| Weapon icon / name | Active weapon displayed | ✓ |
| Charge percentage if relevant | Charge/spool % for chargeable weapons | ✓ |

**User's choice:** All four elements. Charge % shown for Gausscannon, GravityGun, Minigun spool.
**Notes:** User added "Charge percentage if relevant" as a custom note beyond the presented options.

---

## Claude's Discretion

- Exact muzzle flash colors and particle counts per weapon
- Specific balance numbers (damage, rate, spread, ammo) — informed by enemy HP values
- Laser bounce spread angle
- HUD node layout and exact screen position
- Whether Minigun spool resets fully or holds briefly between gaps
- Laser reflection calculation approach

## Deferred Ideas

None — all stated ideas are within Phase 18 scope.
