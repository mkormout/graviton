# Performance — Wave 2 Optimization Notes

Investigation log from the 2026-04-25 perf debug session that took wave 2 (250 enemies) from **2-3 FPS to 30+ FPS minimum**. Kept here so future-you remembers the failure modes when adding more enemies, more lights, or denser physics.

## TL;DR

The dominant cost was **Godot's 2D physics broadphase**, amplified by a **spiral-of-death** from the default fixed-timestep behavior. Two fixes accounted for almost the entire FPS recovery:

| # | Fix | FPS impact | Commit |
|---|---|---|---|
| 1 | Cap `max_physics_steps_per_frame=2` (default 8) | 2-3 → 8 | `ed72709` |
| 2 | Disable `DetectionArea` `CollisionShape2D` after enemy engages | 10 → 30+ | `2435288` |

Everything else was either a real bug fix (kept), a polish improvement, or a dead-end diagnostic (reverted).

---

## Symptom

- Wave 1 (50 enemies): smooth 60 FPS.
- Wave 2 (250 enemies): **2-3 FPS**, unplayable.
- Slowdown persisted even when most enemies were off-screen.
- FPS recovered as enemy count dropped, threshold visibly around 100 live enemies.

## What didn't help (and why)

These were tried first based on hypotheses without profiler data. Most were reverted or kept only because they're independently right.

| Hypothesis | Reality |
|---|---|
| `queue_redraw()` per `_physics_process` (15K dirty-marks/s) | Real waste, kept (`4005bb4`) — but trivial vs the real cost |
| Infinite `call_deferred` loop in orphaned pooled explosions | Real bug, kept (`885e9ce`) — but not the dominant FPS killer |
| 250 GemLight infinite Tweens + 250 BodyGlow lights | Reverted (`cd33b71`) — disabling them had ~zero effect |
| Enemy-vs-enemy physical collisions (`collision_mask: 3 → 2`) | Marginal — 8 → 10 FPS only |

The pattern: **without profiler data we burned multiple iterations on plausible-but-wrong theories**. Lesson: use the profiler first.

## What the profiler actually showed

Godot Editor → Debugger → Profiler + Monitors during a wave-2 stall:

```
Frame Time:        433 ms (~2.3 FPS)
Physics 2D:        279.63 ms  ← 65% of frame
Process Time:       12.17 ms
```

Inside Physics 2D, the same step ran **5+ times in one frame** (visible as repeated `Setup Constraints` / `Solve Constraints` rows). Each step ~35 ms.

```
Active Objects:           420
Collision Pairs:        3,148  (peak: 113,071)
Islands:                3,112
```

In Script Functions, `Body.die` was 87.83 ms / 151 calls in the peak frame (death cascade from explosion shockwaves).

## Root causes — ranked by impact

### 1. Physics spiral-of-death

Godot's default `physics/common/max_physics_steps_per_frame = 8`. When a single physics step exceeds the 16.66 ms budget (60 Hz target), the engine compensates by running up to 8 catch-up steps next frame. If physics is genuinely overloaded, each frame buries the next, and the game spirals into single-digit FPS.

**Fix:** Cap at 2 in `project.godot:33`.
```ini
[physics]
common/max_physics_steps_per_frame=2
```

When physics is overloaded, the game now runs in slow-motion instead of dragging the entire renderer down. FPS floor lifted from 2-3 to 8.

**Gotcha:** I initially typed `physics_max_steps_per_frame` (Godot silently ignored it) before correcting to `max_physics_steps_per_frame`. Always verify the setting actually loaded.

### 2. DetectionArea AABB pile-up

Each enemy's `DetectionArea` had a `CircleShape2D` of **radius 10,000** in its `.tscn`. With 250 enemies, every detection AABB overlapped every other enemy's AABB, producing **113,071 broadphase collision pairs at peak** during wave-2 spawn.

The scripted `@export var detection_radius = 800.0` on `EnemyShip` was unused — a misleading red herring during diagnosis.

**Fix:** Disable each enemy's `DetectionShape` `CollisionShape2D` once it transitions out of IDLING. Done centrally in `EnemyShip._change_state()` so all 5 enemy subclasses inherit it.

Critical detail: setting `Area2D.monitoring = false` does **not** remove the shape from broadphase — it only stops signal emission. The first attempt at this fix did exactly that and FPS went from 25 back to 7. The real fix is to set `disabled = true` on the inner `CollisionShape2D`.

```gdscript
if old_state == State.IDLING and detection_area:
    for connection in detection_area.body_exited.get_connections():
        detection_area.body_exited.disconnect(connection.callable)
    detection_area.set_deferred("monitoring", false)
    var shape := detection_area.get_node_or_null("DetectionShape") as CollisionShape2D
    if shape:
        shape.set_deferred("disabled", true)
```

Two more details worth remembering:

- **Disconnect `body_exited` before disabling.** Disabling a shape causes Godot to fire `body_exited` for any bodies still overlapping. Swarmer/Sniper/Flanker had `body_exited` handlers that re-IDLED on lost target → on engage, the disable would immediately undo the state change. Visible as Swarmer freezing in place. Fix: disconnect first (`1268cab`).
- **`set_deferred` is mandatory.** This code runs from a physics callback (`body_entered` → `_change_state`). Mutating physics state synchronously inside a physics callback is unsafe.

Trade-off: enemies stay committed once aware. The `body_exited`-driven "give up if player escapes" behavior is permanently gone for these three types. Acceptable — it makes them more menacing, not less.

### 3. Light cap saturation (cosmetic but visible)

`limits/opengl/max_renderable_lights=128` was too low for wave 2. With 250 enemies × (`GemLight` + `BodyGlow`) plus bullets, explosions, and propeller lights, visible-light count routinely exceeded the cap. Each new explosion light forced Godot to deactivate the lowest-priority existing light → visible flicker correlated with bullet-hit sounds.

**Fix:** `limits/opengl/max_renderable_lights=512` in `project.godot:41`. Modern GPUs handle this fine for 2D. Bump to 1024 if it ever recurs.

### 4. Single-frame spawn stutter

`WaveManager.trigger_wave()` instantiated and `add_child`'d all 250 wave-2 enemies in one frame. That's the source of the 113,071 collision-pair peak.

**Fix:** Stagger spawns across frames using `await get_tree().process_frame` between batches of 10 (exposed as `@export var spawn_batch_size`). Wave 2 spawn now spreads over ~25 frames (~0.4s) instead of 1 frame.

Note: making `trigger_wave()` `async` works without changing callers. They get a `Signal` return value instead of `void` and don't need to `await` it.

## What was a real bug found along the way (kept)

These weren't the dominant FPS issue but are independently correct:

- **`spawn_parent` propagation in enemy bullets** (`885e9ce`). Beeliner/Flanker/Sniper/Swarmer fire pooled bullets whose death scene is `minigun-bullet-explosion.tscn` (also pooled). On bullet death, `Body.die()` acquires the explosion from pool but couldn't add it to the tree because the bullet's `spawn_parent` was null. The explosion then re-deferred `_on_reacquired` forever via `call_deferred`, saturating the SceneTree deferred queue and amplifying every other cost. Fix is one line per enemy fire path: `bullet.spawn_parent = spawn_parent`.
- **Defensive max-retry guard in `Explosion._on_reacquired`** (`885e9ce`). Caps retries at 4 and releases back to pool with a `push_warning`. Catches future regressions of the orphan-explosion class loudly instead of silently melting the deferred queue.
- **Removed unconditional `queue_redraw()` from `EnemyShip._physics_process`** (`4005bb4`). Saved ~15,000 CanvasItem dirty-marks/sec at 250 enemies. Both legitimate triggers (`set_debug_visible`, `_change_state`) already call it on transitions.

## Lessons

1. **Profile first, hypothesize second.** Multiple iterations were burned on theories that the profiler ruled out in five minutes.
2. **Watch for spiral-of-death.** Fixed-timestep physics with default `max_physics_steps_per_frame` masks a 2× overload as a 16× overload. Cap it.
3. **`monitoring = false` is not "remove from broadphase".** It only stops signal emission. To remove the AABB, disable the inner `CollisionShape2D`.
4. **Disabling a shape fires `body_exited`.** Disconnect handlers first if your subclass code relies on that signal for state.
5. **Setting names matter — verify they load.** Godot silently ignored a typo'd setting for an entire iteration.
6. **Per-enemy `_physics_process` AI was never the issue.** All 250 swarmers running their state machine cost 0.81 ms / 400 calls — fine. The cost was always in physics broadphase.

## Where to look first if perf regresses again

1. Open Godot profiler, look at `Physics 2D` total. If it's >50% of frame time, broadphase is the problem.
2. In Monitors, watch `Collision Pairs`. Sudden spike = bad. Steady-state high = AABB/area sizing problem.
3. If `Setup Constraints` rows repeat 5+ times per frame: spiral-of-death, check `max_physics_steps_per_frame` is still 2.
4. If `Body.die` shows up high: a death cascade is happening. Look for explosion shockwaves chain-killing enemies (rare).
5. If light flicker recurs: bump `max_renderable_lights` again.

## Reference commits

```
ed72709  fix(perf): correct setting name to max_physics_steps_per_frame
8eba294  fix(perf): drop Ship layer from enemy collision_mask (3 → 2)
2435288  fix(perf): disable DetectionArea CollisionShape2D, not just Area2D.monitoring
1268cab  fix(perf): disconnect body_exited before disabling DetectionArea shape
9dcf1fb  fix(perf): raise max_renderable_lights to 512; stagger wave spawns
885e9ce  fix(perf): stop infinite call_deferred loop from orphaned pooled enemy-bullet explosions
4005bb4  perf(260425-eli): remove unconditional queue_redraw() from EnemyShip._physics_process
```
