# Ramayana: The Journey of Rama

A stylized 3D action-adventure for mobile (Android and iOS), built with **Godot 4**. You play as
**Shri Rama** through all seven kandas of the Valmiki Ramayana, fighting with the bow Kodanda and
the divine astras. Lakshmana, Sita, Hanuman, Sugriva, Jatayu, Vibhishana and the Vanara army fight
beside him as companions and summons.

- **Business model:** Bala Kanda is free; one purchase ("The Full Journey") unlocks kandas 2–7.
  No pay-to-win.
- **Current milestone:** Phase 0/1. Design docs and a playable grey-box prototype.

## Documents
- [Game Design Document](docs/GDD.md): pillars, controls, Rama's kit, companions, all seven kandas
- [Art Bible](docs/ART_BIBLE.md): visual direction, palette, budgets, UI, audio
- [Technical Design](docs/TECH_DESIGN.md): architecture, systems, performance budgets, testing

## Running the prototype
1. Install [Godot 4.3+](https://godotengine.org/download) (the standard build, not .NET).
2. Open `project.godot` in the editor and press **F5**. The main scene is
   `kandas/01_bala/greybox.tscn`, the Ayodhya training grounds.

| Action | Touch | Keyboard |
|---|---|---|
| Move | Left-side stick (appears under the thumb) | WASD / arrow keys |
| Look | Swipe on an empty part of the screen | Mouse drag (touch emulation) |
| Fire bow (auto-aim) | **Bow** button | J / Space |
| Dodge roll | **Dodge** button | K / Shift |

Hit the rakshasa training dummies to earn Punya.

## Tests
```bash
godot --headless --import                      # first time only: builds the class cache
godot --headless -s res://tests/run_tests.gd   # exits non-zero if any test fails
```
The tests cover the state machine, health, auto-aim scoring, saves (round trip and tamper
rejection), chapter gating, and an integration test that drives Rama around the grey-box level.

## Layout
```
autoload/     GameState, SaveSystem, Store (IAP), Controls (input map)
core/         StateMachine, combat (Health, AutoAim, Arrow), touch input, camera
characters/   rama/ (player and states), enemies/, companions/, bosses/
kandas/       one folder per kanda (01_bala has the grey-box)
ui/           HUD
docs/         design documents
tests/        headless test runner and unit tests
```

## Roadmap
| Phase | Deliverable |
|---|---|
| 0. Pre-production | GDD, art bible, Bala Kanda script, project skeleton ✅ (skeleton) |
| 1. Prototype | Rama's movement, bow and auto-aim ✅ · one astra · Lakshmana AI · first rakshasa enemy |
| 2. Vertical slice | Bala Kanda at final quality: Tataka boss, Shiva's bow finale, menus, saves |
| 3. Soft launch | Bala Kanda free on Android (India), then iOS |
| 4–5. Full journey | Kandas 2–7, ending with the Ravana finale and New Game+ |
