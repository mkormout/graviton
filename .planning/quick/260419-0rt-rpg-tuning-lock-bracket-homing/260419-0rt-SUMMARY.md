---
status: complete
quick_id: 260419-0rt
date: 2026-04-19
commit: 48881da
---

# Summary

## Changes

- `prefabs/rpg/rpg-weapon.gd`: LOCK_TIME 4.0 → 1.0; fire() now derives direction from lock target when locked (rocket aims directly at target on spawn)
- `prefabs/ui/weapon-hud.gd`: bracket sizes 120→30 scaled to 360→90; replaced single-mount bracket logic with multi-mount loop over `_ship.get_mounts()`, with a `_lock_brackets` dict managing one bracket Control per active RPG
