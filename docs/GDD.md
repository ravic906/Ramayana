# Game Design Document — *Ramayana: The Journey of Rama*

> Working title. Living document — update as design evolves.

## 1. Vision

A premium, stylized-3D action-adventure for mobile that lets players walk the path of **Shri Rama**
through all seven kandas of the Valmiki Ramayana. Combat is built around Rama's identity as the
greatest archer — the bow *Kodanda* and the divine **astras** — supported by the companions who
stand beside him: Lakshmana, Sita, Hanuman, Sugriva, Jatayu, Vibhishana and the Vanara army.

**Pillars**
1. **Rama is the hero.** Every kanda is played as Rama. Others support, assist and are summoned —
   they never replace him as the player character.
2. **Archery-first combat.** Fluid, readable, one-thumb-friendly ranged combat with auto-aim,
   charged shots and cinematic astras.
3. **Dharma matters.** Protecting allies and showing restraint is mechanically rewarded.
4. **Faithful and respectful.** Valmiki Ramayana as the primary source, reviewed by a cultural
   consultant; divine characters are never trivialised.
5. **Mobile-native quality.** 60 FPS on mid-range phones, short sessions (10–15 min missions),
   offline play.

**Audience:** 12+ (Story mode for younger players / families). Primary markets: India and the
Indian diaspora, secondary: global mythology/action fans.

**Business model:** Premium + chapter unlock. Bala Kanda is free; a single in-app purchase
("The Full Journey") unlocks kandas 2–7. No consumables, no energy timers, no pay-to-win, no
purchasable skins for divine characters.

## 2. Core Loop

```
Explore region ─▶ Story beat / cutscene ─▶ Combat encounters ─▶ Boss
      ▲                                                          │
      └──── Skill tree upgrade ◀── Punya (XP) + new astra ◀──────┘
```

Each kanda is split into 4–8 **missions** (10–15 minutes each) with checkpoints and autosave.

## 3. Controls (touch, landscape)

| Input | Action |
|---|---|
| Left-thumb virtual joystick | Move Rama (camera-relative) |
| Swipe on right half of screen | Rotate camera |
| **Bow** button (tap) | Snap shot at the auto-aimed target |
| **Bow** button (hold, drag, release) | Draw, aim over the shoulder, loose. A release in the golden window is a perfect shot. |
| **Dodge** button | Dodge roll with brief invulnerability |
| Astra buttons (2–3 slots) | Cast equipped astras (cooldowns) |
| Companion button | Toggle companion command (Guard / Attack) |
| Summon button | Call a summon when the Dharma meter allows |

Gamepad and keyboard are supported as fallbacks (WASD / arrows, J = bow, K/Shift = dodge).

### Draw, hold, release (implemented in the prototype)
The bow is the heart of the game, so drawing it should feel physical:

| Phase | Feel |
|---|---|
| Nock | Click of the arrow on the string |
| Draw (0.65 s) | The camera blends over the right shoulder and zooms (FOV 50° → 36°). Time eases to 55%. The bow creaks louder and higher, its limbs flex, and the string bends to Rama's drawing hand at his cheek (arm IK). The phone ticks harder as tension rises. |
| Full draw | A haptic thump, a heartbeat, and a gold reticle: the **perfect window** (0.45 s) |
| Hold too long | After 2.2 s the aim trembles and the heartbeat quickens |
| Release | Twang and whoosh, recoil, camera kick and a golden trail. Power scales damage and arrow speed. |
| Perfect release | Double damage, a bell chime, a "PERFECT" banner, and the **arrow cam** in slow motion to the target |
| Impact | Hit-stop (50–90 ms), sparks, a thud, haptics, and the arrow stays stuck in the target |

A dodge cancels the draw. A quick tap is still a snap shot with generous auto-aim, for accessibility.

### Auto-aim
Targets are scored by distance and by how closely they align with Rama's facing direction,
inside a configurable range and cone. The best-scoring enemy receives the shot; with no target
the arrow flies straight ahead. (Implemented in `core/combat/auto_aim.gd`.)

## 4. Rama's Kit

- **Kodanda (bow):** primary weapon. Quick shots, charged piercing shots, later multi-shot.
- **Close strike:** short-range bow strike that knocks back enemies who get close.
- **Dodge roll:** invulnerability window (~0.35 s).
- **Astras** (unlocked through the story):

| Astra | Unlocked | Effect |
|---|---|---|
| Agneyastra | Bala, from Vishvamitra after Tataka (glimpsed in the prologue) | Fire burst, burn damage over time |
| Varunastra | Bala, from Vishvamitra after Tataka | Water wave, knockback, extinguishes fire |
| Vayavyastra | Bala, from Vishvamitra after Tataka | Wind blast that hurls enemies far away |
| Manavastra | Bala, scripted once vs. Maricha | Non-lethal: casts Maricha far over the sea |
| Brahmastra | Yuddha, from Agastya | The finale against Ravana |

- **Dharma meter:** fills when Rama protects allies, rescues civilians/sages and spares fleeing
  enemies. Spent on summons and on Rama's ultimate.

## 5. Support Characters

| Character | Role | Kandas | Mechanic |
|---|---|---|---|
| Lakshmana | AI companion | 1–7 | Melee tank, draws aggro; Guard/Attack command |
| Sita | Story ally | 1–3, 7 | Heals/blesses; later the emotional objective of the journey |
| Vishvamitra | Mentor | 1 | Teaches astras (tutorials) |
| Jatayu | Summon / story | 3 | Aerial dive attack |
| Hanuman | Summon / vision missions | 4–7 | Summon: leap smash. Sundara Kanda "visions" |
| Sugriva & Vanara army | Summon | 4–6 | Troop wave sweeping the battlefield |
| Vibhishana | AI companion | 6 | Reveals boss weak points |

Rama remains the playable hero throughout. In Sundara Kanda, Hanuman's mission is presented as
short "vision" sequences framed by Rama's perspective, then returns to Rama.

## 6. Chapters (Kandas)

### 1. Bala Kanda — *vertical slice, free*
- **Setting:** Ayodhya palace courtyards, Vishvamitra's Siddhashrama forest, Mithila.
- **Missions:**
  1. Ayodhya training grounds — movement & archery tutorial with Lakshmana.
  2. Journey with Vishvamitra — receiving the astras (astra tutorials).
  3. Forest of Tataka — exploration, first rakshasa enemies.
  4. **Boss: Tataka** — large, charging, throws boulders; teaches dodge timing.
  5. Protecting the yagna: wave defence. **Mini-bosses: Maricha & Subahu.** Subahu falls to the
     Agneyastra; the scripted **Manavastra** casts Maricha far over the sea, as in Valmiki.
  6. Ahalya's hermitage — a quiet narrative/exploration interlude.
  7. Mithila: **Shiva's bow (Pinaka)**, Valmiki's test of strength, as a cinematic
     draw-and-hold finale. Epilogue: the **Parashurama** cutscene teases the later Parts.
- **Playable now:**
  - missions 1–4: trials, the sage at the gate, the Silent Forest with the Dharma moment,
    the Tataka boss and the astra ceremony;
  - mission 2 continues on the road along the Sarayu: the sage's walk-and-talk, the
    stampede (Lakshmana's Guard tutorial, no animal harmed), two side quests, three palm
    leaves, and Bala and Atibala at the dusk camp, then the dawn;
  - mission 5: the Siddhashrama yagna defence, Maricha and Subahu, and the Manavastra.
  - Mission 6 shows a "coming soon" card.
- **Prologue:** Guru Vasishtha's maya trials in the Ayodhya training grounds. The
  final trial grants a temporary *glimpse* of the Agneyastra.
- **Unlocks:** Agneyastra, Varunastra and Vayavyastra (from Vishvamitra after Tataka), and
  Lakshmana's Guard command.

### 2. Ayodhya Kanda
Palace intrigue and exile. Story-focused chapter with traversal (crossing the Ganga with Guha),
Chitrakoot, Bharata's visit. Moral-choice dialogue that fills the Dharma meter. No boss.

### 3. Aranya Kanda
Dandaka forest and Panchavati. Rakshasa hordes, Khara & Dushana's army (14,000 → wave
survival). The golden deer chase (Maricha). Jatayu's sacrifice. Bosses: Khara, Maricha (deer).

### 4. Kishkindha Kanda
Rocky Kishkindha. Meeting Hanuman and Sugriva. Boss: **Vali** — a timing-based duel framed by
the story's moral complexity. Hanuman and Vanara summons unlocked.

### 5. Sundara Kanda
Hanuman vision missions: the ocean leap, Ashoka Vatika, the burning of Lanka. Boss (vision):
Akshaya Kumara. Returns to Rama receiving Sita's chudamani.

### 6. Yuddha Kanda
Building the **Setu** (a construction/defense mission with the Vanara army), Vibhishana joins,
large-scale battles. Bosses: Kumbhakarna, Indrajit (illusion fight), **Ravana** (multi-phase;
ten heads that regenerate — the Brahmastra finale).

### 7. Uttara Kanda
Return to Ayodhya and coronation; epilogue told with care and respect. Unlocks boss rush and
New Game+.

## 7. Progression

**Implemented:**
- the skill tree (12 skills, Punya);
- three star goals per mission, with a summary;
- the Missions replay list;
- Story / Warrior modes;
- side quests with a palm-leaf codex (the Ayodhya hub).

**Part 1 target:** 2–3 hours (see the roadmap in the README).

- **Punya (XP):** from missions, bosses, Dharma actions.
- **Skill tree:** three branches — *Archery* (charge speed, multishot, pierce), *Astras*
  (cooldown, power, new forms), *Dharma* (companion buffs, summon power).
- **Lore codex:** collectible palm-leaf manuscripts unlock illustrated lore entries — an
  optional educational layer.
- **Difficulty:** Story / Normal / Hard; New Game+ after Uttara Kanda.

## 8. Enemies (Bala Kanda set)

**In the prototype:**
- Grunts and archers (`data/enemies/*.tres`) with a readable attack cycle: chase → telegraph
  (red glow and growl, ~0.75 s) → strike → recover.
- At most two rakshasas wind up at once, so fights stay readable on a phone.
- Big hits (≥ the enemy's stagger threshold) interrupt the attack.
- Three waves run in the training arena (`kandas/01_bala/wave_spawner.gd`).
- Agneyastra is implemented: it arms the next drawn shot, explodes for 35 damage in a 4.5 m
  radius with falloff, adds knockback, burns for 6 dps over 4 s, leaves burning ground for 3 s,
  and has a 12 s cooldown.

| Enemy | Behaviour |
|---|---|
| Rakshasa grunt | Melee, telegraphed swing |
| Rakshasa archer | Ranged, keeps distance |
| Mayavi (illusionist) | Teleports, spawns decoys |
| Tataka (boss) | Charge, ground slam, boulder throw; enrages at 50% |
| Maricha & Subahu (mini-bosses) | Aerial attackers raining fire on the yagna |

## 9. Cultural & Content Guidelines

- Primary source: Valmiki Ramayana; regional variations noted in the lore codex.
- A cultural consultant reviews script, character design and key scenes.
- No comedic depiction of Rama, Sita or Hanuman; violence is stylised, not gory.
- Launch languages: English, Hindi, Telugu, Tamil. Later: Kannada, Malayalam, Bengali, Marathi.

## 10. Parts and monetization

The game is **one app** in which the journey unfolds as **episodic Parts**, released as downloadable
updates. One save carries Rama's skills, astras, Dharma and Punya from Part to Part. Each Part
roughly follows one kanda; Yuddha Kanda is split in two.

| Part | Title | Kanda | Climax |
|---|---|---|---|
| 1 | The Prince of Ayodhya | Bala | Tataka; Shiva's bow |
| 2 | The Exile | Ayodhya | Crossing the Ganga; Chitrakoot (drama plus one action set piece) |
| 3 | The Forest of Trials | Aranya | Khara; the golden deer; Jatayu |
| 4 | The Monkey Kingdom | Kishkindha | Vali |
| 5 | The Leap | Sundara | Hanuman's vision missions; burning Lanka |
| 6 | The Bridge to Lanka | Yuddha I | Setu; Kumbhakarna |
| 7 | The War for Dharma | Yuddha II | Indrajit; Ravana |
| 8 | The Return | Uttara | Coronation; Lava and Kusha (short finale) |

| Product | Price (indicative) | Contents |
|---|---|---|
| Free download | — | Part 1 (Bala Kanda) complete |
| Single Part (non-consumable, `ramayana_part_NN`) | ₹149 / $1.99 | That Part |
| The Full Journey (non-consumable, `ramayana_full_journey`) | ₹699 / $8.99 | All current and future Parts |

Optional later: a soundtrack/art-book DLC. Never: loot boxes, energy, divine character skins.
