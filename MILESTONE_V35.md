# Development Tasks: Version 3.5

## 1. User Interface (UI)
* **Game Restart:** Implement a "Restart Game" functionality. The system should allow the player to reset the game state, wave progress, and scores to start a fresh session without reloading the entire application.

## 2. Music System
* **Dynamic Audio Engine:** Implement a music management system that handles background audio.
* **Asset Loading:** The system should automatically scan and utilize all audio files located in the `/music` folder.
* **Dynamic Adaptation:** The music must change dynamically based on the current **wave complexity** (e.g., enemy count, difficulty intensity, or wave progression).
* **Categorization Strategy:** * Design a way to categorize tracks (e.g., *Ambient, Combat, Boss, High-Intensity*) to facilitate these dynamic transitions.
    * Propose a technical solution for how the system should decide which track to play and how to handle transitions (e.g., cross-fading or layering).

## 3. Enemy Visuals & Sprites
* **Sprite Implementation:** Transition from debug shapes to actual sprite assets.
* **Asset Source:** Use the `ships_assets.png` file located in the project root.
    * **Details:** This sheet contains all enemy ships (ENM-07 to ENM-11) and their respective ammunition on a white background.
    * **Slicing:** The system needs to programmatically extract (crop) individual ships and projectiles from this sprite sheet.
* **Fallback Logic:** Keep the existing debug shapes in the code. Implement a conditional check: show the sprite if available; otherwise, default to the debug shape.
* **Visual Effects (Gem Glow):** * Each ship features a colored gem in its center.
    * Implement a **pulsing light effect** for these gems. The light color should match the color of the specific gem.
* **Scaling:** Adjust the final scale of the enemy ships to be approximately the same size as the player's ship.
