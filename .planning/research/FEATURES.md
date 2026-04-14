# Feature Landscape: Enemy AI

**Domain:** 2D arcade space shooter — wave-based enemy AI
**Project:** Graviton v2.0 Enemies
**Researched:** 2026-04-11
**Overall confidence:** HIGH (core behaviors), MEDIUM (specific tuning values)

---

## Table Stakes

Features every enemy must have. Missing any of these and the enemy feels broken or unfinished.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Detects player within a range | Without detection, enemy ignores player entirely | Low | Single `Area2D` or distance check per physics frame |
| Moves toward or away from player | Core combat expectation for any enemy | Low | Steering seek/flee; already have `apply_central_force` on `RigidBody2D` |
| Fires projectiles or deals damage on collision | Must deal threat to player | Low–Med | Simplified fire bypasses MountableWeapon; instantiate bullet scene + apply velocity impulse |
| Has health and dies | Integrates with existing `Body` health/death pipeline | Low | Already implemented in base class; just ensure `ItemDropper` is configured per type |
| Drops loot on death | Player reward loop | Low | Already implemented via `ItemDropper`; configure drop tables per type |
| Visual state feedback | Player must read intent (charging, attacking, fleeing) | Med | Modulate color or play animation tied to state; e.g. red tint on aggro |
| Does not clip through asteroids | Physically believable movement | Low–Med | RigidBody2D handles collision automatically; steering needs to avoid getting stuck |

---

## Enemy Type Details

### Beeliner

**Archetype:** Grunt / Rusher — the simplest enemy and best first build

**Core role:** Direct-charge attacker. No tactics, no hesitation. Creates immediate pressure and teaches the player that staying still is dangerous.

**States used:** `seeking` → `fighting` → (optionally) `fleeing` at low health

**Table Stakes**

| Behavior | Why Required | Complexity |
|----------|--------------|------------|
| Charges directly at player | Defines the archetype entirely | Low |
| Fires in a straight line while charging | Adds threat during approach so player cannot just dodge and wait | Low |
| High thrust, low health | Makes it dangerous fast but destroyable quickly | Low (tuning) |
| Enters `fighting` when within firing range | Without this it either rams or never shoots | Low |

**Differentiators**

| Behavior | Value | Complexity |
|----------|-------|------------|
| Overshoot and correct course | Adds physical believability; RigidBody2D inertia makes this natural | Low (free from physics) |
| Brief hesitation before re-locking onto player | Feels like a creature "deciding" rather than a homing missile | Low (add a 0.5s cooldown on seek re-evaluation) |
| Fires a burst of shots when in `fighting` range, then re-charges | Rhythm of pressure + pause prevents trivial kiting | Low |
| Flees at 15% health | Gives player a satisfying "mop-up" moment | Low |

**Anti-Features**

| Anti-Feature | Why Avoid |
|--------------|-----------|
| Complex pathfinding | Beeliner is defined by directness; routing around asteroids loses identity |
| High health | Drags out what should be a quick, punchy encounter |

**State Transitions (recommended)**

```
IDLING → SEEKING:    player enters detection range (e.g. 600px)
SEEKING → FIGHTING:  player within firing range (e.g. 250px)
FIGHTING → SEEKING:  player exits firing range
FIGHTING → FLEEING:  health <= 15% (optional, configurable)
FLEEING → SEEKING:   health regenerated (skip if no regen; can just flee to death)
```

**Detection / fire / movement parameters (starting values for playtesting)**

- Detection range: 600 px
- Firing range: 300 px
- Thrust: high (e.g., 1.5x player's main propeller thrust)
- Fire rate: fast burst (3 shots, 0.15s apart), then 1.5s cooldown
- Health: low (e.g., 40 HP vs player's 100)

**Build order position:** Build first. Establishes all shared infrastructure: `EnemyShip` base class, state machine skeleton, simplified fire logic, wave spawner hookup. Every other type builds on this.

---

### Flanker

**Archetype:** Circler / Tactical — orbits before engaging, then attacks

**Core role:** Creates a feeling that enemies are "smart." The orbit phase denies player the easy "just shoot it" response and forces them to track a moving target. Rewards lead-aiming skill.

**States used:** `seeking` → `lurking` (orbit) → `fighting` → optionally `evading`

**Table Stakes**

| Behavior | Why Required | Complexity |
|----------|--------------|------------|
| Approaches player and begins orbiting at mid-range | Defines the archetype | Med |
| Fires during orbit after a timed delay | Without firing it is just an annoyance | Low |
| Orbits at constant radius, not drifting in/out | Predictable orbit lets players learn and lead shots | Med |
| Breaks orbit and closes in for attack burst | Must have a payoff moment, not orbit forever | Low |

**Differentiators**

| Behavior | Value | Complexity |
|----------|-------|------------|
| Randomizes clockwise vs. counter-clockwise orbit | Removes exploitable repetition | Low (random sign on angular velocity) |
| Varies orbit radius per instance (220–350px) | Multiple flankers don't all sit on the same ring | Low (randomized on spawn) |
| Plays attack burst then re-enters orbit | Creates a "dance" rhythm the player learns to punish | Low |
| Evades (dodges perpendicular) when player shoots | Feels reactive and alive | Med (requires detecting incoming projectiles via Area2D) |

**Anti-Features**

| Anti-Feature | Why Avoid |
|--------------|-----------|
| Orbit that never breaks | Player will just wait; no payoff |
| Firing constantly during orbit | Orbit becomes indistinguishable from Beeliner |

**State Transitions (recommended)**

```
SEEKING → LURKING:   within orbit entry range (e.g. 400px)
LURKING → FIGHTING:  orbit timer expires (e.g. 3–5s) OR player health < threshold
FIGHTING → LURKING:  attack burst complete (return to orbit)
LURKING → EVADING:   incoming projectile detected within evasion radius (optional, v2.1)
```

**Implementation note:** Orbit via angular velocity applied each `_physics_process`: compute tangential direction perpendicular to player-to-enemy vector, apply force. Radius maintained by a spring-like correction force (seek toward orbit radius, flee from inside it).

**Build order position:** Build second. Reuses Beeliner's base class and fire logic. Adds only the `lurking` (orbit) state — which is the first state requiring non-trivial steering math.

---

### Sniper

**Archetype:** Ranged / Retreater — high damage, slow shots, avoids close contact

**Core role:** Forces the player to close distance aggressively rather than staying still. Changes the combat tempo entirely. The slow, visible projectile rewards skilled evasion and punishes standing still.

**States used:** `seeking` (approach to preferred range) → `fighting` → `fleeing` (when player is too close)

**Table Stakes**

| Behavior | Why Required | Complexity |
|----------|--------------|------------|
| Maintains preferred engagement distance from player | Defines the archetype | Low–Med |
| Fires slow, high-damage projectile | The core threat that makes ranged play dangerous | Low (bullet with low velocity, high damage stat) |
| Flees when player enters minimum range | Without flee, it becomes a slow Beeliner | Low |
| Telegraphs shot with a visible charge-up delay | Slow projectile needs visual warning so evasion is possible | Low (timer before fire + visual effect) |

**Differentiators**

| Behavior | Value | Complexity |
|----------|-------|------------|
| Aims ahead of player's position (predictive targeting) | Rewards player dodging skill; not hitscan so misses are possible | Med (predict target pos = current_pos + velocity * time_to_impact) |
| Repositions laterally to maintain line of sight | Adds dynamic feel; doesn't just back-pedal in a straight line | Med |
| Fires a second "warning shot" at lower damage to bait dodges | Advanced — creates mind-game counterplay | High (save for v2.1) |
| Panics and fires rapidly when in flee state | Desperate fire pattern reads emotionally as "cornered" | Low |

**Anti-Features**

| Anti-Feature | Why Avoid |
|--------------|-----------|
| Hitscan (instant hit) shots | Removes player agency; impossible to dodge |
| Aggressive close-range attacks | Undermines the retreat identity |
| Same bullet speed as other enemies | Sniper shots must be visually distinct — slow and large |

**State Transitions (recommended)**

```
SEEKING → FIGHTING:  player within preferred range (e.g. 400–700px band)
FIGHTING → SEEKING:  player drifts outside max range (> 700px) — re-approach
FIGHTING → FLEEING:  player enters minimum range (< 250px)
FLEEING → FIGHTING:  distance restored to preferred range
```

**Bullet design:** Large/visible sprite, slow velocity (e.g. 200 px/s vs. minigun 800 px/s), high damage (e.g. 40 per hit). Travel time gives player ~1s to dodge from 200px.

**Build order position:** Build third. Flee state is new infrastructure. Predictive targeting is the only genuinely new steering calculation. Otherwise reuses fire logic.

---

### Swarmer

**Archetype:** Mob / Pack — individually trivial, dangerous in groups

**Core role:** Creates panic through numbers and attack angles the player cannot defend simultaneously. Solo swarmers are a non-threat by design; three or more become dangerous. Teaches the player to prioritize and use area-effect weapons.

**States used:** `seeking` → `fighting` → optional `evading` (from heavier weapons)

**States NOT used:** `lurking`, `fleeing` (swarmers do not retreat; they press until dead)

**Table Stakes**

| Behavior | Why Required | Complexity |
|----------|--------------|------------|
| Very low health — dies in 1–2 hits | Justifies spawning in groups | Low (tuning) |
| Low individual damage | Solo swarmer must feel manageable | Low (tuning) |
| Attacks from multiple approach angles | Core group mechanic; needs spawn formation logic | Med |
| Fast movement | Makes them hard to track individually | Low (tuning) |
| Groups approach together (proximity-aware) | Without this they are just fast Beeliners | Med |

**Differentiators**

| Behavior | Value | Complexity |
|----------|-------|------------|
| Nearest-neighbor cohesion: slow slightly when outrunning group | Makes the swarm feel like a coordinated organism | Med |
| Erratic jitter movement (small random force each frame) | Individual paths are unpredictable; hard to lead-aim | Low |
| Sound design: more swarmers = more audio layers | Escalating audio builds dread | Low (existing RandomAudioPlayer) |
| Split-fire: different swarmers fire from different angles | With 4+ swarmers, safe angles don't exist | Low (each fires independently, geometry does the work) |

**Anti-Features**

| Anti-Feature | Why Avoid |
|--------------|-----------|
| Boids/full flocking (alignment, separation, cohesion) | Out of scope per PROJECT.md; too complex for v2.0 |
| High individual health | Destroys the "satisfying to kill" feel of clearing a swarm |
| Centralized leader unit | Too much coordination complexity; save for v3.0 |

**Group awareness implementation (v2.0 scope):** Each swarmer independently steers toward player. The "group feel" comes from: (a) spawn formation (spawn in a cluster 50–100px apart), (b) partial proximity slow (if within 80px of another swarmer, reduce thrust 30%), (c) independent random offset to aim direction (±15 degrees). No shared state required — emergence from simple rules. True Boids deferred to v2.1.

**State Transitions (recommended)**

```
SEEKING → FIGHTING:  within firing range (150px — closer than other types)
FIGHTING → SEEKING:  player exits range
```

**Build order position:** Build fourth. No new states beyond what Beeliner established. Complexity is in the spawn formation logic (wave spawner must place them in clusters) and the proximity-slow mechanic. The wave spawner needs cluster-spawn support before Swarmer waves feel right.

---

### Suicider

**Archetype:** Kamikaze / Charger — no weapons, explodes on contact

**Core role:** Creates a different threat category — you cannot shoot at it slowly. It demands immediate evasive action or burst damage to kill before contact. Teaches the player that some threats require priority response.

**States used:** `seeking` (immediate, no hesitation) → contact triggers explosion

**States NOT used:** `fighting`, `lurking`, `fleeing` — Suicider has no firing state

**Table Stakes**

| Behavior | Why Required | Complexity |
|----------|--------------|------------|
| Charges directly at player at high speed | Defines the archetype entirely | Low |
| Explodes on player contact dealing large damage | The payoff — death must hurt | Low (trigger `Explosion` on `body_entered`) |
| Also explodes when health reaches zero (from being shot) | Shooting it to death still detonates it; rewards pre-emptive engagement | Low |
| Explosion radius hurts nearby enemies too | Creates interesting tactical choices (kite into other enemies) | Low (existing Explosion component with Area2D) |
| Visual warning: turns red / flashes as it accelerates | Player must read "this is coming for me" at a glance | Low |

**Differentiators**

| Behavior | Value | Complexity |
|----------|-------|------------|
| Slight tracking lag: re-evaluates direction every 0.3s rather than every frame | Gives player a tiny window to break line of sight | Low |
| Screams on detection (audio cue) | Audio-visual warning combo; pure tension | Low (RandomAudioPlayer) |
| Variable speed: starts medium, accelerates over 2s to max speed | Ramp-up creates dread; player sees it accelerate toward them | Low |
| Detonates mid-air if killed at distance (no contact explosion) | Skilled players can destroy it safely by leading shots | Low |

**Anti-Features**

| Anti-Feature | Why Avoid |
|--------------|-----------|
| Perfect tracking (pixel-perfect prediction) | Impossible to dodge; removes player agency |
| Tiny explosion radius | Removes consequence of failure; must punish near-misses |
| High health | Should be killable with 3–5 hits; it is fast, health shouldn't stack on top |

**Explosion parameters (starting values)**

- Contact damage: 80 HP (very high — near one-shot for player)
- Explosion radius: 200px
- Explosion falloff: linear (existing Explosion component supports this)
- Health: very low (30 HP) — designed to be killable but requires commitment

**Build order position:** Build fifth/last. Simplest state machine of all five (one state: seek). New piece is the on-death / on-contact explosion trigger — but the `Explosion` component already exists. Integration is straightforward.

---

## Anti-Features (Project-Wide)

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Pathfinding (NavigationAgent2D) | Overkill for open-space shooter; adds node overhead with no terrain benefit | Steering forces: seek/flee/orbit via `apply_central_force` |
| Shared mutable state between enemies | Creates subtle bugs when enemies reference each other across frames | Each enemy is fully self-contained; group effects emerge from local rules |
| Inventory/MountableWeapon layer for enemy fire | Confirmed out of scope in PROJECT.md; increases coupling | Simplified fire: instantiate bullet scene, apply velocity impulse, done |
| True Boids flocking | Explicitly out of scope (PROJECT.md); complex, diminishing returns for v2.0 | Proximity-slow + cluster spawning approximates the feel |
| Health bars above enemies | Slows down arcade pace; adds UI complexity | Color modulation on damage (e.g., red flash) is sufficient |
| Healing / respawning enemies | Frustrating in arcade shooters; breaks "kill it and it's dead" contract | Enemies do not regenerate health |

---

## Feature Dependencies

```
EnemyShip base class (abstract)
    └── State machine skeleton (states: idling, seeking, fighting, fleeing, lurking)
        └── Beeliner          [needs: seek, fight]
            └── Flanker       [needs: lurking/orbit — new steering]
                └── Sniper    [needs: flee — new state logic]
                    └── Swarmer [needs: cluster spawn from wave system]
                        └── Suicider [needs: on-contact explosion integration]

Simplified fire logic (independent module)
    └── All types except Suicider

Wave spawner
    └── All enemy types (Swarmer specifically needs cluster-spawn mode)
```

---

## Shared Infrastructure Needed Before Any Enemy Works

These must exist before the first enemy type (Beeliner) is playable:

1. `EnemyShip` base class with virtual `_tick_state()` and state enum
2. Simplified `fire(direction: Vector2)` method on `EnemyShip` (bullet scene + impulse)
3. `_physics_process` loop calling `_tick_state()` each frame
4. Wave spawner: basic instantiate-at-position, queue up wave definitions

---

## MVP Recommendation

Prioritize in this order:

1. Shared infrastructure (EnemyShip base, state machine, simplified fire, wave spawner)
2. **Beeliner** — validates the entire pipeline; simplest enemy
3. **Sniper** — introduces flee state; changes combat tempo fundamentally
4. **Flanker** — introduces orbit; most mechanically interesting to fight
5. **Swarmer** — requires cluster spawn support; needs wave spawner mature enough to place groups
6. **Suicider** — simplest logic, but save last so explosion integration is clean

Defer:
- Predictive aiming for Sniper (v2.1): complex math, low necessity for first pass
- Evasion / incoming-projectile detection for Flanker (v2.1): requires projectile tracking
- True Boids for Swarmer (v3.0): explicitly out of scope in PROJECT.md

---

## Wave Spawning — What Makes It Feel Good

| Property | Why It Matters | Implementation Note |
|----------|----------------|---------------------|
| 8–12s breathing room between waves | Prevents fatigue; players reposition and heal | Timer-based gap after last enemy in wave dies |
| Wave announcement (counter + audio sting) | Tension and anticipation before first spawn | HUD text + audio cue 3s before spawn |
| Spawn off-screen at random edge positions | Enemies appear from "out there" — maintains space theme | Spawn 200px beyond viewport edge |
| Escalating composition, not just more enemies | Wave 1: Beeliners only. Wave 3: Beeliners + Snipers. Wave 5: add Swarmers | Wave definition as data (Array of enemy type + count pairs) |
| First enemy of a new type introduced alone or in a small group | Player learns the new enemy without being overwhelmed | Structure first appearance in wave data, not random |
| Cluster spawning for Swarmers | Swarmers arriving spread apart lose their group identity | `spawn_cluster(type, count, center, radius)` helper on spawner |
| Optional: bonus wave (all-Suiciders) | High-intensity curveball; keeps late-game surprising | Flag in wave definition data |

---

## Sources

- [Enemy design — The Level Design Book](https://book.leveldesignbook.com/process/combat/enemy) — HIGH confidence, comprehensive archetype design principles
- [Roles of Monsters: The Swarmer — Rather Ghastly Gaming](https://ghastlygaming.wordpress.com/2012/09/13/roles-of-monsters-the-swarmer/) — MEDIUM confidence, design analysis
- [Battle Circle AI — Tutsplus/Envato](https://code.tutsplus.com/battle-circle-ai-let-your-player-feel-like-theyre-fighting-lots-of-enemies--gamedev-13535t) — HIGH confidence, implementation-level orbit AI
- [Dynamic Maneuvers: Circular Movement for Space Shooter Enemies — Medium](https://medium.com/@victormct/dynamic-maneuvers-implementing-circular-movement-for-enemies-in-a-space-shooter-game-c0085570c5c1) — MEDIUM confidence
- [Space Shooter Aggressive Enemy Type: Ramming — Medium](https://medium.com/@victormct/space-shooter-aggressive-enemy-type-ramming-the-player-b1a62428d399) — MEDIUM confidence, kamikaze-specific implementation
- [Unleashing Chaos: Mastering Enemy Waves — Medium](https://medium.com/@victormct/unleashing-chaos-mastering-enemy-waves-9be16f92e673) — MEDIUM confidence, wave design principles
- [Keys to Rational Enemy Design — GDKeys](https://gdkeys.com/keys-to-rational-enemy-design/) — HIGH confidence, design philosophy
- [Enemy NPC Design Patterns in Shooter Games — ACM DL](https://dl.acm.org/doi/10.1145/2427116.2427122) — HIGH confidence (academic)
- [Steering Behaviors Godot 4 — GitHub konbel](https://github.com/konbel/steering-behaviors-godot-4) — HIGH confidence, Godot-specific seek/flee implementation
