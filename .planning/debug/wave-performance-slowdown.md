---
slug: wave-performance-slowdown
status: root_cause_found_v2
trigger: |
  Performance regression: First wave runs smoothly with no performance issues,
  but the second wave is incredibly slow. Analyze what's causing the slowdown
  between waves and suggest a change based on the analysis.
created: 2026-04-25
updated: 2026-04-25
---

## NEW ROOT CAUSE (2026-04-25, after fix #1 had no effect)

**Real cause: infinite `call_deferred` loop in `Explosion._on_reacquired()` from orphaned pooled explosions.**

Trace:
1. Enemy bullet types (beeliner, flanker, sniper, swarmer) all reference `res://prefabs/minigun/minigun-bullet-explosion.tscn` as `death`.
2. That scene IS pooled (PoolManager._POOL_CONFIGS line 38).
3. Enemy bullet spawn code did NOT propagate `spawn_parent` to the bullet.
4. Bullet dies → `Body.die()` runs → `PoolManager.acquire(death)` returns a pooled explosion.
5. ScenePool.acquire calls `_pool_reset()` on the explosion → `call_deferred("_on_reacquired")`.
6. Body.die() then sets `node.spawn_parent = bullet.spawn_parent` (NULL) → fails the `if spawn_parent` branch → push_warning, never adds to tree.
7. Next deferred frame: `_on_reacquired` runs → `is_inside_tree()` false → `call_deferred("_on_reacquired")` — **infinite loop, growing the deferred queue every frame**.
8. Wave 1 saturates the deferred queue with hundreds of orphan-explosion `_on_reacquired` calls. By wave 2 the engine spends nearly all CPU time processing them → 2-3 FPS.

**Fix:** propagate `spawn_parent = spawn_parent` in beeliner/flanker/sniper/swarmer bullet spawn code (already present in user's working tree, uncommitted) + defensive max-retry guard in `Explosion._on_reacquired` so any future similar bug fails loudly instead of catastrophically.

The original "Compounding factors 1-5" report was correct about secondary inefficiencies but missed the dominant primary cause.

---

# Debug Session: wave-performance-slowdown

## Symptoms

- **Expected behavior:** Both waves should run smoothly at the target frame rate; the second wave should perform similarly to the first.
- **Actual behavior:** First wave is fluent with no performance issues; second wave is "incredibly slow" — significant frame rate drop / lag.
- **Error messages:** None reported (performance issue, not a crash).
- **Timeline:** Recent — observed in current build (Phase 16 just completed; recent quick task on 2026-04-25 added SHIFT+D enemy-sprite toggle). User has not specified whether this regressed recently or has always existed.
- **Reproduction:** Start the game, play through the first wave, observe smooth performance; second wave begins → slowdown appears.

## Current Focus

```yaml
hypothesis: Wave 2 spawns 5x as many enemies as Wave 1 (250 vs 50), causing quadratic-scaling per-physics-frame work (queue_redraw per enemy, _draw() arc calls, print() per state change, load() per enemy spawn) plus a ShaderMaterial per enemy instance that creates a new GPU pipeline compilation.
test: Confirmed by reading world.gd wave definitions and all enemy _physics_process / _setup_sprite implementations.
expecting: Root cause confirmed — multiple compounding factors, primary one being the 5x enemy count amplifying all per-enemy work.
next_action: report root cause
reasoning_checkpoint: All five enemy types examined. WaveManager, ScenePool, PoolManager, world.gd, body.gd all examined.
tdd_checkpoint: null
```

## Hypotheses to Investigate

Initial candidates (the debugger will refine based on evidence):

1. **Object accumulation across waves** — wave 1 enemies/bullets/debris not freed before wave 2 starts; per-frame physics/AI/processing scales with total live objects.
2. **Pool growth without reuse** — bullet/enemy pools grow on demand but objects never return to pool; pool size doubles wave-over-wave.
3. **Signal/listener leak** — connections accumulate across waves, causing duplicate handlers to fire each frame.
4. **Particle/debris persistence** — explosions, asteroid fragments, or VFX from wave 1 still alive when wave 2 spawns.
5. **Recent regression** — the SHIFT+D debug toggle commit (cba9d3b) or the deferred `set_debug_visible` fix (cc1a429) introduced per-frame work that scales with enemy count.

## Evidence

- timestamp: 2026-04-25T00:00:00Z
  type: code_read
  file: world.gd
  lines: 98-116
  finding: |
    Wave 1 ("Performance test 1") spawns 50 enemies (10 of each of 5 types).
    Wave 2 ("Performance test 2") spawns 250 enemies (50 of each of 5 types).
    This is a deliberate 5x jump. All per-enemy costs scale linearly with count;
    quadratic interactions (swarmer cohesion/separation O(n^2), physics broadphase)
    scale worse.

- timestamp: 2026-04-25T00:00:00Z
  type: code_read
  file: components/enemy-ship.gd
  lines: 80-85
  finding: |
    EnemyShip._physics_process calls queue_redraw() unconditionally every physics
    frame regardless of debug mode. With 250 enemies active, this is 250
    queue_redraw() calls per physics tick (60/s = 15,000 redraw requests/s), each
    of which triggers _draw() to run on EnemyShip.

- timestamp: 2026-04-25T00:00:00Z
  type: code_read
  file: components/enemy-ship.gd
  lines: 113-138
  finding: |
    EnemyShip._draw() executes unconditionally but has an early exit when Shape
    is not visible (i.e. sprite mode — the normal mode). The early exit at line
    117-118 does avoid the arc/text drawing work. However, queue_redraw() itself
    still forces a CanvasItem dirty-mark and eventual canvas re-sort on all 250
    nodes every physics frame.

- timestamp: 2026-04-25T00:00:00Z
  type: code_read
  file: components/beeliner.gd, flanker.gd, swarmer.gd, sniper.gd, suicider.gd
  lines: _setup_sprite() in each file
  finding: |
    Every enemy type calls load("res://ships_assests.png") and
    load("res://components/enemy-sprite.gdshader") inside _setup_sprite() which
    runs in _ready(). Each of the 250 wave-2 enemies calls load() twice at spawn
    time. While Godot's ResourceLoader caches these (so the texture itself is not
    re-read from disk after the first load), each call to load() acquires the
    cache lock and does a hash lookup. More critically: each enemy creates a new
    ShaderMaterial instance via ShaderMaterial.new() and assigns the shader to it.
    ShaderMaterial instances are NOT shared — each of 250 enemies owns a unique
    ShaderMaterial, causing 250 separate GPU shader variant compilations/uploads
    on first use. This is a spawn-time spike that can stall the main thread.

- timestamp: 2026-04-25T00:00:00Z
  type: code_read
  file: components/beeliner.gd
  lines: 97, 113
  finding: |
    Beeliner._fire() contains two print() calls per shot: one at fire entry and
    one per bullet spawned. Beeliner fires 3 bullets per shot at 1.5s intervals.
    With 50 Beeliners active this is ~100 print() calls per fire cycle, each
    writing to the Godot output bus which is synchronous. Flanker and Sniper also
    print per bullet. print() in Godot 4 is not a no-op — it acquires a mutex
    and formats strings on the main thread.

- timestamp: 2026-04-25T00:00:00Z
  type: code_read
  file: components/enemy-ship.gd
  lines: 106
  finding: |
    EnemyShip._change_state() prints on every state transition for all 250
    enemies, and each subclass _enter_state also prints. With 250 enemies
    transitioning from IDLING -> SEEKING as they detect the player shortly after
    spawn, this produces 500+ print() calls in a short window.

- timestamp: 2026-04-25T00:00:00Z
  type: code_read
  file: components/swarmer.gd
  lines: 107-162
  finding: |
    Swarmer._apply_separation() and _apply_cohesion() iterate _nearby_swarmers
    every physics frame. _nearby_swarmers is populated by CohesionArea body_entered
    signals. With 50 Swarmers close together, each Swarmer iterates up to 49
    neighbors every physics tick. This is O(n^2) work per physics frame: 50*49/2
    = 1,225 distance calculations every tick (3,600 with separation + cohesion
    both running). At 60 Hz this is ~73,500 distance+force ops/second from
    Swarmers alone in wave 2 vs ~2,940 in wave 1 (25x more, not just 5x, because
    n^2 scaling).

- timestamp: 2026-04-25T00:00:00Z
  type: code_read
  file: components/wave-manager.gd
  lines: 92-104
  finding: |
    WaveManager._spawn_enemy does NOT use a pool for enemies — each enemy is
    instantiate()d fresh. 250 enemies are instantiated synchronously in a tight
    for loop inside trigger_wave(). Godot's add_child() is not deferred here,
    so 250 add_child() calls happen in one frame, stalling the main thread.

- timestamp: 2026-04-25T00:00:00Z
  type: code_read
  file: components/scene-pool.gd, components/pool-manager.gd
  finding: |
    Bullet and explosion pooling look correct — objects acquire and release
    properly. No accumulation bug found in the pool. Enemies themselves are not
    pooled (WaveManager always calls enemy_scene.instantiate()), which is correct
    for enemies but means spawn-time cost is paid in full for all 250 wave-2
    enemies.

## Eliminated

- **Signal/listener leak across waves**: Not found. WaveManager connects
  tree_exiting before add_child, which is a single-fire signal; no accumulation.
  Bullet signals (body_entered) are per-instance and freed with the instance.

- **Object accumulation from wave 1**: WaveManager tracks _enemies_alive and
  trigger_wave() refuses to start if _enemies_alive > 0. Wave 2 only starts
  after all wave-1 enemies are dead and removed from the tree.

- **Pool accumulation**: ScenePool correctly releases to _free on release() and
  removes from gameplay tree. Pool growth warning fires if live count exceeds 2x
  initial, but this would not cause slowdown on its own.

- **SHIFT+D regression (cba9d3b / cc1a429)**: The queue_redraw() in
  _physics_process existed before this commit and the _draw() early-exit means
  it is nearly free when sprites are active. The SHIFT+D toggle itself is O(n)
  only when pressed, not per-frame.

## Resolution

**Root Cause (primary):** The "Performance test" wave configuration in world.gd
defines Wave 2 with 250 enemies versus Wave 1's 50. The 5x raw enemy count
amplifies every per-enemy per-frame cost, and the Swarmer cohesion/separation
algorithm is O(n^2) in nearby-swarmer count, causing a ~25x increase in physics
work for swarmers alone.

**Root Cause (compounding factors):**
1. Every enemy calls queue_redraw() unconditionally in _physics_process — 250
   canvas dirty-marks per physics tick even when nothing visual changed.
2. Every enemy creates a unique ShaderMaterial instance in _setup_sprite() —
   250 GPU shader pipeline compilations triggered at wave-2 spawn time.
3. print() calls inside _fire() and _enter_state() are synchronous and scale
   with enemy count and fire rate.
4. 250 enemy add_child() calls happen synchronously in one frame inside
   trigger_wave(), stalling frame rendering.

**Suggested Change:** See detailed recommendations in the ROOT CAUSE FOUND section below.
