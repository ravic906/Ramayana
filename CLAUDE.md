# Project rules (read first)

**Ramayana: The Journey of Rama**: a mobile 3D game in Godot 4.7. Rama is the only playable
hero. Serious tone, top quality in every aspect.

## The Valmiki canon rule (standing)
The game follows the **Valmiki Ramayana, popular recension**. The reference is `docs/canon/`
(start with `README.md`; the Bala Kanda is `01_bala_kanda.md`).
- Descriptions of **people, places, objects and events** come from the reference. Cite it in art
  briefs, dialogue and design notes.
- Every mission, scene (dialogue), quest and lore leaf has a `canon` field (e.g.
  `Griffith XX-XXIII`) **or** `invented = true`. `tests/unit/test_canon.gd` enforces it.
- Additions are allowed **only if** labelled `invented`, consistent with every verse, and listed
  in `docs/canon/ADDITIONS.md`.
- **Before designing a new Part, write its kanda file in `docs/canon/` first**, read against the
  text (public-domain Griffith on Wikisource), in our own words; mark entries *verified* or
  *to verify*.
- Where tellings differ, the popular recension wins; note the difference for the lore codex.

## Working agreements
- Keep `docs/OWNER_TODO.md` ("With you") up to date and summarise it in every report.
- Develop on the branch the session names; no pull requests unless asked.
- Run the tests (`godot --headless -s res://tests/run_tests.gd`) before committing.
