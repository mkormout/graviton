# Requirements: Graviton v3.5 Juice & Polish

**Milestone:** v3.5  
**Goal:** Transform the raw combat loop into a polished experience with real enemy sprites, dynamic music, and a proper restart flow.  
**Status:** Active

---

## v3.5 Requirements

### Game Restart

- [ ] **UI-05**: Player can click "Play Again" on the death screen to restart without reloading the application
- [ ] **UI-06**: Restart resets wave to Wave 1, clears all living enemies, and restores player to full health
- [ ] **UI-07**: Restart resets MusicManager to Ambient intensity

### Dynamic Music

- [ ] **MUS-01**: Background music begins playing automatically when the game starts
- [ ] **MUS-02**: MusicManager loads tracks via a preload catalog (export-safe; no DirAccess scan)
- [ ] **MUS-03**: Tracks are categorized as Ambient, Combat, or High-Intensity
- [ ] **MUS-04**: Active music category updates based on current wave number/complexity
- [ ] **MUS-05**: Music transitions between categories with a cross-fade (dual AudioStreamPlayer + Tween)

### Enemy Sprites

- [ ] **SPR-01**: All 5 enemy types (ENM-07–ENM-11) display sprites from ships_assets.png
- [ ] **SPR-02**: Sprite regions are extracted via hardcoded Rect2 constants per enemy type
- [ ] **SPR-03**: If sprite is unavailable, enemy falls back to existing Polygon2D shape
- [ ] **SPR-04**: Each enemy has a pulsing PointLight2D gem glow matching gem color (with distance culling)
- [ ] **SPR-05**: Enemy sprite scale is adjusted so apparent size matches the player ship

---

## Future Requirements

- Boss music category (no boss enemy yet)
- Ammo sprite variants from ships_assets.png (lower-right of sheet)
- Player ship sprite replacement
- Animated sprite frames (idle/thrust/damage states)

---

## Out of Scope

- DirAccess-based auto-scan of music folder — export-unsafe; use preload catalog instead
- External audio middleware plugins — Godot built-ins sufficient
- NavigationAgent2D or other pathfinding changes
- New enemy types in this milestone
- Multiplayer
- Procedural level generation

---

## Traceability

| REQ-ID | Phase | Status |
|--------|-------|--------|
| UI-05  | TBD   | Pending |
| UI-06  | TBD   | Pending |
| UI-07  | TBD   | Pending |
| MUS-01 | TBD   | Pending |
| MUS-02 | TBD   | Pending |
| MUS-03 | TBD   | Pending |
| MUS-04 | TBD   | Pending |
| MUS-05 | TBD   | Pending |
| SPR-01 | TBD   | Pending |
| SPR-02 | TBD   | Pending |
| SPR-03 | TBD   | Pending |
| SPR-04 | TBD   | Pending |
| SPR-05 | TBD   | Pending |

---
*Last updated: 2026-04-16 — v3.5 requirements defined*
