# Technical Design

## Engine & Targets

| Item | Choice |
|---|---|
| Engine | Godot 4.3+ |
| Renderer | **Mobile** (Vulkan); Compatibility (GLES3) fallback for low-end Android |
| Language | GDScript; C++ GDExtension only for profiled hot paths |
| Platforms | Android 8+ (arm64), iOS 15+ |
| Frame rate | 60 FPS on mid-range (Snapdragon 7-series / Apple A14), 30 FPS floor on low-end |
| Install size | < 1.5 GB base; kandas 2–7 delivered as downloadable `.pck` packs |
| Orientation | Sensor landscape |

## Project Layout

```
autoload/        Global singletons: GameState, SaveSystem, Store, Controls
core/
  state_machine/ StateMachine + State (reusable FSM)
  combat/        Health, AutoAim, Arrow projectile
  input/         VirtualJoystick, ActionButton (multitouch)
  camera/        FollowCamera (swipe to rotate)
characters/
  rama/          Rama player controller + states (Idle, Move, Dodge)
  companions/    CompanionAI + per-character folders (future)
  enemies/       Enemy base + variants (TargetDummy for now)
  bosses/        Boss folders (future)
data/            Resource (.tres) definitions: astras, enemies, kandas
kandas/          Per-kanda scenes; 01_bala/training_grounds.tscn is the prototype level
ui/              HUD, menus
assets/          glTF models, textures, audio, shaders
tests/           Headless test runner + unit tests
```

## Autoloads

| Name | File | Responsibility |
|---|---|---|
| `Controls` | `autoload/controls.gd` | Registers input actions with keyboard defaults at startup |
| `GameState` | `autoload/game_state.gd` | Current kanda, punya, unlocked astras, story flags; (de)serialisation |
| `SaveSystem` | `autoload/save_system.gd` | Slot-based JSON saves with a SHA-256 checksum |
| `Store` | `autoload/store.gd` | IAP wrapper: entitlement for "The Full Journey" (stubbed) |
| `Settings` | `autoload/settings.gd` | Look, quality, story mode and Music/SFX volumes (`user://settings.cfg`); creates the Music and SFX buses |
| `Music` | `autoload/music.gd` | Adaptive music: synced stems, crossfades, intensity, layers, ducking; routes other players to SFX |

## Key Systems

### Player controller
`Rama` is a `CharacterBody3D`. Behaviour lives in a node-based `StateMachine` (`Idle`, `Move`,
`Dodge`; later `Aim`, `Astra`, `Stagger`). Shooting is an overlay action that is allowed in
`Idle` and `Move`. Movement is relative to the camera's yaw.

### Character visuals
`RamaModel` (`characters/rama/rama_model.gd`) wraps the rigged body built by
`tools/build_rama.gd`.
- **Ornaments** are authored in rest-pose space and parented to bones through `BoneAttachment3D`.
- **The bow** follows the left hand's position, while code sets its orientation: carried at
  rest, raised while shooting.
- **The AnimationTree is built in code:**
  - BlendSpace1D locomotion (idle / walk / run, driven by speed)
  - upper-body `shoot` and `hit` one-shots
  - a full-body `roll` one-shot, time-scaled to the dodge duration
- **Outfit colours** are painted as 0/1 region masks in vertex colours and mapped to palette
  uniforms in the toon shader, so they look the same under the Mobile and Compatibility
  renderers.

### Archery feel
- **State and draw logic:** the `Aim` state (`characters/rama/states/aim.gd`) drives the draw,
  with logic in `Rama.begin_draw / update_draw / release_draw`. Draw timing uses real
  (unscaled) seconds so slow motion doesn't change it.
- **Slow motion:** the `TimeFX` autoload owns `Engine.time_scale` through named layers (`focus`,
  `arrow_cam`, `hitstop`). The slowest layer wins, and every layer is cleared on release, dodge or
  scene exit.
- **Arm IK:** `ArcheryPose` is a `SkeletonModifier3D` doing analytic two-bone IK for both arms
  plus a head look-at, blended by `influence`. Godot applies modifier output only for rendering,
  so it publishes the solved hand positions, which the bow, string and nocked arrow follow.
- **Bow flex:** `toon_bow.gdshader` bends the limbs on `bend`. The string is two segments from
  the tips to the nock.
- **Camera:** `FollowCamera` blends to an over-the-shoulder aim view, punches FOV with the draw,
  shakes on trauma, adds depth of field on Vulkan renderers, and runs the arrow cam.
- **Feedback:** haptics come from `Haptics.pulse` (Android `VIBRATE` permission is enabled).
  Prototype sounds are synthesised by `tools/gen_sfx.py`.

### Music
- **Cues:** `tools/fetch_music.py` downloads Kevin MacLeod tracks (CC BY 4.0) and cuts each cue
  to a seamless loop:
  - it searches the loop start and length where the music after the end best matches the start
    (log band-energy similarity);
  - it aligns the seam to the sample by cross-correlation and crossfades (1.2 s, or 2.5 s for
    weak matches);
  - it normalizes loudness on the band phone speakers reproduce (above ~200 Hz).
  - Output: `assets/audio/music/<cue>.ogg` plus `credits.json`, about 7 MB in total.
- **Playback (`Music`):** each scene track maps to cues (`TRACKS`).
  - `set_intensity()` crossfades explore ↔ combat with hysteresis: on at 0.5, off at 0.2. In
    0.6 s, out 3 s.
  - `set_layer("maya")` swaps Tataka's cue.
  - `stinger()` plays a one-shot and ducks the music 9 dB.
  - `duck()` (cutscenes, -6 dB) and `voice_duck()` (while a line is spoken, -7 dB) add up.
- **Hooks:** `WaveSpawner` wave signals drive intensity.
  - The forest switches to "tataka" in `_start_boss`, with the reveal stinger.
  - It falls silent when she falls, plays the blessing stinger at the astra ceremony, and plays
    "bloom" with the bloom action.
- **Buses:** Master ← Music, SFX, Voice. Any other `AudioStreamPlayer*` added on Master is moved
  to SFX.

### Voices
- **Generation:** `tools/gen_voices.py` (Piper, `en_GB-vctk-medium`) voices:
  - every line in `data/dialogue/**`;
  - every `show_subtitle("Speaker", "...")` and `lakshmana.say("...")` call-out in code.
- **Cast:** `CAST` sets each character's VCTK speaker, speed, pitch and size, and reverb. Tataka
  gets a growl and distortion, the narrators unison, and the astras a choir.
- **Pronunciation:** `PRONOUNCE` respells Sanskrit names for the voice only.
- **Files:** `assets/audio/voice/<md5("Speaker|text")>.ogg`. `Voice.key()` computes the same
  key, so any subtitle is spoken without extra data. Edited lines need a regenerate; a test
  catches missing lines.
- **Playback (`Voice`):**
  - `say(speaker, text, interrupt)` returns the line's length and ducks the music;
  - `Cutscene` speaks each line, paces the typewriter to it, and auto-advances 0.6 s after it
    ends (a tap stops it and advances);
  - `HUD.show_subtitle` speaks call-outs without interrupting a line already playing.

### Mission 2b: the road along the Sarayu
- **Level:** `kandas/01_bala/sarayu_road.{tscn,gd}`; the environment `env/sarayu_road.scn` is
  built by `tools/build_sarayu.gd`:
  - a chunked height grid (river bed and sloping banks; trimesh collision on the walkable side;
    a wall at the shallows);
  - the river ribbon with `river.gdshader` (procedural flowing ripples along UV.y, lit glints,
    foam from vertex alpha);
  - `riverbank.gdshader` blends meadow into sand by vertex colour (textured PBR in the
    realistic look, two-tone noise in the stylised look);
  - the ghat and shrine, moored boats, Ayodhya's walls behind, crop fields, groves, reeds, the
    dusk camp with seat stones, and named markers that the level script reads.
- **Flow:** the gate cutscene calls `go_to_scene(SARAYU)`, and the road sets
  `GameState.checkpoint = "sarayu"`, which `PartFlow.scene_for()` honours on resume
  (`CHECKPOINT_SCENES`, mission 2 only). The camp ends with `complete_mission(2)`, then
  `go_to_mission(3)`.
- **The walk:** the sage leads to talk points, waits, and speaks when Rama catches up
  (`say_lines`); the light drifts from late afternoon to sunset with Rama's progress.
- **Stampede:** `Animal` (`characters/animals/animal.gd`: GRAZE / RUN / FLEE / CHARGE) runs
  along a route; bulls charge the sage. A companion on GUARD within 2.6 m turns a bull
  (Lakshmana steps between the sage and anything charging), and an arrow landing within 4.5 m
  makes an animal flee. Animals have no Health. +5 Dharma and `fact:sage_unharmed` if the
  sage is never struck.
- **Blessing:** the `bala_atibala` flag: dodge cooldown ×0.65 and bow tremble onset ×1.5
  (`Rama.has_bala_atibala()`). Saves already past mission 2 get it on load.
- **Story poses:** `RamaModel.play_pose()/clear_pose()` bypass the gameplay AnimationTree. New
  clips: `sit_down`, `sit`, `sit_talk`, `stand_up`, `kneel`, `talk`, `walk_formal`, `interact`.

### Mission 1's range, the forest chapters and the Trials
- **The Range** (`training_grounds.gd: range_chapter()`): three drills (moving `TargetDummy`s
  on looping tweens, three perfect releases via `Rama.released`, a far target at 36 m), each
  introduced by one Vasishtha line; flag `range_done` skips it afterwards.
- **The Silent Forest** (`build_forest.gd` extends the path south to z +190; `forest.gd`):
  - chapter I is open farmland with a ruined village (`_village()`) and three scouts (a
    `WaveSpawner` built in code, triggered at the village);
  - chapter II starts at the `Chapter2` marker, saves `checkpoint = "forest_c2"` and puts a
    thorn wall (`StaticBody3D`) on the path at `Thorns`;
  - `ShrinePuzzle` (`kandas/01_bala/shrine_puzzle.gd`): three bells are `StaticBody3D`s with
    a never-emptying `Health`, so an arrow hit is a ring. The order is `ORDER` (moon, earth,
    sun, from the carving); a wrong bell resets. Solving it lights the shrine, gives
    +30 Punya, sets `fact:shrine` and `flag shrine_rung`, and dissolves the thorns.
    `tools/gen_bells.py` synthesises the bells.
  - chapter III is the grove (unchanged).
- **Trials** (`core/progress/trials.gd`, `ui/trials_screen.gd`, `ui/trial_result.gd`):
  - `GameState.trial` (not saved) makes a level run its trial variant;
  - the Gauntlet is 30 escalating waves in the training grounds at night (score = foes + 3 per
    wave; one life);
  - the rematches (Tataka in the grove; night 6 at Siddhashrama) are timed and never advance
    the story or its checkpoints;
  - medal thresholds are in `Trials.LIST`; Punya for each new medal tier; the best result is
    kept in `flags`.

### Choosing any mission or chapter
- The Missions screen offers every available mission, and chapters for each
  (`PartFlow.CHAPTERS`): the Range or the Maya Trials; the palace, the gate, the Sarayu road,
  the camp; the fields or the Deep Wood; the grove; each Siddhashrama night, or the sky battle.
- `PartFlow.start_at(mission, chapter)` sets the mission and the checkpoint the level honours,
  and returns the scene. `ensure_story_state()` grants what the story would have given by then
  (the Bala and Atibala blessing for 3+; the astras and Tataka's defeat for 5+; the yagna for
  6+) and marks the mission reached; it never takes anything away. The Journey's Play still
  continues the story.

### Difficulty
- `Settings.difficulty`: STORY / WARRIOR / MAHARATHI (`story_mode` remains a property for
  older code; configs with only `story_mode` migrate).
- Scales per mode: incoming damage 0.5 / 1.0 / 1.5, enemy health 0.8 / 1.0 / 1.3, rakshasa
  wind-up 1.15 / 1.0 / 0.85 (`Rakshasa.telegraph_time()`), perfect window +0.2 / 0 / −0.05 s,
  aim-assist cone ×1.6 / 1 / 0.8. Tataka and the sky bosses take 1.3× health on Maharathi.
- Maharathi unlocks with the `tataka_defeated` flag; toggles skip it until then. Stars won on
  Maharathi are kept apart (`flags.hard_stars`) and shown as a red seal in the Missions list.

### Faces and close-up dialogue
- **The rig (build time, `tools/face_rig_builder.gd`, run by `tools/build_rama.gd`).** The
  Quaternius base has no facial rig, so the build makes one:
  - `Head`: the head split out of the skinned body by head-bone weight. Blend shapes live only on
    this small mesh, which keeps skinning cheap on phones.
  - Blend shapes (normalized, absolute targets) on `Head`: `jaw_open`, `mouth_smile`,
    `mouth_frown`, `mouth_wide`, `mouth_round`, `lips_press`, `cheek_raise`; on `Eyebrows`:
    `brow_raise`, `brow_furrow`, `brow_sad`. Each is a smooth-falloff displacement around
    landmarks measured on the rest pose; the jaw rotates the lower lip and chin about a pivot.
  - `HeadAttachment/EyeL|EyeR`: pivots at the eye centres (rest frame: +Z out of the face) holding
    `Ball` (turns to look) and `UpperLid` (a skin shell rotated from -58° open to 0° closed).
  - `HeadAttachment/MouthInterior`: a dark hollow behind the lips.
  - **For a commissioned head:** provide these shape names (they map to ARKit's
    `jawOpen`, `mouthSmile_L/R`, `mouthFrown_L/R`, `mouthStretch_L/R`, `mouthPucker`,
    `mouthPress_L/R`, `cheekSquint_L/R`, `browInnerUp`, `browDown_L/R`, and `eyeBlink_L/R`
    for lids) and the eye pivots, and the runtime works unchanged.
  - Materials: `FaceController.set_skin()` / `set_eyes()` set the body, head and lids together.
- **`FaceController`** (`core/visual/`), on `RamaModel` and `NpcModel` as `face_rig`:
  - blinks every 2.5–6 s (15% doubles), saccades, gaze toward `look_target`, lids follow a
    downward gaze;
  - restrained emotion presets (`EMOTIONS`); Rama defaults to *calm*;
  - effort at the bow (`draw`), a wince when struck;
  - lip sync: `tools/gen_voices.py` writes `assets/audio/voice/lipsync.json` (30 values a second
    per line, from speech-band loudness); `Voice.mouth_level()` reads it at the playback position;
    the speaking character's jaw and mouth follow it;
  - idle beyond 14 m from the camera unless speaking, so crowds cost nothing.
- **Cutscene framing (`ShotFramer`, `Cutscene`).** Lines are
  `Speaker|shot|action|text|emotion`. Levels register actors (`StoryLevel.actors`: Rama,
  Lakshmana, every `spawn_npc`). When the shot is empty, `auto`, `close`, `ots` or `two` and the
  speaker is an actor:
  - a two-shot opens the scene, then close-ups (eyes on the upper third, 26° lens) and
    over-the-shoulder shots, cut on the line with a slow push-in;
  - depth of field on the subject (off on Battery saver) and a soft warm key light;
  - the speaker takes the line's emotion and looks at the listener; everyone else looks at the
    speaker; all are released when the scene ends.
  - Level shot ids still win where a line names one (wide establishing shots).
- **Voices by emotion:** `gen_voices.py` nudges speed and pitch per line emotion
  (`EMOTION_DELIVERY`).

### Enemies and astras
- **`Rakshasa`** (`characters/enemies/rakshasa/`) is a CharacterBody3D driven by the shared
  StateMachine (Idle, Chase, Telegraph, Recover, Stagger, Dead).
  - Data comes from `EnemyResource`.
  - A static attack-token pool caps simultaneous attackers.
  - Melee blows call `Rama.on_attacked()`, which detects perfect dodges.
- **`RakshasaModel`** reuses the rigged body with a different palette material (region uniforms)
  and plays clips directly on the AnimationPlayer.
- **Astras** are `AstraResource` data.
  - The arrow carries the payload (`Arrow.set_astra`).
  - `Explosion.detonate()` applies falloff damage, `Burn`, knockback and a `FirePatch`, plus the
    VFX and feedback.
- **Spawning:** `WaveSpawner` places enemies before they enter the tree. Characters only treat
  world geometry (layer 1) as moving platforms (`platform_floor_layers = 1`), so nobody rides on
  anyone's head.

### Performance work (measured with 7 characters on screen)
| Change | Draw calls | Triangles |
|---|---|---|
| Before | 859 | 830k |
| `PropBatch` merges props per bone and material; tiny props don't cast shadows | 195 | 434k |
| Generated LODs (`tools/build_rama.gd`) + LOD threshold 2 px + PSSM 2 splits | ~225 | ~127k |

Draw calls are still above the 150 target. The next step is merging the body and hair into one
draw, and rendering outlines only on LOD0.

### Environment (Ayodhya training grounds)
- **Build tool:** `tools/build_ayodhya.gd` deterministically builds
  `kandas/01_bala/env/ayodhya_grounds.scn`. It must run with a real renderer, e.g.
  `xvfb-run godot --rendering-driver opengl3 -s res://tools/build_ayodhya.gd`, because MultiMesh
  instance data lives in the RenderingServer.
- **Static geometry:** merged per region and material. Stone materials share one `arch` draw
  through 0/1 vertex-colour masks.
- **Repeated pieces** are MultiMeshes: pillars, finials, lamps, banners and foliage. Trees outside
  the walls are chunked per side and cast no shadows.
- **Collision:** simple boxes and cylinders on layer 1, plus an invisible wall inside each
  colonnade.
- **Runtime extras:** `kandas/01_bala/env/ambience.gd` (birds, dust). The `Settings` autoload has a
  `low_quality` hook (no ambience or shadows).
- **No lightmaps:** baking needs a GPU, so lighting is real-time with a warm sun, sky ambient and
  fog.
- **Measured** with Rama and six rakshasas in the courtyard (Compatibility renderer, LOD
  threshold 2 px, PSSM2 shadows to 32 m): about 296k triangles and 286 draw calls.
  - Triangles are within mid-range targets; draw calls are high.
  - Next steps: occlusion culling, impostors for the distant tree rows, an atlas for the remaining
    environment materials, and fewer separate character prop draws.

### Combat
- `Health` is a component node with `changed`, `damaged` and `died` signals and an
  `invulnerable` flag (used by Dodge).
- `Arrow` is a ray-swept projectile (no tunnelling at high speed). It damages the first collider it hits that has a `Health` child.
- `AutoAim.find_best_target()` is a pure, static, unit-tested scoring function.
- Future additions: data-driven `AstraResource` and `EnemyResource`, and hitbox/hurtbox layers.

### Physics layers
| Layer | Name |
|---|---|
| 1 | world |
| 2 | player |
| 3 | enemies |
| 4 | projectiles |
| 5 | companions |
| 6 | animals (arrows don't collide; a landing arrow startles them via the `animals` group) |

### Companion AI (Phase 1)
Use a behaviour tree (LimboAI addon) with Follow, Engage and Command (Guard / Attack) branches,
plus NavigationAgent3D for pathing.

### Save system
Saves go to `user://saves/slot_<n>.json` as
`{ "version": 1, "checksum": sha256(payload), "payload": "<json>" }`. The checksum is computed on the
raw payload string, so float/int round-tripping can't break verification. A save that fails its
checksum is rejected. Autosave runs at checkpoints. There are three manual slots. Cloud save will go
through Play Games Services and iCloud later.

### Visual styles (Stylised / Realistic)
- **Settings:** `Settings.visual_style` is saved in `user://settings.cfg` and can be toggled from
  the Journey menu and the pause menu. `--realistic` / `--stylised` override it for testing.
- **`StyleSwitcher`** (in the level) swaps materials by resource path using a stylised → realistic
  map. It covers material overrides, mesh surface materials and MultiMesh surface materials, and
  catches nodes that spawn later. It also swaps the WorldEnvironment and sun, and adds a
  ReflectionProbe. Rakshasas pick their body material per style.
- **Realistic materials:**
  - `stone_pbr` samples texture arrays (sandstone / red sandstone / marble / dark stone) chosen
    by the same 0/1 vertex masks as the toon `arch` material. It uses a world-space
    dominant-axis projection, so each map is one sample.
  - `paving_pbr` keeps the rangoli as an inlay.
  - `character_pbr` reuses the toon palette uniforms.
  - `foliage_pbr` keeps the wind sway.
- **Realistic lighting:**
  - Photographed sunset sky (PanoramaSky with energy multiplier 0.45) rotated so its sun matches
    the directional light
  - Colour ambient for consistent shadow fill on every renderer
  - Filmic tonemap, warm fog
  - No SSAO: unsupported on the Mobile renderer, and it crushed the shadows
- **Cost** (full fight, 7 characters): Realistic is about 261 draw calls and 269k triangles,
  against 286 and 296k for Stylised, because it has no outline passes. It does use more texture
  memory, mostly the 2K HDR sky (~16 MB as RGBA16F).

### Story and missions
- **Dialogue:** `DialogueResource` (`data/dialogue/**`) holds compact `Speaker|shot|action|text`
  lines.
- **Cutscenes:** `Cutscene` draws letterbox bars, typewriter subtitles and Lava–Kusha narration
  cards, and moves level-supplied camera shots. It supports tap-to-advance and Skip; skipping
  still emits every story action.
- **Story levels:** `StoryLevel` locks Rama's controls (`Rama.controls_locked`), hides the HUD,
  stages NPCs and hands off between missions.
- **Missions:** `MissionResource` (`data/missions/part01`) plus `PartFlow`, which resumes from
  `GameState.current_mission`.
- **When story runs:** only when a Part is launched from the Journey menu
  (`GameState.story_session`), so tests and direct scene runs stay deterministic.
- **Cast:**
  - `NpcModel`: shared rig, palette, beard, crown, topknot, staff.
  - `Lakshmana`: a follower on `RamaModel`.
  - `Tataka`: the boss on `RakshasaModel` (weapon NONE, 2.4× scale), with a charge, slam ring,
    `Boulder` projectiles that can be shot down, a maya vanish phase and a stagger meter.
- **Forest:** `tools/build_forest.gd` builds `kandas/01_bala/env/tataka_forest.scn`:
  - a baked path ribbon, ruins, bones, mist, light shafts and spores
  - colliders, a grove gate, and bloom MultiMeshes whose instances grow from metadata targets
    (hidden until the bloom, so they cost nothing before it)
  - **Render cost:**
    - Trees are split into cells so culling and visibility ranges work per cell.
    - Near trees show full detail within 30 m and a proxy mesh beyond. The proxy is the
      bark's coarsest LOD plus a third of the leaf cards, enlarged (`far_mesh`).
    - Shadows come from shadow-only proxy copies.
    - Distant cells end at 85 m, where the fog has them.
    - Path view: about 330k triangles including shadows, down from about 840k.
- **Astras:** `AstraResource.effect` (FIRE / WATER / WIND) drives `Explosion.detonate`. Water
  quenches `FirePatch` and `Burn`; wind is mostly knockback.

### Progression, stars, difficulty
- **Skills:** `SkillResource` (`data/skills/*.tres`) and the `Skills` autoload: `buy()`,
  `mult(key)`, `add(key)`, `flag(key)`.
  - Hooks: `Rama` (draw time, perfect window, cooldowns, pierce, twin, health, Blessing),
    `Explosion` (water radius, burn, wind knockback) and `Lakshmana` (health, downed time, shot
    interval).
  - UI: `ui/skills_screen.gd`, opened from the Journey menu, the pause menu and the summary.
- **Stars:** `MissionResource.star_goals` (`kind[:param]|label`) are scored by `MissionStats`
  (perfect shots, falls, damage, Dharma, level facts).
  - `StoryLevel.complete_mission(n)` records the best stars and shows `MissionSummary`.
  - `MissionsScreen` replays reached missions (`PartFlow.furthest()`).
- **Save v3:** skills, mission_stars, checkpoint, quests, lore. Older saves load with empty
  defaults.
- **Story mode:** `Settings.story_mode` / `difficulty_chosen`.
  - Damage to Rama, Lakshmana and the sacred fire ×0.5 (`incoming_damage_scale`).
  - Enemy health ×0.8; sky bosses ×0.75.
  - Aim-assist cone ×1.6; perfect window +0.2 s.
  - Chosen on first Play (`JourneyMenu.choose_mode`); toggles on the Journey menu and in the
    pause menu.

### Navigation, the Log and thermals
- **Objectives:** `StoryLevel.set_objective(text, target, beacon)` sets the objective line,
  moves a MAIN `NavMarker` onto the target (it follows moving targets) and points a
  `WaypointBeacon` at it.
- **Markers:** `NavMarker` (MAIN, SIDE, PICKUP, EXIT, plus `quest_id`) in the "nav_markers"
  group. PICKUPs show only when near (25 m) or when their quest is tracked (`Quests.tracked`,
  saved in flags).
- **HUD:**
  - `Compass` (bearing maths in `Compass.bar_position`);
  - distances for the objective and the nearest tracked marker only;
  - the side-quest tracker shows only in levels with that quest's markers;
  - the compass hides during boss fights.
- **Map:** `tools/render_map.gd` renders each environment top-down to `assets/maps/*.png` and
  writes `data/maps/*.tres` (`MapResource`: world rect, image path, `other_scenes`).
  - `MapScreen` draws it as parchment (shader), with markers, Rama's arrow and Lakshmana.
  - Pan, pinch or +/- to zoom; tap a quest marker to track it.
- **Log:** `JournalScreen` with Story (missions, current objective, star goals), Side quests
  (Track) and Palm leaves tabs, opened from the HUD and the pause menu.
- **Thermals:**
  - `application/run/max_fps` 60;
  - Mobile FSR `scaling_3d` 0.75, MSAA off;
  - `Settings.quality`: Battery / Balanced / High sets the fps (30/60), render scale
    (0.6/0.75/0.85), FXAA (High), shadow mode and distance, glow, and the particle amounts;
  - `Settings.set_fps_context()`: menus and cutscenes run at 30;
  - HUD group lookups are cached at 0.15 s; rakshasa crowd separation is shared per physics
    tick.
- **Fonts:** the project default is Noto Sans; `PartCard._label` uses Tiro Devanagari Sanskrit
  at title sizes (≥ 34).

### Side quests and the Ayodhya hub
- **Quests:** `QuestResource` (`data/quests`), `LoreResource` (`data/lore`) and the `Quests`
  autoload: start, progress (optional auto-complete), complete with rewards, tracker text.
- **Interaction:** `Interactable` (group "interactables", prompt, radius, glint). The HUD shows
  an Interact button (action `interact`: E / D-pad down) for the nearest one, plus a quest
  tracker line.
- **Journal:** `JournalScreen` (pause menu) lists quests and the palm-leaf codex.
- **Hub:** `kandas/01_bala/ayodhya_hub.tscn` reuses the Ayodhya environment and is mission 2's
  scene.
  - The trials hand off to it; its gate leads to the sage scene (`training_grounds`, mission 2).
  - Practice targets give no Punya there (`TargetDummy.punya_reward`).

### New enemies (Rakshasa variants)
- **Shield-bearer:** `shield`. A `Health.damage_filter` cuts frontal hits to 10%; astras
  (`Health.from_astra`) and flank shots pass. Lakshmana's shove calls `break_shield()`.
- **Mayavi:** `blinks`. Teleports every 3.5–5 s; the first blink conjures 2 `is_decoy`
  copies (1 HP, harmless, no reward, fade after 14 s).
- **Brute:** data only (220 HP, 1.6× scale, stagger threshold 50). Only perfect shots
  stagger it by damage; any astra staggers through `Rakshasa.on_astra`.

### Mission 5: Siddhashrama
- **Environment:** `tools/build_ashram.gd` extends the forest builder (same helpers, tree cells
  and proxies) and writes `kandas/01_bala/env/siddhashrama.scn`. It has:
  - a clearing with the altar at the origin;
  - three spawn lanes (N/W/E) and eight huts (group "huts");
  - sage, spawn and sky markers.
- **Night look:**
  - Stylised: `sky_night.tres`.
  - Realistic: `realistic_night_environment.tres` (Poly Haven `qwantani_moonrise_puresky`).
  - Dawn swaps in the sunset environment.
- **`SacredFire`:**
  - in the "objective" group, with a `Health`, a `reach_radius` (struck at the altar's edge)
    and `on_attacked`;
  - flames and light dim with health;
  - `defiled` triggers a retry.
- **Enemy targeting:** `Rakshasa.target_mode` is PLAYER, NEAREST (Rama or companions) or
  OBJECTIVE.
  - OBJECTIVE raiders turn on whoever hits them.
  - `flat_to_target()` honours `reach_radius`.
- **Hostile fire:** `FirePatch.hostile` and the `Boulder` kinds `fire` and `shard` hurt the
  "player", "companions", "objective" and "bystanders" (the sages, `NpcModel.on_attacked`)
  groups. Varunastra quenches any `FirePatch`.
- **`SkyRakshasa`** (Subahu, Maricha):
  - flies its orbit, volleys, and swoops; only one swoops at a time (static token);
  - Subahu's LAST_STAND makes `Health` invulnerable, and `on_astra()` (called by
    `Explosion.detonate`) lets the Agneyastra kill him;
  - Maricha's YIELDING is invulnerable, and `banish()` is triggered by the BANISH effect
    (`AstraResource.Effect.BANISH`, `manavastra.tres` in Rama's 4th slot, lent with
    `grant_temporary_astra(3)`).
- **Lakshmana:** command FOLLOW, ATTACK or GUARD, plus a DOWNED state.
  - He shoots with `arrow.tscn`.
  - The `companion` action / HUD Command button toggles him.
  - `guard_point` is the fire at Siddhashrama; FOLLOW applies in Vasishtha's trials.
- **Nights:** `NIGHTS` in `siddhashrama.gd` set the waves, fog and lesson per night.
  - `start_night(n)` saves `GameState.checkpoint = "night_n"`; resuming starts there.
  - Night 4 sends melee rakshasas after the sages (OBJECTIVE + `objective_group = bystanders`).
- **Flow:** `StoryLevel.go_to_mission()` shows an end card when the next mission isn't
  released. `say_lines()` speaks in-game exchanges without locking controls.

### Parts (episodic content)
- **Data:** `PartResource` (`core/progress/part_resource.gd`) in `data/parts/*.tres`, listed in
  order by `PartCatalog`.
- **Title screen:** `ui/journey_menu.tscn` is the main scene. It shows one `PartCard` per Part
  with these states: Play/Replay, Buy, Download (with progress), Coming soon.
- **Content packs:** Part 1 is built into the APK. Later Parts ship as `.pck` packs
  (`PartLoader`):
  - downloaded from `ramayana/parts/base_url` into `user://parts/`
  - checked against the size and SHA-256 declared in the `PartResource`
  - mounted with `ProjectSettings.load_resource_pack()`
  - On the stores this maps to Play Asset Delivery and iOS On-Demand Resources.
  - Export a pack with the `Part pack (template)` preset: set its file list to the Part's
    folder, then run `godot --headless --export-pack "Part pack (template)" build/part_NN.pck`.
- **Saves:** version 2 stores `current_part` and `completed_parts`. Version 1 saves migrate from
  `current_kanda` (Yuddha maps to Part 6).

### Chapter gating & IAP
`GameState.is_part_unlocked(part)` checks, in order: the Part is free; the Part's own product
(`Store.owns_product("ramayana_part_NN")`); the Full Journey (`Store.owns_full_journey()`).
- Android uses the official Godot Google Play Billing plugin.
- iOS uses the Godot iOS `InAppStore` plugin.
- Entitlement is restored on launch from the store, not trusted from the local save.

### Performance budget (per frame, mid-range)
| Item | Budget |
|---|---|
| Draw calls | < 150 |
| Visible triangles | < 300k |
| Skinned characters on screen | ≤ 12 (army uses MultiMesh + vertex animation) |
| Particles | ≤ 2k |
| Texture memory | < 600 MB |

Tools: LODs (auto mesh LOD), LightmapGI, occlusion culling, ASTC/ETC2 texture compression.

## Testing

- Unit tests use a lightweight headless runner (`tests/run_tests.gd`) with no third-party
  dependency. GUT can be adopted later if needed:
  ```
  godot --headless --import
  godot --headless -s res://tests/run_tests.gd
  ```
- Each kanda gets a manual QA checklist. The smoke test runs on one low-end and one mid-range device.

## CI (planned)
A GitHub Actions workflow will import the project, run the headless tests, and export debug APKs.
