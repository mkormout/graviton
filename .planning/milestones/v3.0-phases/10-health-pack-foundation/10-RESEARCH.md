# Phase 10: Health Pack Foundation - Research

**Researched:** 2026-04-14
**Domain:** Godot 4 item system — new pickup type, drop table wiring, heal path
**Confidence:** HIGH

## Summary

Phase 10 adds a Health Pack item using the existing item infrastructure. The codebase already
has `ItemType.ItemTypes.HEALTH`, the `Item` base class, `ItemDropper`/`ItemDrop` for drops, and
a routing match branch in `Ship.picker_body_entered()`. The work is additive: create the item
resource, create the scene with procedural visuals, fix one broken method (`pick_health`), and
wire the drop table into 5 enemy scenes. One critical gap: the Suicider has **no** ItemDropper or
CoinDropper node at all — adding health-pack drops requires creating both a CoinDropper node and
an ItemDrop resource sub-resource in that scene.

**Primary recommendation:** Build the health-pack scene with two Polygon2D bars + PointLight2D +
CPUParticles2D as decided, patch `Ship.pick_health()` to clamp-heal instead of calling storage,
then add the weighted ItemDrop entry to each enemy's CoinDropper (creating CoinDropper on Suicider
from scratch).

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** One Health Pack restores **25% of max_health (2500 HP)** at current max_health=10000
- **D-02:** Heal is capped at max_health — no overheal
- **D-03:** Green cross built procedurally with two overlapping **Polygon2D** rectangles (horizontal bar + vertical bar)
- **D-04:** Color: bright green (~#00FF88). Apply `modulate` with value > 1.0 on the Polygon2D for emissive appearance
- **D-05:** Add a **PointLight2D** for the emissive glow effect
- **D-06:** **Subtle ambient** — small `CPUParticles2D` emitting slow outward green dots around the cross
- **D-07:** Particles should be low-count and low-velocity; not distracting, just visible
- **D-08:** Add health-pack as an additional **ItemDrop entry in each enemy's existing CoinDropper** node
- **D-09:** Weight the health-pack entry at ~11% to achieve ~10% effective drop rate per roll
- **D-10:** All 5 enemy types get the health-pack entry: Beeliner, Sniper, Flanker, Swarmer, Suicider
- **D-11:** Reuse the existing `ItemType.ItemTypes.HEALTH` enum value — no new enum value needed
- **D-12:** Fix `Ship.pick_health()` in `components/ship.gd` to heal the ship instead of adding to storage

### Claude's Discretion

- Exact Polygon2D vertex coordinates for the cross shape
- PointLight2D radius and energy values
- CPUParticles2D particle count, lifetime, and emission radius
- Exact weight values in the drop table to achieve ~10% net probability

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ITM-01 | Any destroyed enemy has a 10% chance to drop a Health Pack | ItemDropper.roll() uses weighted random; add health-pack entry with ~11 weight vs coin 100 weight → ~10% effective rate |
| ITM-02 | Health Pack has a green cross visual with emissive glow and particle aura | Polygon2D + modulate>1 for emissive look; PointLight2D for glow; CPUParticles2D for aura — all standard Godot 4 nodes |
| ITM-03 | Player ship heals when picking up a Health Pack | Ship.picker_body_entered() already routes HEALTH to pick_health(); fix pick_health() to set health = min(health + heal_amount, max_health) |
</phase_requirements>

---

## Standard Stack

### Core (all pre-existing in codebase)

| Node/Class | Purpose | Source |
|-----------|---------|--------|
| `Item` (`components/item.gd`) | Base class for all pickup items; provides `pick()`, `type: ItemType`, `count: int` | [VERIFIED: codebase] |
| `ItemType` (`components/item-type.gd`) | Resource describing item; `ItemTypes.HEALTH` enum already exists | [VERIFIED: codebase] |
| `ItemDropper` (`components/item-dropper.gd`) | Drop table node; `roll()` weighted random, `drop()` spawns results | [VERIFIED: codebase] |
| `ItemDrop` (`components/item-drop.gd`) | Resource with `model: PackedScene`, `chance: float` (0–100 range) | [VERIFIED: codebase] |
| `Body` (`components/body.gd`) | Base physics body; has `health: int`, `max_health: int` fields | [VERIFIED: codebase] |
| `Ship` (`components/ship.gd`) | Player ship; `pick_health()` currently broken (calls storage.add_item) | [VERIFIED: codebase] |

### Visual Nodes

| Node | Purpose | Notes |
|------|---------|-------|
| `Polygon2D` | Procedural shape rendering | Two instances form the cross (H bar + V bar) |
| `PointLight2D` | 2D dynamic light for glow effect | Godot 4 standard; texture required (can use default or GradientTexture2D) |
| `CPUParticles2D` | Particle aura | CPU-based, no GPU required; works in all render modes |
| `CircleShape2D` + `CollisionShape2D` | Pickup collision | Match coin pattern: `collision_layer = 32`, `collision_mask = 0` |

**Installation:** No packages required — all built-in Godot 4 nodes.

---

## Architecture Patterns

### Recommended Project Structure

```
prefabs/health-pack/
└── health-pack.tscn       # Item scene (matches res://prefabs/{name}/{name}.tscn convention)

items/
└── health-pack.tres       # ItemType resource (type=HEALTH, name="health-pack")
```

### Pattern 1: Item Scene Structure (follow coin-copper.tscn)

**What:** Every item scene is a `RigidBody2D` with the `Item` script, a collision shape, and
visual children. Health-pack replaces the Sprite2D with Polygon2D nodes.

**When to use:** All pickup items follow this exact layout.

**Coin-copper.tscn as template (verified structure):**
```
Coin-copper [RigidBody2D, script=item.gd]
  collision_layer = 32    # picker Area2D detects this layer
  collision_mask = 0
  contact_monitor = true
  max_contacts_reported = 10
  Sprite2D
  CollisionShape2D [CircleShape2D radius ~150]
  LightOccluder2D
  AudioStreamPlayer2D
```

**Health-pack.tscn adapted structure:**
```
Health-pack [RigidBody2D, script=item.gd]
  collision_layer = 32    # same as coins — picker Area2D uses this layer
  collision_mask = 0
  contact_monitor = true
  max_contacts_reported = 10
  CrossH [Polygon2D]        # horizontal bar
  CrossV [Polygon2D]        # vertical bar  
  PointLight2D
  CPUParticles2D
  CollisionShape2D [CircleShape2D]
  AudioStreamPlayer2D       # reuse ammo-pick.mp3 or coin-pick.wav
```

**Source:** [VERIFIED: codebase — coin-copper.tscn, item.gd, ship.gd]

### Pattern 2: ItemType Resource (follow coin-copper.tres)

**What:** A `.tres` file with `ItemType` script, `name` matching the prefab folder, `type` enum.

**Coin-copper.tres verified structure:**
```gdscript
// [gd_resource type="Resource" script_class="ItemType" ...]
name = "coin-copper"       // must match prefabs/{name}/{name}.tscn
title = "Copper Coin"
type = 0                   // ItemTypes.COIN
price = 1
image = <Texture2D>        // optional — nil OK for health-pack
```

**Health-pack.tres:**
```
name = "health-pack"       // → loads res://prefabs/health-pack/health-pack.tscn
title = "Health Pack"
type = 3                   // ItemTypes.HEALTH (index in enum: COIN=0, AMMO=1, WEAPON=2, HEALTH=3)
price = 0                  // no market value
```

**Source:** [VERIFIED: codebase — item-type.gd enum, coin-copper.tres]

### Pattern 3: ItemDrop Weighted Roll

**What:** `ItemDropper.roll()` sums all `chance` values then draws a random float in [0, total].
Items are selected cumulatively. Returning `null` means no item dropped (the dropper silently
skips null results).

**Verified roll() logic:**
```gdscript
func roll() -> PackedScene:
    var totalWeight = 0
    for item in models:
        totalWeight += item.chance
    var randomValue = randf_range(0, totalWeight)
    var cumulativeWeight = 0
    for item in models:
        cumulativeWeight += item.chance
        if randomValue <= cumulativeWeight:
            return item.model
    return null   # safe — drop() null-checks this
```

**Current Beeliner CoinDropper:** `models = [coin-copper (chance=1.0)]`, `drop_count = 2`

**To achieve ~10% health-pack rate:**
The CoinDropper currently has coin at weight 1.0. To get ~10% health-pack probability:
- Add health-pack entry with `chance = 0.11`
- New total weight = 1.11
- Health-pack probability = 0.11 / 1.11 ≈ 9.9%
- Coin probability = 1.0 / 1.11 ≈ 90.1%

**Note:** `drop_count = 2` on most enemies means each drop rolls the table twice independently.
The 10% target from ITM-01 is per-roll, not per-death. With drop_count=2, the probability of
at least one health-pack from a single enemy death is ≈ 18.9%. If ITM-01 means 10% per-death
(one pack per kill), set `drop_count = 1` on CoinDropper, or interpret "10% chance" as per-roll.
**Planner note:** This ambiguity is in the discretion range — D-09 says "10% effective drop rate
per roll"; interpret as per-roll to match D-09 wording. Suggested: keep existing drop_count, use
chance ≈ 0.11.

**Source:** [VERIFIED: codebase — item-dropper.gd, beeliner.tscn]

### Pattern 4: pick_health() Heal Implementation

**Current broken implementation (verified):**
```gdscript
func pick_health(item: Item):
    storage.add_item(item)   # WRONG — adds to inventory instead of healing
    item.pick()
```

**Correct implementation (per D-01, D-02):**
```gdscript
func pick_health(item: Item):
    var heal_amount: int = max_health / 4   # 25% of max_health (D-01)
    health = min(health + heal_amount, max_health)   # clamped, no overheal (D-02)
    item.pick()
```

**Note on `damage()` route:** `Body.damage()` adds the result of `attack.calculate(defense)` to
`health`, and that result is always ≤ 0 (line: `result = min(result, 0)`). Healing cannot go
through `damage()` — it requires direct `health` mutation. The direct approach above is correct.

**Source:** [VERIFIED: codebase — ship.gd pick_health(), body.gd damage(), damage.gd calculate()]

### Pattern 5: Suicider — No ItemDropper Exists

**Critical finding:** `suicider.tscn` has **no** ItemDropper or CoinDropper node. The four other
enemies (Beeliner, Sniper, Flanker, Swarmer) all have a `CoinDropper` node ready for the new
entry. The Suicider scene requires:
1. Adding the `item-dropper.gd` script ext_resource
2. Adding the `item-drop.gd` script ext_resource
3. Adding coin-copper.tscn and health-pack.tscn ext_resources
4. Creating ItemDrop sub_resources for coin + health-pack
5. Adding a `CoinDropper` Node2D with `item_dropper.gd` script and wired models array
6. Setting `item_dropper = NodePath("CoinDropper")` on the Suicider root node

Also note: `suicider.gd` overrides `die()` — this is fine because `super(delay)` is called, which
invokes `Body.die()` which calls `item_dropper.drop()`. The ItemDropper just needs to be wired
on the root node via the `item_dropper` export.

**Source:** [VERIFIED: codebase — suicider.tscn, suicider.gd, body.gd die()]

### Anti-Patterns to Avoid

- **Using `damage()` for healing:** `damage.calculate()` clamps to ≤ 0; passing negative energy
  will be clamped to zero — healing has zero effect. Use direct `health` mutation instead.
- **Setting `collision_layer` to anything other than 32:** The picker Area2D in the player ship
  detects `collision_layer = 32`. Using layer 64 (ammo) or 1 (enemies) will not trigger pickup.
- **Omitting `type` on the Item scene:** `Ship.picker_body_entered()` early-returns if
  `item.type == null`. The scene must wire the `type` export to the `.tres` resource.
- **Using `name_item` in the resource:** `ItemType.name_item` is for an alternate "item" scene
  variant (the `0item.tscn` pattern). Health-pack does not need this; leave `name_item` unset.
- **Forgetting `spawn_parent`:** `ItemDropper.drop()` uses `spawn_parent.call_deferred("add_child", node)`
  and warns if spawn_parent is null. The `spawn_parent` is set on the Item instance by `drop()`
  if the node has the property (via `"spawn_parent" in node` check). As long as the health-pack
  scene root has `spawn_parent` (inherited from `Body`), this is automatic.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Weighted random drop selection | Custom random logic | `ItemDropper.roll()` | Already implemented, null-safe, handles edge cases |
| Item pickup routing | Custom signal or collision detection | Existing `Ship.picker_body_entered()` + collision_layer 32 | Already wired for HEALTH; just fix `pick_health()` |
| Item scene spawning | Manual `add_child` in enemy script | `ItemDropper.drop()` called from `Body.die()` | Auto-invoked on death; handles position scatter and velocity |
| Health clamping | Custom clamp logic | `min(health + heal, max_health)` inline | One-liner; overheal prevention is trivial here |

---

## Common Pitfalls

### Pitfall 1: Wrong collision_layer on health-pack scene

**What goes wrong:** Health pack spawns in the world but player flying over it does nothing.
**Why it happens:** The player ship's picker Area2D is configured to detect `collision_layer = 32`
(coins). If the health-pack uses layer 64 (ammo) or any other value, it will not enter the picker.
**How to avoid:** Set `collision_layer = 32` on the health-pack RigidBody2D root, matching coin-copper.
**Warning signs:** No `picker_body_entered` calls in the debugger when flying over the item.

### Pitfall 2: `heal()` via `damage()` does nothing

**What goes wrong:** Health appears to not increase on pickup.
**Why it happens:** `Damage.calculate()` always clamps the result to `min(result, 0)` — negative
damage (which would be positive health delta) is zeroed out.
**How to avoid:** Set `health` directly: `health = min(health + heal_amount, max_health)`.
**Warning signs:** Health stays at current value after picking up the pack.

### Pitfall 3: Suicider drops nothing (missing ItemDropper node)

**What goes wrong:** Suicider dies but never drops a health-pack or coins.
**Why it happens:** `suicider.tscn` has no ItemDropper node and `item_dropper` export is not set.
`Body.die()` checks `if item_dropper:` before calling drop — silently skips if null.
**How to avoid:** Add CoinDropper node to suicider.tscn AND set `item_dropper = NodePath("CoinDropper")`
on the root Suicider node.
**Warning signs:** Suicider dies with no item spawn; no warning in Output panel (it's a silent if-null check).

### Pitfall 4: ItemType resource `name` field mismatch

**What goes wrong:** Health-pack item is picked up but calling `item.type.instantiate()` elsewhere
fails (scene not found error).
**Why it happens:** `ItemType.init()` loads `"res://prefabs/%s/%s.tscn" % [name, name]`. If
`name = "healthpack"` but scene is at `prefabs/health-pack/health-pack.tscn`, it 404s.
**How to avoid:** Set `name = "health-pack"` in the .tres to match the directory and scene name exactly.
**Warning signs:** "Scene not found" error in Output panel on item instantiation (not during pickup,
only if some other code calls `item.type.instantiate()`).

### Pitfall 5: PointLight2D has no texture — renders as nothing

**What goes wrong:** PointLight2D is added to the scene but emits no visible glow.
**Why it happens:** In Godot 4, `PointLight2D` requires a `texture` property — without a texture,
it renders nothing even with `energy > 0`.
**How to avoid:** Assign a `GradientTexture2D` or the built-in `default_white.png` as the
PointLight2D texture. A radial gradient (white center to transparent) gives the best glow look.
**Warning signs:** No visible glow around the health-pack in the running game, even though the node
exists in the scene.

### Pitfall 6: CPUParticles2D lifetime and amount — performance in swarms

**What goes wrong:** Many Suiciders or Swarmers spawn, each dropping a health-pack; dozens of
CPUParticles2D instances running simultaneously causes framerate drop.
**Why it happens:** CPUParticles2D is CPU-bound; high particle counts multiply linearly with
instance count.
**How to avoid:** Keep particle `amount` very low (8–16 particles max). Lifetime can be long
(3–5s) to keep visual presence without constant respawning. Low velocity (50–150 px/s range).

---

## Code Examples

### Correct pick_health() implementation

```gdscript
# In components/ship.gd
# Source: [VERIFIED: body.gd health/max_health fields; damage.gd clamp behavior]
func pick_health(item: Item):
    var heal_amount: int = max_health / 4   # 25% per D-01
    health = min(health + heal_amount, max_health)   # clamped per D-02
    item.pick()
```

### ItemDrop sub_resource in enemy .tscn (to add to all 5 enemies)

```gdscript
# Sub-resource to add alongside existing coin entry
[sub_resource type="Resource" id="Resource_health_pack_drop"]
script = ExtResource("3_itemdrop")
model = ExtResource("X_healthpack")    # assign fresh ext_resource ID
chance = 0.11

# Updated CoinDropper models array (example Beeliner):
[node name="CoinDropper" type="Node2D" parent="."]
script = ExtResource("2_itemdropper")
models = Array[ExtResource("3_itemdrop")]([SubResource("Resource_coin_drop"), SubResource("Resource_health_pack_drop")])
drop_count = 2
```

### Health-pack.tscn root node configuration

```gdscript
# Source: [VERIFIED: coin-copper.tscn pattern; item.gd exports]
[node name="Health-pack" type="RigidBody2D" node_paths=PackedStringArray("pick_sound")]
collision_layer = 32        # CRITICAL: matches picker Area2D detection layer
collision_mask = 0
contact_monitor = true
max_contacts_reported = 10
script = ExtResource("1_item")
pick_sound = NodePath("AudioStreamPlayer2D")
type = ExtResource("2_healthpackres")   # points to items/health-pack.tres
```

### Polygon2D cross shape vertex coordinates (discretion area)

```gdscript
# Horizontal bar: 300 wide, 100 tall (centered at origin)
[node name="CrossH" type="Polygon2D" parent="."]
modulate = Color(0, 2.55, 1.36, 1)   # #00FF88 at modulate > 1.0 for emissive
polygon = PackedVector2Array(-150, -50, 150, -50, 150, 50, -150, 50)

# Vertical bar: 100 wide, 300 tall (centered at origin)
[node name="CrossV" type="Polygon2D" parent="."]
modulate = Color(0, 2.55, 1.36, 1)
polygon = PackedVector2Array(-50, -150, 50, -150, 50, 150, -50, 150)
```

### PointLight2D configuration (discretion area)

```gdscript
[node name="PointLight2D" type="PointLight2D" parent="."]
texture = <GradientTexture2D radial white-to-transparent>
color = Color(0, 1, 0.53, 1)       # matches #00FF88
energy = 1.5
texture_scale = 3.0                # scale determines glow radius (~450px at scale 3)
shadow_enabled = false
```

### CPUParticles2D aura configuration (discretion area)

```gdscript
[node name="CPUParticles2D" type="CPUParticles2D" parent="."]
emitting = true
amount = 12
lifetime = 4.0
one_shot = false
emission_shape = 0             # EMISSION_SHAPE_SPHERE
emission_sphere_radius = 80.0
direction = Vector2(0, 0)
spread = 180.0                 # omnidirectional
initial_velocity_min = 20.0
initial_velocity_max = 80.0
color = Color(0, 1, 0.53, 1)  # #00FF88
scale_amount_min = 0.3
scale_amount_max = 0.8
```

---

## State of the Art

| Old Approach | Current Approach | Notes |
|--------------|------------------|-------|
| `pick_health()` adds to storage | Fix to heal ship directly | Bug present in current codebase — phase fixes this |
| Suicider has no drop table | Add CoinDropper node to suicider.tscn | Suicider is the only enemy missing drop infrastructure |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `collision_layer = 32` is the picker detection layer (based on coin-copper.tscn having layer 32) | Architecture Patterns | Health-pack won't be picked up; planner should verify picker Area2D collision_mask in player ship scene |
| A2 | No pick sound file exists specifically for health; reusing `coin-pick.wav` or `ammo-pick.mp3` is acceptable | Standard Stack | Minor — worst case is wrong audio feel; easily swapped |
| A3 | PointLight2D in Godot 4.2 requires an explicit texture to render | Common Pitfalls | If wrong, glow may work without texture; pitfall is harmless false positive |

---

## Open Questions

1. **Exact drop_count intent for Suicider**
   - What we know: Suicider has no CoinDropper; must be created from scratch
   - What's unclear: Should Suicider drop coins at all, or only health-pack? The CONTEXT says all 5 enemies get health-pack in CoinDropper, but Suicider's CoinDropper doesn't exist yet
   - Recommendation: Mirror Beeliner pattern — create CoinDropper with coin (chance=1.0) + health-pack (chance=0.11), drop_count=1 (Suicider is a kamikaze; generous loot is fine)

2. **Per-roll vs per-death 10% probability**
   - What we know: Most enemies have drop_count=2 (two rolls per death). ITM-01 says "10% chance to drop a Health Pack"
   - What's unclear: Does 10% mean per-roll or at least one pack per death?
   - Recommendation: D-09 says "10% effective drop rate per roll" — use chance=0.11 and leave drop_count unchanged. Document this interpretation in the plan.

---

## Environment Availability

Step 2.6: SKIPPED — this phase is code and scene file changes only. No external CLI tools, databases, or services are required beyond the Godot editor.

---

## Validation Architecture

`workflow.nyquist_validation` is explicitly `false` in `.planning/config.json`. Section skipped.

---

## Security Domain

No authentication, networking, user input persistence, or cryptography in this phase. Security domain not applicable.

---

## Sources

### Primary (HIGH confidence)
- Codebase: `components/item-type.gd` — ItemTypes enum with HEALTH at index 3; verified HEALTH already exists
- Codebase: `components/item.gd` — Item base class, pick() method, type/count exports
- Codebase: `components/item-dropper.gd` — roll() logic, drop() spawn pattern, null-safety
- Codebase: `components/item-drop.gd` — chance float (0–100 range export), model PackedScene
- Codebase: `components/ship.gd` — pick_health() bug (adds to storage), picker_body_entered routing
- Codebase: `components/body.gd` — health/max_health fields, die() calls item_dropper.drop()
- Codebase: `components/damage.gd` — calculate() clamps to ≤ 0; healing via damage() impossible
- Codebase: `prefabs/coin/coin-copper.tscn` — item scene template (collision_layer=32 confirmed)
- Codebase: `prefabs/enemies/suicider/suicider.tscn` — confirmed no ItemDropper or CoinDropper
- Codebase: `prefabs/enemies/beeliner/beeliner.tscn` — CoinDropper pattern with weights verified
- Codebase: `items/coin-copper.tres` — ItemType resource format verified

### Secondary (MEDIUM confidence)
- None required — all findings drawn directly from codebase

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Item system integration: HIGH — read and verified every relevant source file
- Visual nodes (Polygon2D, PointLight2D, CPUParticles2D): HIGH — standard Godot 4 nodes, well understood
- Exact vertex coordinates / light energy values: [ASSUMED] — discretion area, reasonable defaults provided
- Drop weight math: HIGH — roll() algorithm read directly; math verified

**Research date:** 2026-04-14
**Valid until:** 2026-05-14 (stable codebase; no external dependencies)
