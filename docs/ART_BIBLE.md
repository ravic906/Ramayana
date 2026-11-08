# Art Bible

## Direction

**Stylized 3D inspired by Indian temple sculpture and Rajput/Pahari miniature painting.**
Characters are shaped with the clean, idealised proportions of temple sculpture. The world is lit
and coloured like a miniature painting: flat, rich colour fields, gold ornament, and a soft
painted sky.

Keywords: *luminous, devotional, heroic, painterly, readable.*

## Palette

| Use | Colour | Hex |
|---|---|---|
| Rama (skin, key accents) | Deep blue | `#2B4C8C` |
| Royal / divine accents | Saffron | `#F28C28` |
| Ornament, astras | Gold | `#D4A63A` |
| Forest (Dandaka, Siddhashrama) | Leaf green | `#3E7B4F` |
| Lanka | Crimson / obsidian | `#8C1C2B` / `#1E1A24` |
| Sky (day) | Miniature-painting cream-blue | `#BFD8E8` |

Each kanda has its own palette key (Ayodhya: cream and gold; Aranya: deep greens; Lanka: crimson
and black-gold) so players can tell chapters apart at a glance.

## Shading

- A toon/cel shader with 2–3 light bands and a soft rim light.
- An inverted-hull ink outline on characters, with thinner outlines on props.
- Gold surfaces use a matcap-style sheen that stays cheap on mobile.
- Astra VFX use additive, hand-painted flipbooks plus geometric mandala motifs.

## Characters

| Character | Silhouette cue | Notes |
|---|---|---|
| Rama | Tall bow (Kodanda), crown, blue skin, yellow dhoti | Calm, regal posture, never comedic |
| Lakshmana | Bow and sword, fair, lighter armour | Protective stance, a step behind Rama |
| Sita | Flowing saree, lotus motifs | Grace and strength |
| Hanuman | Mace (gada), tail, broad shoulders | Devotional and powerful |
| Ravana | Ten heads, golden armour, Pushpaka motifs | Grand and intimidating, never cartoonish |

**Budgets:** hero characters about 15k triangles with one 2k texture set. Enemies about 5k
triangles with a 1k texture set. Bosses up to 25k triangles.

## Environments

- Modular kits per region: Ayodhya palace, forest hermitage, Kishkindha rocks, Lanka fortress.
- Baked lightmaps. Use vertex-colour variation rather than unique textures.
- Foliage drawn with MultiMesh and wind animated in the shader.

## UI

- Palm-leaf and parchment textures with gold filigree frames.
- The type pairs a Devanagari-inspired display face with a clean, highly legible sans for body text.
  Every launch script (Latin, Devanagari, Telugu, Tamil) must be supported.
- Touch targets are at least 9 mm (about 64 px at 1080p), and thumb zones stay clear.

## Audio

- Instruments: bansuri, veena, sitar, mridangam, tabla and chorus.
- Music is adaptive, with an exploration layer and a combat layer.
- Voice over is in each launch language. Rama's voice is measured and calm.
