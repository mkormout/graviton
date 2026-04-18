# Game Implementation Tasks (Version 3.0)

**Context:** Following an testing period of the new enemy implementation, we have identified several improvements and fixes required for version 3.0. Please implement or provide the code structure for the following updates.

## 1. User Interface (UI) Improvements
* **Wave Labels:** Increase the font and overall size of the labels showing the Wave Name, Enemy Count, and Countdown. Add a **subtitle** below the wave name specifying the enemy types (similar to the central announcement at the start of a wave).
* **Cheat Sheet:** Update the right-side cheat sheet to include descriptions for all new keyboard shortcuts.
* **Toggle Visibility:** Implement a new keyboard shortcut to show/hide the cheat sheet during gameplay.

## 2. Scoring System
* **Counter Enhancements:** Expand the score counter. In addition to collected coins, track and display:
    * Number of destroyed enemy ships.
    * Total Score (calculated based on logic below).
* **Score Multiplier:** Add a visible multiplier indicator.
    * The multiplier increases by **2x every wave**, provided the player takes no damage.
    * If the player is hit, the multiplier resets to 1x.
* **Combo System:**
    * Increase a "Combo" counter by 1 for every enemy killed (starting from the 2nd kill).
    * **Timer:** If no enemy is killed for more than 5 seconds, the accumulated combo is "cashed in." The player receives the total score from those kills multiplied by the combo factor.
    * **Audio:** Each combo increase should trigger a sound effect with a **progressively higher pitch** for each subsequent kill in the chain.
* **High Score Leaderboard:** * Implement local storage (disk or browser `localStorage`).
    * Upon player death, prompt for a name.
    * The game should remember the last entered name for the next session.

## 3. Enemy Behavior & Balancing
* **Orientation:** Enemy meshes/shapes should always have one of their vertices/corners pointing toward the player's barrel (look-at direction). The "axis of sight" should bisect the enemy shape into two equal halves.
* **Individual Values:** Define a specific score value for each enemy type.
* **Global Buffs:** * Increase **fire range by 2x** for all enemies.
    * Slightly increase **projectile speed** for all enemies.
    * Double (**2x**) the **HP** for all enemy types.
* **Class-Specific Tweaks:**
    * **Beeliner:** Slightly increase movement speed and add a layer of randomness to their pathing so they don't move in a perfect formation.
    * **Flanker:** Fix the bug where Flankers get stuck far from the player and fail to resume their "patrolling" behavior.
    * **Swarmer:** Increase max speed. Make movement more dynamic to create "fast" and "slow" swarms (groups with varied movement traits). Significantly increase their fire range and projectile speed (currently the weakest link).
    * **Sniper:** Implement slight "strafing" (side-to-side movement) while aiming to make them harder to hit.
    * **Suicider:** Increase maximum movement speed and slightly buff the explosion radius/damage.

## 4. Wave Logic
* **Variety:** Increase wave complexity by adding more enemies and more diverse enemy compositions.
* **Manual Progression:** Remove automatic wave transitions. Display a label when a wave is cleared, requiring the player to press **Enter** or **F** to start the next wave.

## 5. Items & Pickups
* **Health Pack:** Implement a new Health Pack item.
    * **Drop Rate:** 10% chance to drop from any destroyed enemy.
    * **Visuals:** Marked with a green cross, featuring a soft green emissive glow and a light green aura/particle effect.