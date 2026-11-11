# Quality bar

This is a serious, devotional retelling. **Every aspect must be top-notch.** Nothing light,
playful or dance-like: not in the music, the voices, the text, or the effects. Anything subjective
that tests can't verify (music, voices, pronunciation, the look of a face) goes in front of the
owner before it ships.

## Standing rules
- **Music:**
  - Orchestral or choral, cinematic, solemn.
  - `tools/fetch_music.py` refuses any track whose catalogue mood includes Grooving, Bouncy,
    Humorous, Bright, Quirky, Silly or Funky.
  - Every cue is chosen by the owner from an audition reel.
- **Voices:** every Sanskrit name is checked in a pronunciation reel and fixed in
  `gen_voices.py`'s `PRONOUNCE`.
- **Faces:** every close-up is checked in a render before it ships; expressions stay
  restrained (no cartoon extremes on Rama or the sages).
- **Rama** is calm, dignified, never the source of humour; divine figures are never trivialised
  (`docs/STORY.md`).
- **Typography:**
  - Tiro Devanagari Sanskrit for titles; Noto Sans for everything else (project default font).
  - No glyph-dependent symbols; stars and swatches are drawn.
- **Performance and heat:**
  - 60 fps cap (30 in menus, cutscenes and Battery saver).
  - FSR-upscaled 3D at 0.6/0.75/0.85, no MSAA.
  - No per-frame group scans.
- **Layout:** the HUD is checked at 20:9 and 4:3. Touch targets are at least 64 px; nothing
  overlaps.

## Audit log

| Area | Finding | Status |
|---|---|---|
| Heat | No fps cap; native-resolution 3D with MSAA; per-frame group scans | Fixed: caps, FSR, presets, cached lookups (CPU in the siege 2.15 → 1.85 ms/frame) |
| Music | *Vadodora* (trials fights) and *Hidden Wonders* (forest) are dance/groove pieces; *The Curtain Rises* is "Bright" | Removed; interim *Strength of the Titans*, *Oppressive Gloom*, *Our Story Begins*; owner auditions all scenes |
| Text | Rama's quip on the fifth night ("fell it like one") | Rewritten: "Size is not strength, brother. Stand with me." |
| Fonts | Engine default font everywhere | Tiro Devanagari Sanskrit (titles) + Noto Sans (body), OFL |
| Navigation | No mission log, objectives, map or compass | Log (Story / Side quests / Palm leaves), objectives per level, compass, beacon, parchment map |
| Layout | Subtitles overlapped Dodge on 4:3 | Narrowed |
| Voices | Pronunciation unverified | Reel sent to the owner; awaiting corrections |
| Faces | No facial expressions; dialogue lacks close-ups | Face rig with blend shapes, blinking lids and turning eyes; lip sync; emotions per line; automatic close-ups, over-the-shoulder and two-shots with depth of field and a key light. Interim until a character artist's heads (owner, item 4) |
| Hair | Stock long loose cut fell over the princes' faces | Gathered into the crown after temple iconography: face and ears open, dark locks behind to the shoulders; sages, the king and rakshasas keep the long hair |
| Rama | Bucket-shaped crown; plain skin | A tall tapered kireeta with a lotus crest; a subtle luminous skin (Rama only) |
| Dialogue | Scenes are brief | *Sage at the Gate* told in full after Valmiki (20 lines); the trials, forest, Tataka, Siddhashrama and dawn scenes deepened, each line with an emotion |
| Animals | The pack is low-poly and flat-shaded (toy-like beside the cast) | Welded and smooth-shaded, life-sized, colours muted; never harmed (arrows pass them; near arrows startle) |
| Boatman's name | "Guha" would clash with the Nishada king of Ayodhya Kanda | Left unnamed |
| Mouth | Interior poked through the chin in the idle pose | Interior made smaller and set deeper; checked in a close-up render |
| Score | Licensed placeholders | A commissioned score (Indian classical + orchestra + choir) is the goal for launch |
