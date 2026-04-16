# Phase 10: Health Pack Foundation - Context

**Gathered:** 2026-04-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Add a Health Pack item type that enemies drop at 10% probability. The player heals by flying over a dropped pack. Visual: green cross with emissive glow and particle aura. Scope is limited to the item scene, drop wiring, and heal pickup path — no UI display or score integration.

</domain>

<decisions>
## Implementation Decisions

### Heal amount
- **D-01:** One Health Pack restores **25% of max_health (2500 HP)** at current max_health=10000
- **D-02:** Heal is capped at max_health — no overheal

### Visual cross
- **D-03:** Green cross built procedurally with two overlapping **Polygon2D** rectangles (horizontal bar + vertical bar)
- **D-04:** Color: bright green (~#00FF88). Apply `modulate` with value > 1.0 on the Polygon2D for emissive appearance
- **D-05:** Add a **PointLight2D** for the emissive glow effect

### Particle aura
- **D-06:** **Subtle ambient** — small `CPUParticles2D` emitting slow outward green dots around the cross
- **D-07:** Particles should be low-count and low-velocity; not distracting, just visible in the dark space background

### Drop table wiring
- **D-08:** Add health-pack as an additional **ItemDrop entry in each enemy's existing CoinDropper** node
- **D-09:** Weight the health-pack entry at ~11% (e.g., if coins total 100 weight, add health-pack at ~11) to achieve ~10% effective drop rate per roll
- **D-10:** All 5 enemy types get the health-pack entry: Beeliner, Sniper, Flanker, Swarmer, Suicider

### Item type
- **D-11:** Reuse the existing `ItemType.ItemTypes.HEALTH` enum value — no new enum value needed
- **D-12:** Fix `Ship.pick_health()` in `components/ship.gd` to heal the ship instead of adding to storage

### Claude's Discretion
- Exact Polygon2D vertex coordinates for the cross shape
- PointLight2D radius and energy values
- CPUParticles2D particle count, lifetime, and emission radius
- Exact weight values in the drop table to achieve ~10% net probability

</decisions>

<specifics>
## Specific Ideas

- The health-pack visual should be distinguishable from coins (which use Sprite2D + PNG) and ammo — procedural green cross sets it apart
- The aura should feel like a "live" item rather than a static pickup — subtle movement is key

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

No external specs or ADRs exist for this phase. Requirements are fully captured in decisions above and the files listed below.

### Item system
- `components/item-type.gd` — ItemType resource and ItemTypes enum (HEALTH already defined)
- `components/item.gd` — Item base class (Body subclass with pick() method)
- `components/item-dropper.gd` — ItemDropper node, roll() weighted random logic, drop() method
- `components/item-drop.gd` — ItemDrop resource (model: PackedScene, chance: float)

### Pickup path
- `components/ship.gd` — pick_health() method (currently adds to storage — needs to heal instead); picker Area2D routing

### Enemy scenes (drop table targets)
- `prefabs/enemies/beeliner/beeliner.tscn` — has CoinDropper node (ItemDropper)
- `prefabs/enemies/sniper/sniper.tscn` — has CoinDropper node
- `prefabs/enemies/flanker/flanker.tscn` — has CoinDropper node
- `prefabs/enemies/swarmer/swarmer.tscn` — has CoinDropper node
- `prefabs/enemies/suicider/suicider.tscn` — has CoinDropper node

### Requirements
- `.planning/REQUIREMENTS.md` — ITM-01, ITM-02, ITM-03

### Visual reference
- `prefabs/coin/coin-copper.tscn` — Coin item scene structure (Sprite2D + CollisionShape2D + AudioStreamPlayer2D pattern)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ItemDropper` + `ItemDrop` resources: Drop table already in all enemy scenes as `CoinDropper`; add health-pack entry with weighted chance
- `Item` base class (`components/item.gd`): Extend this for the health-pack scene — provides Body physics, `pick()` method, `type: ItemType` reference
- `Body` class: `health` and `max_health` fields available on player ship for heal math

### Established Patterns
- Item scenes live at `res://prefabs/{name}/{name}.tscn` — health-pack scene must be at `res://prefabs/health-pack/health-pack.tscn`
- Item resources live in `items/` as `.tres` files — create `items/health-pack.tres` (ItemType with type=HEALTH, name="health-pack")
- Coins use `collision_layer = 32`; follow same layer for health-pack so it enters the picker Area2D

### Integration Points
- `Ship.picker_body_entered()` already matches on `IT.ItemTypes.HEALTH` and calls `pick_health()` — just fix `pick_health()` to heal
- `ItemDropper.drop()` null-checks the model from `roll()` — safe to add health-pack to weight table at any chance value
- `Body.damage()` applies negative health delta — healing is equivalent to calling `damage()` with a negative Damage, OR directly incrementing `health` clamped to `max_health`

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 10-health-pack-foundation*
*Context gathered: 2026-04-14*
