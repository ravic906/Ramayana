# Canon reference: the Valmiki Ramayana

The game follows the **Valmiki Ramayana, popular recension** (the version most Indians know).
This folder is the reference every scene, level, character, object and lore leaf is checked
against. It is working material for the cultural consultant and the team, **in our own words**;
short quotations come from a public-domain translation (R. T. H. Griffith, 1870-74).

## How to cite
- **`Griffith <canto>`**: the canto number in Griffith's translation (Wikisource edition), e.g.
  `Griffith XX`. This is what has been read and checked.
- **`pop <sarga>`**: the usual sarga number in Gita Press / popular editions, e.g. `Bala 20`.
  Griffith's numbering runs a little off the popular one in places (the sacrifice and birth
  cantos are split differently), so popular numbers are **given only where checked** and are
  otherwise marked `pop ?`.
- In data files (`canon` fields) write both when known: `Bala 20 (Griffith XXII)`.

## Status marks
- **verified**: read in the translation, citation given.
- **to verify**: from memory or a later tradition; not yet checked. Treat as provisional.
- **invented**: added by the game; must not contradict any verse; listed in `ADDITIONS.md`.
- **variant**: another recension or tradition tells it differently (Kamba, Tulsidas, Krittivasi,
  the critical edition).

## Rules (standing)
1. Every mission, scene, dialogue, level, character, object and lore leaf cites its canon
   (`canon` field) or is marked `invented`.
2. **Descriptions of people and places come from here.** Art briefs and visual choices cite this
   reference; a departure needs a reason written under *Variants*.
3. **Additions** are allowed if labelled `invented` and consistent with every verse; each is
   listed in `ADDITIONS.md` for the consultant.
4. **Before a new Part is designed,** its kanda file is written here first.
5. Where editions differ, the popular recension wins; the difference is noted for the lore codex.

## Files
| File | State |
|---|---|
| `01_bala_kanda.md` | complete: Griffith I-LXXVII read (cantos XXXVII-XXXVIII omitted by Griffith) |
| `ADDITIONS.md` | started |
| `AUDIT_PART1.md` | planned (after the Bala file is complete) |
| `02_ayodhya` ... `07_uttara` | written just before each Part is designed |

## Sources
- R. T. H. Griffith, *The Ramayan of Valmiki* (1870-74), English Wikisource transcription of the
  1895 edition; it has OCR errors, so check quotations against the scan before publishing.
- Canto numbering differs from the popular edition; the Gita Press text was not available to read.
- **Limit:** this is careful desk research, not a scholar's review. The consultant reviews it
  before release.
