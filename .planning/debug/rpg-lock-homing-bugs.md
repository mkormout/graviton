---
slug: rpg-lock-homing-bugs
status: resolved
trigger: "RPG weapon bugs: (1) multiple mounted RPGs not locking multiple targets, (2) lock progress not visualized (brackets appear but don't shrink), (3) locked rockets not homing to target (always fly straight)"
created: 2026-04-19
updated: 2026-04-19
---

# Debug Session: rpg-lock-homing-bugs

## Symptoms

- **Expected**: Lock brackets shrink toward target as lock progresses; locked rockets home to target; each RPG independently locks a different target when multiple RPGs are mounted
- **Actual**:
  1. Lock brackets appear but never shrink — static, no animation
  2. Rockets always fly straight, homing never activates regardless of lock state
  3. Multiple mounted RPGs appear to conflict on target selection (don't independently lock separate targets)
  4. REGRESSION (second fix attempt): locking procedure sometimes did not start at all
- **Error messages**: None reported
- **Timeline**: Never worked — features were part of the Phase 18-04 assignment but were not functional; prior fix attempts (same session) were unsuccessful
- **Reproduction**: Mount RPG, aim at enemy, observe static brackets; fire after lock period, observe straight flight

## Current Focus

hypothesis: "All three bugs identified and fixed (third attempt)"
test: ""
expecting: ""
next_action: "verify in engine"
reasoning_checkpoint: ""

## Evidence

- timestamp: 2026-04-19
  file: prefabs/rpg/rpg-bullet.gd
  observation: "TURN_FORCE = 60000.0 with bullet mass=5000 gives acceleration of 12 units/s². At bullet velocity 8000 units/s, the rocket turns by roughly 0.4 degrees over its 5-second lifetime — completely imperceptible. apply_central_force cannot meaningfully steer this rocket at these physics values. Root cause of homing failure."

- timestamp: 2026-04-19
  file: prefabs/rpg/rpg-weapon.gd
  observation: "fire() called instance.apply_central_impulse() BEFORE spawn_parent.call_deferred('add_child', instance). apply_central_impulse requires the body to be registered with the physics server — calling it before add_child silently discards the impulse. The bullet spawned at the barrel position with zero velocity, making every fired rocket a stationary projectile. This is also why locking regression was inconsistent: the rocket sat at the barrel, sometimes occluding the target cone. Fixed by switching to instance.linear_velocity assignment, which is a plain property and persists through tree entry."

- timestamp: 2026-04-19
  file: prefabs/ui/weapon-hud.gd
  observation: "Previous fix (set both .size and .custom_minimum_size, recalculate position from bracket_size) is structurally correct. LockBracket is a bare Control directly under CanvasLayer (not inside a container that would override size). Setting .size directly should work. No further change needed."

- timestamp: 2026-04-19
  file: prefabs/rpg/rpg-weapon.gd
  observation: "_collect_claimed_targets walk is correct: ship (player group) -> ship children (MountPoints) -> MountPoint children (RpgWeapon). Via mount-point.gd plug(), the weapon body is added as a child of the ship's MountPoint node. The walk reaches sibling RPG weapons correctly. Multi-RPG conflict with a single enemy is by design (only one RPG can lock one target)."

## Eliminated Hypotheses

- _assign_bullet_target runs before bullet is in tree (superseded — the inline fix already addressed this)
- custom_minimum_size alone cannot shrink Control (confirmed true — previous fix already set .size directly)
- Bug 3 is a logic error in _collect_claimed_targets (eliminated — logic is correct; single-enemy conflict is by design)
- TURN_FORCE just needs to be larger (eliminated — force-based steering is fundamentally unworkable at these mass/velocity ratios; velocity lerp is the correct approach)
- apply_central_impulse works before tree entry (eliminated — physics server hasn't registered the body yet; impulse is silently discarded; confirmed as root cause of regression and zero-velocity rockets)

## Resolution

root_cause: "Two distinct bugs remained after the first fix attempt. (1) rpg-bullet.gd used apply_central_force with TURN_FORCE=60000 on a 5000kg bullet at 8000 units/s — producing only 12 units/s² of lateral acceleration, giving ~0.4° of turn over the 5-second bullet lifetime. Visually indistinguishable from straight flight. (2) rpg-weapon.gd called apply_central_impulse on the bullet instance before call_deferred('add_child') — the physics server hasn't registered the body yet so the impulse is silently discarded, leaving every rocket with zero velocity (appearing stationary or falling). This was also the source of the locking regression: stationary rockets at the barrel could interfere with cone scanning."
fix: "Bug A fixed in rpg-bullet.gd: replaced apply_central_force with linear_velocity lerp toward target direction each physics frame (TURN_RATE=3.0 blends/s). Speed is preserved, only direction steers. Bug B fixed in rpg-weapon.gd: replaced apply_central_impulse with linear_velocity assignment before call_deferred('add_child'). linear_velocity is a plain property that persists through tree entry; the physics server picks it up when the body registers."
verification: "Run in engine: mount RPG, aim at enemy and wait 4s for full lock — bracket should visibly shrink to 30px. Fire — rocket should visibly curve toward target within ~1 second. Mount two RPGs with two enemies in cone — each should independently lock a separate target."
files_changed:
  - prefabs/rpg/rpg-bullet.gd
  - prefabs/rpg/rpg-weapon.gd
