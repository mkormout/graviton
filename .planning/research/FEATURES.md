# Feature Research

**Domain:** Godot 4 arcade space shooter — dynamic music, sprite sheets with fallbacks, in-game restart
**Researched:** 2026-04-16
**Confidence:** HIGH (Godot 4.6 official docs verified via Context7)

---

## Feature Landscape

### Game Restart

#### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Restart resets wave to Wave 1 | Standard arcade expectation — game starts fresh | LOW | WaveManager._current_wave_index = 0; _enemies_alive = 0; _wave_total = 0 |
| Restart resets score/kills/multiplier to 0 | Any leaderboard game resets stats on replay | LOW | ScoreManager.total_score, kill_count, wave_multiplier, combo_count all zeroed |
| Living enemies cleared before restart | Ghost enemies firing at newly-spawned player would be a bug | LOW | get_tree().get_nodes_in_group("enemy") loop → queue_free() each |
| Player health restored to max_health | Starting at 1 HP is not a restart | LOW | Body.health = Body.max_health; dying = false; linear_velocity = Vector2.ZERO |
| Death screen hides on restart | Obvious UX requirement | LOW | DeathScreen.visible = false |
| Combo timer cancelled | Audio pitch-scaling combo artifact from previous run | LOW | ScoreManager._combo_timer.stop(); combo_count = 0; emit combo_updated(0) |
| Player ship repositioned to (or near) origin | Edge-of-map start is disorienting | LOW | $ShipBFG23.global_position = Vector2.ZERO; linear_velocity = Vector2.ZERO |
| Wave HUD / Score HUD reset visually | Stale "x16" multiplier label persists without an explicit signal | LOW | Emit multiplier_changed(1) and score_changed(0, 0) after state reset |

#### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Restart WITHOUT get_tree().reload_current_scene() | Preserves audio continuity; avoids autoload side-effects; faster UX (no scene stutter) | MEDIUM | Manual state reset per system. reload_current_scene IS tempting as a one-liner — avoid it to preserve music playback and prevent duplicate Timer/AudioStreamPlayer children in ScoreManager |
| Smooth fade-to-black transition wrapping the reset | Brief fade-to-black then fade-in feels pro-polish | LOW | Tween CanvasLayer modulate.a 1.0→0.0 (0.3s), reset state, then 0.0→1.0 (0.3s) |
| Restart preserves leaderboard session | Name pre-fill still works; avoids ConfigFile disk re-read on hot path | LOW | Already handled naturally: _load_last_name() reads ConfigFile; ConfigFile data is on disk, not in-memory state |

#### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| get_tree().reload_current_scene() | Simple one-liner restart | Re-runs ScoreManager._ready() — creates duplicate Timer and AudioStreamPlayer nodes (memory leak risk); cuts audio mid-fade; causes frame stutter on scene reload | Manual reset: zero ScoreManager vars, reset WaveManager counters, kill enemy group nodes, restore player health |
| "Resume from last wave" checkpoint | Convenience for long runs | Contradicts arcade score-chase design; invalidates combo chain meaning; out of scope for v3.5 | Full restart only |
| Confirm dialog before restart | Prevents accidental restart | Adds friction in an arcade shooter where restart should feel snappy; leaderboard was already submitted at death screen step | Single "Restart" button with no confirmation |

---

### Dynamic Music System

#### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Background music plays on game start | Silent game feels unfinished | LOW | Single AudioStreamPlayer (non-positional) started in world._ready() or MusicManager autoload _ready() |
| Music loops without gap | Track cutting off mid-loop is jarring | LOW | Set loop = true on AudioStreamMP3/OGG resource in .import, or stream.loop = true; AudioStreamPlayer handles seamless loop |
| Volume sits under SFX in mix | Music at 0 dB drowns out combat sounds | LOW | music_player.volume_db = -12.0 (or named constant); SFX remain at default |
| Music does not stack on restart | Old player keeps playing when restart triggers a new one | LOW | Stop previous AudioStreamPlayer before starting new; guard with is_playing() check |

#### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Category-based selection (Ambient / Combat / High-Intensity) | Music reacts to wave escalation; players feel the tension curve | MEDIUM | Three arrays keyed by enum; threshold on WaveManager._current_wave_index (e.g., waves 1-5 = Ambient, 6-14 = Combat, 15-20 = High-Intensity); connect to wave_started or wave_completed signal |
| Auto-scan /music folder at startup | New tracks drop in without code changes; future-proof | MEDIUM | DirAccess.open("res://music/").get_files() → filter by .mp3/.ogg/.wav extension → ResourceLoader.load() each; categorize by filename prefix convention (e.g., "ambient_", "combat_", "intense_") |
| Smooth A/B cross-fade on category transition | Abrupt cut is amateurish; cross-fade is the expected behavior in games post-2010 | MEDIUM | Two AudioStreamPlayers (player_a, player_b); Tween volume_db from -80→0 on incoming, 0→-80 on outgoing over 1.5s; swap active reference after fade completes |
| Filename-prefix category detection | No metadata .cfg file needed; drop "combat_03.mp3" and it works | LOW | Parse filename prefix before first underscore character; default to Ambient if no recognized prefix found |

#### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| AudioStreamInteractive (Godot 4.3+) | Purpose-built Godot node for adaptive music | Requires .tres resource authoring per track in the editor; incompatible with runtime file scanning; overkill for 3 fixed categories | Manual A/B AudioStreamPlayers with Tween cross-fade — simpler, dynamically loadable |
| Beat-synced transitions | Professional cinematic feel | Requires BPM metadata per track and tracks authored specifically for sync points; no BPM metadata exists for /music assets | Transition at wave boundary events (already discrete game events) |
| Separate AudioBusLayout with a Music bus | Fine-grained mixing control | Overkill for 3 categories; requires editor bus layout setup that is fragile to export; volume_db on the player node is sufficient | Direct volume_db on AudioStreamPlayer nodes |
| Per-enemy-type audio stingers | Hollywood-style dynamic cues | Requires 5 additional short audio assets not yet created; out of scope for v3.5 | Wave category transitions already communicate intensity changes |
| Randomized track order within a category | Adds variety on repeat plays | Must guard against repeating the last track; must handle single-track categories (only one file); adds stateful logic for marginal value | pick_random() with a single-entry guard (if array.size() == 1: return array[0]) |

---

### Enemy Sprites

#### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Each enemy shows a distinct ship sprite | Debug Polygon2D shapes convey no identity at a glance during combat | MEDIUM | Sprite2D node added as child in each enemy .tscn; region_enabled = true; region_rect set per enemy type using measured coordinates from ships_assests.png |
| Sprites face forward (correct rotation axis) | Backward sprite is a visual bug | LOW | Sprite2D inherits parent RigidBody2D rotation; ships_assets.png art faces upward (+Y); game forward = +X; set Sprite2D.rotation_degrees = 90 (or flip in region offset) — confirm during implementation |
| Sprite scale matches player ship approximate size | Tiny enemies at large combat range are invisible; oversized enemies clip each other | LOW | Player ShipBFG23 is approximately 120px visual width in scene; measure each sprite region and set Sprite2D.scale = Vector2(target_px / sprite_region_width) |
| Fallback to Polygon2D when sprite unavailable | Graceful degradation; game remains playable if asset is missing or corrupted | LOW | if ResourceLoader.exists("res://ships_assests.png"): show Sprite2D, hide Polygon2D; else: hide Sprite2D, show Polygon2D |

#### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Per-enemy gem glow PointLight2D with pulsing energy | Distinct per-type color identity readable instantly during combat; costs no gameplay design work | MEDIUM | PointLight2D child node per enemy; energy sinusoidally animated in _process: energy = base + amplitude * sin(Time.get_ticks_msec() * 0.001 * freq); gem colors from image — ENM-07 green, ENM-08 purple, ENM-09 orange, ENM-10 gold/cream, ENM-11 red |
| Sprite sheet sliced programmatically (not via editor import) | No per-sprite editor click-work; region coords live in code as constants | MEDIUM | AtlasTexture constructed in GDScript: var at = AtlasTexture.new(); at.atlas = preload("res://ships_assests.png"); at.region = Rect2(x, y, w, h); sprite.texture = at; region coordinates must be manually measured from the PNG (no auto-slice metadata exists in the file) |
| Sprite orientation correction as a constant | Clean code — no magic rotation in _process every frame | LOW | ships_assests.png art faces upward; set Sprite2D.rotation_degrees = 90 as a constant in each enemy _ready(); does not affect physics rotation |

#### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| AnimatedSprite2D with SpriteFrames | Enables idle/thrust/damage frame animations | No animation frames exist in ships_assests.png; one static sprite per ship; SpriteFrames resource adds overhead with zero visual benefit | Sprite2D with region_enabled for single-frame sprite display |
| Editor-side SpriteSheet import (atlas slice in .import file) | GUI-friendly workflow in the Godot editor | Requires manual per-sprite setup in the editor; not reproducible in code; fragile on asset path change; cannot be driven by region constants | AtlasTexture constructed in GDScript — region Rect2 values as named constants per enemy type |
| Exporting separate PNGs per enemy from the atlas | Cleaner per-file asset management | Requires an external tooling step outside Godot; ships_assests.png is the canonical source; adds CI asset maintenance burden | Single atlas, Rect2 region constants in code |
| Replacing Polygon2D nodes in .tscn files | Cleaner scene tree | Polygon2D provides collision shape debug feedback and is the existing fallback; removing it breaks the fallback requirement; modifying 5 .tscn files increases regression risk | Add Sprite2D as a sibling child node; toggle .visible in _ready() conditionally |
| Gem glow via CanvasItemMaterial shader | More sophisticated visual pulse effect | Requires custom shader authoring and material assignment; PointLight2D.energy animation achieves the same perceived visual effect at zero shader complexity | PointLight2D with energy animated via sin() in _process |

---

## Feature Dependencies

```
[Game Restart]
    └── clears   --> [Enemy group nodes]   (get_tree().get_nodes_in_group("enemy") → queue_free each)
    └── resets   --> [ScoreManager state]  (total_score=0, kill_count=0, wave_multiplier=1, combo_count=0, _combo_timer.stop())
    └── resets   --> [WaveManager state]   (_current_wave_index=0, _enemies_alive=0, _wave_total=0)
    └── restores --> [PlayerShip state]    (health=max_health, dying=false, position=Vector2.ZERO, velocity=Vector2.ZERO)
    └── hides    --> [DeathScreen]         (visible = false)
    └── refreshes--> [Score HUD, Wave HUD] (emit multiplier_changed(1), score_changed(0,0) to trigger label refresh)

[Dynamic Music System]
    └── reads    --> [WaveManager.wave_started or wave_completed signal] (wave number → category threshold evaluation)
    └── reads    --> [WaveManager._current_wave_index]                   (1-5 = Ambient, 6-14 = Combat, 15-20 = High-Intensity)
    └── survives --> [Game Restart]                                       (music node persists if in autoload or above scene root; no interruption)

[Enemy Sprites]
    └── requires --> [ships_assests.png present at res://]  (already in project root — confirmed)
    └── coexists --> [Polygon2D fallback]                   (Polygon2D.visible toggled, not removed from scene)
    └── adds     --> [PointLight2D per enemy type]          (new child node; no dependency on any other system)
    └── scale-matches --> [PlayerShip visual size]          (~120px reference width from ship-bfg-23.tscn)

[Game Restart] --must-not-interrupt--> [Dynamic Music System]
    (restart is a state reset, not get_tree().reload_current_scene(); music node and state persist)
```

### Dependency Notes

- **Game Restart requires ScoreManager.reset():** ScoreManager is an autoload singleton. Its vars (total_score, kill_count, wave_multiplier, combo_count) persist across reload_current_scene. A dedicated reset() method must be called explicitly. Using reload_current_scene causes ScoreManager._ready() to re-execute, creating duplicate Timer and AudioStreamPlayer child nodes — the primary reason to avoid reload_current_scene.
- **Game Restart requires WaveManager counter reset:** WaveManager is a scene node (not an autoload), so reload_current_scene would reset it naturally — but enemies spawned in the world do not get cleaned up by scene reload. Manual enemy group clear + counter reset is therefore consistent with the manual-reset approach.
- **Music must survive restart:** If MusicManager is implemented as an autoload or a node parented to an above-scene container, it outlives the world scene state reset and does not interrupt. Manual restart trivially preserves music without any special handling.
- **Enemy Sprites coexist with Polygon2D fallback:** Sprite2D is added as a sibling child alongside the existing Polygon2D, not replacing it. The Polygon2D also serves as the collision debug overlay and visual orientation reference — keeping it satisfies the fallback requirement and preserves debugging utility.

---

## MVP Definition

### Launch With (v3.5)

All nine requirements are in scope for this milestone. No deferral is appropriate.

- [ ] **Game Restart** — "Restart" button on death screen leaderboard view; manual state reset (no reload_current_scene); enemy group cleared; ScoreManager.reset(); WaveManager counters zeroed; player health and position restored
- [ ] **Music auto-plays on start** — at least one track playing immediately on game start; loop enabled
- [ ] **Music scans /music folder** — DirAccess scan at startup; loads all .mp3/.ogg/.wav files found
- [ ] **Music category transitions on wave** — three category arrays; threshold logic on wave_started/wave_completed signal; category change triggers cross-fade
- [ ] **Cross-fade between tracks** — A/B AudioStreamPlayers; Tween volume_db 1.5s duration
- [ ] **Enemy Sprite2D from ships_assests.png** — AtlasTexture with Rect2 region constants per enemy type; Sprite2D child added in each enemy .tscn
- [ ] **Sprite fallback to Polygon2D** — ResourceLoader.exists() guard; Polygon2D.visible toggled off when sprite available
- [ ] **Gem glow PointLight2D** — per-enemy color constant; energy animated with sin() in _process
- [ ] **Sprite scale matches player** — scale Vector2 constant per enemy type; measured against player ship reference

### Add After Validation (post-v3.5)

- [ ] Smooth fade-to-black restart transition — trigger: player feedback requests it; implementation is LOW complexity when base restart works
- [ ] Beat-synced music transitions — trigger: music tracks authored with BPM metadata
- [ ] Per-enemy death audio stingers — trigger: short audio assets provided

### Future Consideration (v4+)

- [ ] AnimatedSprite2D per enemy with idle/thrust/damage animations — requires multi-frame art assets per enemy type
- [ ] AudioStreamInteractive adaptive music — requires tracks authored as stems/loops with sync points

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Game Restart | HIGH | LOW | P1 |
| Music auto-plays + loops | HIGH | LOW | P1 |
| Music folder scan | MEDIUM | LOW | P1 |
| Music category/wave transition | HIGH | MEDIUM | P1 |
| Cross-fade A/B | MEDIUM | MEDIUM | P1 |
| Enemy Sprite2D (atlas region) | HIGH | MEDIUM | P1 |
| Sprite fallback to Polygon2D | MEDIUM | LOW | P1 |
| Gem glow PointLight2D | MEDIUM | LOW | P1 |
| Sprite scale match | MEDIUM | LOW | P1 |
| Restart fade-to-black transition | LOW | LOW | P2 |

**Priority key:**
- P1: Required for v3.5 milestone
- P2: Add if time allows within v3.5
- P3: Future milestone

---

## Competitor Feature Analysis

Reference patterns from Godot 4 arcade shooters (design patterns, not competing products):

| Feature | Standard Godot tutorial pattern | Geometry Wars / arcade pattern | Our Approach |
|---------|--------------------------------|-------------------------------|--------------|
| Restart | get_tree().reload_current_scene() | Same | Manual state reset — preserves music, avoids autoload Timer/AudioStreamPlayer side-effects |
| Music | Single AudioStreamPlayer in scene | Looping background track, no dynamics | A/B AudioStreamPlayers in persistent node; cross-fade via Tween; category driven by wave index thresholds |
| Sprite sheets | Sprite2D hframes/vframes for uniform grids | AtlasTexture for non-uniform art | AtlasTexture with explicit Rect2 per ship — ships_assests.png is non-uniform layout |
| Fallback visuals | Not a common pattern | Not applicable | Polygon2D sibling; visibility toggled in _ready() via ResourceLoader.exists() |
| Gem glow pulsing | AnimationPlayer on PointLight2D | Not applicable | PointLight2D energy with sin(Time.get_ticks_msec()) in _process — avoids AnimationPlayer complexity |

---

## Sources

- Godot 4.6 official documentation via Context7 (/websites/godotengine_en_4_6): AudioStreamPlayer, Tween, DirAccess, ResourceLoader, AtlasTexture, Sprite2D, PointLight2D, get_tree().reload_current_scene() — HIGH confidence
- Project source files: `/components/score-manager.gd`, `/components/wave-manager.gd`, `/prefabs/ui/death-screen.gd`, `/world.gd`, `/components/beeliner.gd`, `/components/enemy-ship.gd`, `/components/random-audio-player.gd` — HIGH confidence (direct read)
- Project assets: `ships_assests.png` (visually inspected — 5 ships ENM-07 through ENM-11 with distinct gem colors, non-uniform layout on white background), `/music/Gravimetric Dawn.mp3` (one track present) — HIGH confidence (direct read)
- Project context: `.planning/PROJECT.md`, `MILESTONE_V35.md` — HIGH confidence (direct read)

---
*Feature research for: Graviton v3.5 — dynamic music, sprite sheets with fallbacks, game restart*
*Researched: 2026-04-16*
