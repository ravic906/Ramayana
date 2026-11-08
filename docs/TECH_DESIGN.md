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
kandas/          Per-kanda scenes; 01_bala/greybox.tscn is the prototype level
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

### Companion AI (Phase 1)
Use a behaviour tree (LimboAI addon) with Follow, Engage and Command (Guard / Attack) branches,
plus NavigationAgent3D for pathing.

### Save system
Saves go to `user://saves/slot_<n>.json` as
`{ "version": 1, "checksum": sha256(payload), "payload": "<json>" }`. The checksum is computed on the
raw payload string, so float/int round-tripping can't break verification. A save that fails its
checksum is rejected. Autosave runs at checkpoints. There are three manual slots. Cloud save will go
through Play Games Services and iCloud later.

### Chapter gating & IAP
`Store.owns_full_game()` gates kandas 2–7 through `GameState.is_kanda_playable()`.
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
