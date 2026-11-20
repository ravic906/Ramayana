# Gemini art prompts: Mission 1 (Ayodhya training grounds)

How to use: open a **new Gemini chat**, paste the **STYLE BLOCK** once, then paste one asset
prompt at a time in the same chat so the style stays consistent. Ask for **4 variants**, pick
the best, say "keep this exact style" for the next asset. Send me the PNGs at the highest
resolution Gemini gives you (name them as in the headings, e.g. `01_gate_front.png`).

Before anything ships in the paid game: check Google's current terms for commercial use of
generated images, and have a lawyer glance at it. Keep every prompt and output in the repo
(`assets/art_source/`) as the record of how each piece was made.

Descriptions follow our canon reference (`docs/canon/01_bala_kanda.md`, Valmiki Bala Kanda):
Ayodhya has high walls, many gates and towers, wide streets laid out like a chessboard, sal
trees and gardens; Rama is dark and luminous ("lustrous dark", the colour of a rain cloud or
blue lotus), lotus-eyed, long-armed, about sixteen, with hair in side-locks like a raven's
wing; he carries a bow and quiver.

---

## STYLE BLOCK (paste first, once per chat)

```
You are my concept artist for a premium mobile action game based on the Valmiki Ramayana.
Keep ONE consistent style for every image I ask for in this chat:
- Stylised 3D-game concept art, polished and painterly, in the spirit of Genshin Impact and
  Clash of Clans: clean shapes, soft cel shading, rich saturated colour, crisp edges,
  no film grain, no blur, no noise, no text, no watermark, no signature, no UI.
- Tone: serious, reverent, noble, never cartoonish or comical.
- Palette: deep blue clear-day sky; warm ivory-white marble and sandstone; gold with a
  glossy highlight; crimson, teal and saffron accents; soft violet-blue shadows.
- Lighting: bright warm sun from the upper left, soft shadows.
- Indian temple architecture (Nagara style): tiered curved spires with small corner spires,
  gold finials and kalasha, saffron flags with a golden sun emblem, carved pillars,
  jharokha balconies, scalloped arches.
Always follow the framing, background and aspect ratio I specify. If I do not say otherwise,
use a plain flat light-grey background.
```

---

## 01_gate_front.png: the gate hall, straight-on elevation

```
Front elevation, perfectly straight-on and symmetrical, of the royal gate hall of Ayodhya:
a tall central hall with a curved tiered spire and gold finial and a saffron flag, two
smaller spires stepping down on each side, a pillared porch with six carved crimson pillars,
a broad ceremonial stair with an elephant statue on each side, a high crenellated fort wall
joining round bastion towers with golden domes at both ends. White marble with gold trim,
crimson and teal tile bands. Orthographic view, no perspective, centred, full building in
frame, plain flat light-grey background, 16:9.
```

## 02_gate_three_quarter.png: the same gate in perspective (key image)

```
The same gate hall of Ayodhya seen from a low three-quarter angle across a paved courtyard
with a round inlaid medallion (crimson, teal and gold rings, lotus petals) in the foreground,
deep blue sky with soft white clouds, golden afternoon light, a few marigold petals drifting.
Grand, serene and sacred. 16:9.
```

## 03_skyline_layers.png: distant backdrop (three horizontal layers)

```
A seamless horizontal panorama of distant Ayodhya for a game backdrop: layered silhouettes
of temple spires, domes, tall sal trees and low hills fading into soft blue haze, three
depth layers (far pale, middle medium, near richer colour), deep blue clear sky above with
soft clouds. Flat, no foreground, left and right edges must match so it tiles seamlessly.
Wide 4:1.
```

## 04_courtyard_floor_top.png: floor from directly above

```
Top-down view, perfectly overhead, of a courtyard floor of large cream-and-sand marble
slabs with clear thin grout lines and a large inlaid circular medallion in the centre
(concentric rings of crimson, teal and gold, sixteen lotus petals, a saffron eight-point
star). Flat even lighting, no shadows, no perspective. Square 1:1.
```

---

## Seamless textures (ask for "seamless tileable, flat lighting, top-down, square 1:1")

### 05_tex_marble.png
```
Seamless tileable texture: polished ivory-white marble with faint blue-grey veins, subtle
soft painterly variation, flat even lighting, no shadows, no perspective. Square 1:1.
```
### 06_tex_gold.png
```
Seamless tileable texture: hammered polished gold with a soft glossy sheen and tiny dents,
warm yellow-orange, flat even lighting. Square 1:1.
```
### 07_tex_cloth.png
```
Seamless tileable texture: fine woven saffron-orange cotton cloth with a gold printed
border of small lotus motifs along the top and bottom edge, flat lighting. Square 1:1.
```
### 08_tex_carving.png
```
Seamless tileable texture: carved ivory sandstone relief band of lotus petals above a row of
beads above a row of small dentils, lit softly from above so the carving reads clearly,
horizontally tileable. 4:1.
```

---

## Characters (for 3D: front, side and back; **one character per image sheet**)

For all characters add: "Character turnaround sheet on a plain flat light-grey background:
front view, side view and back view side by side, same scale, neutral relaxed A-pose,
arms slightly away from the body, even soft studio lighting, full body head to feet,
no motion blur, no text. 16:9."

### 09_rama_turnaround.png
```
Rama as a noble sixteen-year-old prince, tall and graceful with long arms, dark luminous
skin like a blue lotus or rain cloud, large lotus-shaped eyes, calm serious expression,
black hair gathered in a topknot with two short side-locks like a raven's wing, a small gold
earring each side. Bare chest with a crimson-and-gold sash across one shoulder, saffron-gold
dhoti with a gold waist band, gold armlets and bracelets, a leather guard on the left
forearm, a short sword at the left hip, a quiver of arrows on the back, a great bow in the
left hand. Version 1: road look (no crown). 
```
### 10_rama_crowned.png
```
The same Rama, same face and clothes, but wearing a tall tiered gold kireeta crown with a
lotus crest and a ruby at the front, for scenes at court. Front view and three-quarter view.
```
### 11_lakshmana_turnaround.png
```
Lakshmana, Rama's younger brother: same noble style as Rama but slightly broader and more
intense, lighter warm-brown skin, black hair in a topknot with two side-locks, simple gold
earrings, bare chest with a white-and-gold sash, white dhoti with a gold waist band, bow and
quiver, a watchful, protective expression.
```
### 12_vasishtha_turnaround.png
```
Guru Vasishtha, an elderly royal sage: long white beard and white matted hair in a high
topknot, thin kind weathered face, saffron robe with a white sacred thread and rudraksha
beads, a wooden staff, calm authority.
```
### 13_vishvamitra_turnaround.png
```
Sage Vishvamitra: tall, lean and fierce, long grey-black beard and matted hair in a topknot,
sharp eyes, deep ochre robe, rudraksha beads, a water pot (kamandalu), a staff, the bearing
of a former king turned ascetic.
```
### 14_guard_turnaround.png
```
Ayodhya gate guard: strong man in a crimson-and-gold tunic with a white sash and a plain
gold-trimmed cap, a tall spear with a saffron pennant, a round shield, calm and disciplined.
```
### 15_townswoman_turnaround.png
```
Townswoman of Ayodhya in an elegant teal sari with a gold border and pallu, hair in a bun
with jasmine flowers, simple gold jewellery, graceful and dignified.
```
### 16_rakshasa_turnaround.png
```
A rakshasa warrior for the maya trials (an illusion conjured by the sage): grey-green skin,
heavy muscular build, small curved tusks, matted black hair, crimson loincloth, wooden club,
menacing but not gory.
```

---

## Props (single object, centred, plain background, "three-quarter view, soft studio light")

### 17_prop_archery_target.png
```
Archery target on a wooden stand: round straw target with concentric red, white and blue
rings, a small saffron flag on top, three arrows stuck near the centre.
```
### 18_prop_banner.png
```
Tall flag pole with a swallow-tailed saffron banner bearing a golden sun emblem (the solar
dynasty), gold finial on top, banner flowing gently.
```
### 19_prop_lamp.png
```
Tall gold ceremonial oil-lamp post with a lotus-shaped base, a bowl on top with a bright
steady flame, glossy gold with soft glow.
```
### 20_prop_planter.png
```
Carved white-marble planter with marigold flowers and green leaves, gold rim, small lotus
carvings on the sides.
```
### 21_prop_elephant_statue.png
```
Marble elephant statue on a square plinth, gold-and-crimson ceremonial cloth, gold tusk
caps, noble and calm, facing forward.
```

---

## Key art and interface (last, once the style is settled)

### 22_title_art.png
```
Key art: Rama standing at the gate of Ayodhya at golden hour with his bow, seen from below,
the white-and-gold gate hall and saffron flags behind him, deep blue sky, sacred and heroic,
space at the top for a title. 16:9.
```
### 23_ui_frame.png
```
Game interface frame elements on a flat grey background: a rounded rectangular panel with a
gold border and ivory fill, a round gold button with a crimson gem, a long horizontal health
bar frame with gold ends, a small square icon frame, all in the same style, no text.
```

---

## What I do with them
- Backdrops and skylines become scrolling layers behind the courtyard.
- Marble, gold, cloth and carving become tiled textures on the level.
- Character sheets go to a text-to-3D tool (Meshy, Tripo or Rodin), then I clean, rig and
  animate the result in the game.
- Props become models (or flat cut-outs) in the level.
- Key art and interface frames go in the title screen, menus and HUD.
