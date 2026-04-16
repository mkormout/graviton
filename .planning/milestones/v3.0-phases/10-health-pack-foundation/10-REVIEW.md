---
phase: 10-health-pack-foundation
reviewed: 2026-04-14T00:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - items/health-pack.tres
  - prefabs/health-pack/health-pack.tscn
  - components/ship.gd
  - prefabs/enemies/beeliner/beeliner.tscn
  - prefabs/enemies/sniper/sniper.tscn
  - prefabs/enemies/flanker/flanker.tscn
  - prefabs/enemies/swarmer/swarmer.tscn
  - prefabs/enemies/suicider/suicider.tscn
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 10: Code Review Report

**Reviewed:** 2026-04-14
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

This phase introduces the health pack item: a `.tres` resource, a `RigidBody2D` scene (prefab), a pickup handler in `ship.gd`, and health-pack drop table entries across all five enemy types (beeliner, sniper, flanker, swarmer, suicider).

The core pickup flow is functional. `ItemType.HEALTH` (type=3) is correctly handled in `ship.gd:picker_body_entered`, and the `collision_layer = 32` (Coins layer) allows the ship's Picker area (mask=224) to detect health packs. All five enemy drop tables correctly reference `uid://healthpack_scene_001`.

Three warnings were found that can cause incorrect runtime behavior: a zero-heal edge case, a missing `image` asset reference, and a missing collision layer on enemies. Three info-level observations cover a dead `ext_resource` import, a shared collision layer with coins, and missing UIDs on script references.

## Warnings

### WR-01: Zero-heal bug when max_health < 10

**File:** `components/ship.gd:35`
**Issue:** `heal_amount` is computed as `var heal_amount: int = max_health / 10`. GDScript integer division truncates toward zero, so any ship with `max_health < 10` heals 0 HP when picking up a health pack. The player ship (`max_health = 10000`) is unaffected, but if any ship with low health values ever picks up a health pack the item is consumed with no effect. The fix should also guard against the degenerate case where `heal_amount` evaluates to zero.
**Fix:**
```gdscript
func pick_health(item: Item):
    var heal_amount: int = max(1, max_health / 10)
    health = min(health + heal_amount, max_health)
    item.pick()
```

### WR-02: health-pack.tres missing image field

**File:** `items/health-pack.tres:1-10`
**Issue:** The resource declares no `image` field, unlike every other `ItemType` resource (`coin-copper.tres`, `minigun.tres`, etc.). `ItemType` declares `@export var image: Texture2D`, and any UI code that reads `item.type.image` for health pack items will get `null`. If the inventory HUD or a tooltip ever tries to render health pack inventory entries, it will display nothing or trigger a null-dereference depending on how the UI handles the missing texture.

No texture asset for the health pack currently exists in `images/`, so the fix requires two steps: (1) add a health-pack image asset, and (2) reference it in the `.tres`:
```gdscript
# After adding res://images/health-pack.png:
[ext_resource type="Texture2D" uid="..." path="res://images/health-pack.png" id="1_hpimg"]

[resource]
...
image = ExtResource("1_hpimg")
```

### WR-03: Enemy scenes (sniper, flanker, swarmer) omit explicit collision_layer

**Files:** `prefabs/enemies/sniper/sniper.tscn:38`, `prefabs/enemies/flanker/flanker.tscn:38`, `prefabs/enemies/swarmer/swarmer.tscn:41`
**Issue:** The sniper, flanker, and swarmer root nodes do not set `collision_layer`, relying on Godot's engine default (layer 1). The beeliner and suicider explicitly set `collision_layer = 1`. While the current behavior is identical, the omission creates an inconsistency: if `base-enemy-ship.tscn`'s default is ever changed, or if these scenes are opened in the editor and saved without attention, the missing property could be silently assigned a different value. Explicit declaration is the defensive pattern used by beeliner and suicider.
**Fix:**
```
# In sniper.tscn, flanker.tscn, swarmer.tscn — add to root node:
collision_layer = 1
```

## Info

### IN-01: Unused ext_resource in beeliner.tscn

**File:** `prefabs/enemies/beeliner/beeliner.tscn:3`
**Issue:** `base-enemy-ship.tscn` is listed as `ext_resource id="0_base"` but is never referenced in any node definition in the file. The other enemy scenes (sniper, flanker, swarmer, suicider) correctly do not include this unused reference. This is dead import cruft that adds load overhead and could confuse future readers into thinking beeliner inherits from `base-enemy-ship.tscn`.
**Fix:** Remove the `ext_resource` line for `base-enemy-ship.tscn` and decrement `load_steps` on the `[gd_scene]` header accordingly.

### IN-02: Health pack reuses the Coins collision layer (layer 6)

**File:** `prefabs/health-pack/health-pack.tscn:22`
**Issue:** `collision_layer = 32` is bit 6, documented in `world.gd` as the "Coins" layer. The Picker's `collision_mask = 224` (bits 6, 7, 8) was designed to detect Coins, Ammo, and Weapon Items — health packs are not mentioned. This works at runtime because the Picker dispatches on `ItemType.type`, not on collision layer, but the layer comment in `world.gd` is now incorrect and could mislead future collision setup. A dedicated layer (e.g., layer 9) and an update to the Picker mask and the `world.gd` comment would keep the architecture self-documenting.
**Fix:** Add a layer 9 "Health Pack" entry to the `world.gd` comment, assign `collision_layer = 512` in `health-pack.tscn`, and update the Picker's `collision_mask` to `224 | 512 = 736`.

### IN-03: Script ext_resource references without UID in beeliner, swarmer, suicider scenes

**Files:** `prefabs/enemies/beeliner/beeliner.tscn:4`, `prefabs/enemies/swarmer/swarmer.tscn:3`, `prefabs/enemies/suicider/suicider.tscn:3`
**Issue:** The script references for `beeliner.gd`, `swarmer.gd`, and `suicider.gd` lack a `uid=` attribute (e.g., `[ext_resource type="Script" path="res://components/beeliner.gd" id="1_beeliner"]`). The sniper and flanker scripts do include UIDs. All scripts have `.uid` sidecar files on disk. Without UIDs in the scene, Godot must resolve scripts by path; renaming or moving the script file breaks the reference silently (no editor error until the scene is opened). Opening and re-saving each scene in the Godot editor will automatically add the UIDs.
**Fix:** Open `beeliner.tscn`, `swarmer.tscn`, and `suicider.tscn` in the Godot editor and resave; Godot will populate the UID attributes automatically.

---

_Reviewed: 2026-04-14_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
