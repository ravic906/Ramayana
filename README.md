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
| Snap shot (auto-aim) | Tap **Bow** | Tap J / Space |
| Draw, aim, loose | Hold **Bow** (drag the same thumb to aim), then release | Hold J / Space, mouse-drag to aim |
| Dodge roll (cancels a draw) | **Dodge** button | K / Shift |

Hit the rakshasa training dummies to earn Punya.

### The bow
Holding Bow draws the Kodanda:
- The camera moves over Rama's shoulder and zooms as the string tightens.
- Time slows, the bow creaks and flexes, and the phone vibrates with rising tension.

Release while the reticle glows **gold**, just after full draw, for a **perfect shot**. A perfect
shot does double damage and the camera rides along with the arrow. Hold too long and Rama's aim
starts to tremble.

## Try it on your Android phone
Every push builds a debug APK through GitHub Actions (`.github/workflows/android.yml`).
1. On your phone, open **https://github.com/ravic906/Ramayana/releases/tag/android-dev**.
2. Download `ramayana-debug.apk` and open it.
3. If Android asks, allow your browser or file manager to install unknown apps.

Each build replaces the previous one; install over the top to update. The APK is also attached to
every workflow run (Actions tab → run → Artifacts) as a zip.

The build targets arm64 phones running Android 5.0+ and needs Vulkan, which most phones from 2018
onward support.

## Credits
Rama's prototype body and animations are CC0 assets by Quaternius. See [assets/CREDITS.md](assets/CREDITS.md).

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
tools/        asset build scripts (e.g. build_rama.gd)
docs/         design documents
tests/        headless test runner and unit tests
```

## Roadmap
| Phase | Deliverable |
|---|---|
| 0. Pre-production | GDD, art bible, Bala Kanda script, project skeleton ✅ (skeleton) |
| 1. Prototype | Rama's movement, bow and auto-aim ✅ · animated, dressed Rama ✅ · draw-hold-release archery ✅ · one astra · Lakshmana AI · first rakshasa enemy |
| 2. Vertical slice | Bala Kanda at final quality: Tataka boss, Shiva's bow finale, menus, saves |
| 3. Soft launch | Bala Kanda free on Android (India), then iOS |
| 4–5. Full journey | Kandas 2–7, ending with the Ravana finale and New Game+ |
