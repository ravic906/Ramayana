# Ramayana: The Journey of Rama

A stylized 3D action-adventure for mobile (Android and iOS), built with **Godot 4**. You play as
**Shri Rama** through all seven kandas of the Valmiki Ramayana, fighting with the bow Kodanda and
the divine astras. Lakshmana, Sita, Hanuman, Sugriva, Jatayu, Vibhishana and the Vanara army fight
beside him as companions and summons.

- **Structure:** one app. The journey is told in 8 episodic **Parts**, roughly one per kanda,
  with Yuddha Kanda split in two. They're released as downloadable updates, and one save carries
  Rama's progress through all of them.
- **Business model:** Part 1 (Bala Kanda) is free. Each later Part can be unlocked on its own,
  or the **Full Journey** unlocks them all. No pay-to-win.
- **Current milestone:** Phase 0/1. Design docs and a playable grey-box prototype.

## Documents
- [Game Design Document](docs/GDD.md): pillars, controls, Rama's kit, companions, all seven kandas
- [Art Bible](docs/ART_BIBLE.md): visual direction, palette, budgets, UI, audio
- [Technical Design](docs/TECH_DESIGN.md): architecture, systems, performance budgets, testing
- [Story Bible](docs/STORY.md): framing, Bala Kanda beat sheet, character arcs, sensitive moments, open decisions

## Running the prototype
1. Install [Godot 4.3+](https://godotengine.org/download) (the standard build, not .NET).
2. Open `project.godot` in the editor and press **F5**. The game opens on the **Journey menu**
   (`ui/journey_menu.tscn`). Part 1 starts the royal training grounds of Ayodhya at golden hour.

| Action | Touch | Keyboard |
|---|---|---|
| Move | Left-side stick (appears under the thumb) | WASD / arrow keys |
| Look | Swipe on an empty part of the screen | Mouse drag (touch emulation) |
| Snap shot (auto-aim) | Tap **Bow** | Tap J / Space |
| Draw, aim, loose | Hold **Bow** (drag the same thumb to aim), then release | Hold J / Space, mouse-drag to aim |
| Dodge roll (cancels a draw) | **Dodge** button | K / Shift |
| Arm Agneyastra (next drawn shot) | **Agni** button | L / 1 |

Survive Guru Vasishtha's three *maya* trials: waves of illusory rakshasas summoned into the royal
training grounds of Ayodhya. In the final trial, Vasishtha grants a brief *glimpse* of the
Agneyastra; Rama truly receives the astras from Vishvamitra later in Part 1.
- **Grunts** charge with spiked clubs. Each glows red and growls before it swings, so dodge through
  the blow for a *perfect dodge*.
- **Archers** keep their distance and strafe.

The red dummies remain for target practice. If Rama falls, he rises again and the wave restarts.

### Part 1 so far
Play from the Journey menu to get the story:
1. **Golden Hour:** Guru Vasishtha's maya trials in Ayodhya.
2. **The Sage at the Gate:** Vishvamitra asks Dasharatha for Rama.
3. **The Silent Forest:** a cursed forest walk with Lakshmana, two ambushes, and a wounded
   rakshasa who flees. Let him go and Rama's **Dharma** rises.
4. **Tataka:** the first boss.
   - She charges (trees stun her), slams the ground (roll through the shockwave) and hurls
     boulders (shoot them down).
   - Below half health she vanishes into maya, and only the dust shows where she is.
   - Afterwards the forest blooms, and Vishvamitra grants **Agneyastra, Varunastra and
     Vayavyastra** for good.

Cutscenes can be skipped. Missions resume from where you left off.

### Music
Adaptive music, generated in code by `tools/gen_music.py` (placeholder until the real score):
| Scene | Raga | What you hear |
|---|---|---|
| Journey menu | Yaman | tanpura and a slow bansuri alaap |
| Ayodhya trials | Yaman | flute and santoor; tabla teental comes in when a trial starts |
| Silent Forest | Malkauns | low drone, breathy flute and wind; mridangam and dhol in ambushes |
| Tataka | Malkauns | barrel drums and dhol; an eerie choir joins in her maya phase |
| The bloom | Bhupali | choir, santoor and flute |

Music dips under dialogue. The pause menu has **Music** and **Sound** volume sliders.

### Agneyastra (a glimpse in the prologue)
Tap **Agni** to set the bow aflame, then loose a drawn arrow (at least 60% draw). It explodes in
fire, hurling back and burning every rakshasa nearby, and leaves the ground burning. It then needs
12 seconds before it can be invoked again; the ring on the button shows the cooldown.

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
| 1. Prototype | Rama's movement, bow and auto-aim ✅ · animated, dressed Rama ✅ · draw-hold-release archery ✅ · Agneyastra ✅ · rakshasa grunts and archers ✅ · Lakshmana AI |
| 1c. Part 1 story | Missions 1–4: trials, Vishvamitra, the Silent Forest, the Tataka boss, astra ceremony ✅ |
| 1b. Surroundings | Ayodhya training grounds at golden hour ✅ (gopuram, colonnades, garden, kalyani, sky); Stylised / Realistic looks ✅ |
| 2. Vertical slice | Bala Kanda at final quality: Tataka boss, Shiva's bow finale, menus, saves |
| 3. Soft launch | Bala Kanda free on Android (India), then iOS |
| 4–5. Parts 2–8 | Released one by one as downloadable Parts, ending with the Ravana finale and The Return |
| — | Parts structure: Journey menu, per-Part unlocks, downloadable Part packs ✅ |
