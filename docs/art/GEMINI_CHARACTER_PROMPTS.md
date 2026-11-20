# Character prompts for image-to-3D (Bala Kanda cast)

Recipe that worked for Rama: one clean FRONT picture per character, then Tripo "image to 3D"
(textured, standard quality, about 10,000 triangles if it asks, A-pose), download `.glb`.
Send me the `.glb` and the picture. Names in brackets are the file names I expect.

## Use in the SAME Gemini chat as Rama (so the style matches)
Attach the clean Rama picture (`09b_rama_front_clean`) to every prompt and paste this block first:

```
Use the attached Rama picture only as the STYLE reference (same stylised 3D-game render, same soft
cel shading, same colour richness, same level of detail, same proportions of a real adult or youth
of that age). New character below. Full body from head to bare feet, perfectly straight-on front
view, symmetrical, standing in a relaxed A-pose: arms hanging about 30 degrees away from the body,
hands EMPTY with fingers slightly apart, palms toward the thighs, feet slightly apart. Nothing
held, no bow, no staff, no weapon, no shield. Plain flat light-grey background, no shadow on the
ground, no text, no watermark. Clothing close to the body and legs clearly visible (nothing that
hides the legs or merges the arms into the torso). Portrait 3:4.
```

Then paste ONE character below per message. Ask for 4 variants and keep the best.

## Bala Kanda cast, in priority order

### 1. Lakshmana  [lakshmana]
```
Character: Lakshmana, Rama's younger brother, about fifteen, slightly broader and more intense
than Rama, warm light-brown skin, black hair in a topknot with two short side-locks, a small gold
earring each side, a watchful protective expression. Bare chest with a white-and-gold sash across
one shoulder, white dhoti with a gold waist band, gold armlets and bracelets. Same road look as
Rama, no crown.
```
### 2. Vishvamitra  [vishvamitra]
```
Character: the sage Vishvamitra, tall, lean and fierce, a former king turned ascetic, long
grey-black beard, matted hair in a topknot, sharp eyes, weathered dark-tan skin. Deep ochre robe
wrapped round the body and tied at the waist (ending above the ankles), a bare shoulder, a sacred
thread, a rudraksha bead necklace. Not holding anything.
```
### 3. Vasishtha  [vasishtha]
```
Character: Guru Vasishtha, elderly royal preceptor, long white beard and white matted hair in a
high topknot, thin kind weathered face, calm authority. Saffron-and-white robe wrapped at the waist
(ending above the ankles) and a white upper cloth over one shoulder, a sacred thread, rudraksha
beads. Not holding anything.
```
### 4. Dasharatha  [dasharatha]
```
Character: King Dasharatha of Ayodhya, an aged but strong king, grey beard, dignified tired eyes,
medium-brown skin. Rich cream silk dhoti with a gold border, a deep crimson upper cloth over one
shoulder, gold necklace, armlets and bracelets, a tall tiered gold crown with a ruby. Regal and
gentle. Not holding anything.
```
### 5. Tataka  [tataka]
```
Character: Tataka, a gigantic cursed yakshini turned man-eating rakshasi, towering and heavily
built, dark grey-green skin, a fierce wide face with two small tusks, wild matted black hair,
bangles of bone and dark iron on arms, a tattered dark-red cloth wrapped at the waist, menacing but
not gory. Taller and broader than a normal person. Claws open, no weapon.
```
### 6. Maricha  [maricha]
```
Character: Maricha, a rakshasa warrior, lean and powerful, grey-brown skin, small curved tusks,
matted hair tied back, gold earrings, dark armour plates on chest and shoulders, dark cloth kilt,
cunning cruel expression. Hands empty.
```
### 7. Subahu  [subahu]
```
Character: Subahu, a rakshasa warrior, heavy and brutal, dark grey skin, two thick tusks, shaved
head with a topknot of coarse hair, red war paint on the face and chest, a dark-red kilt, iron
bangles. Hands empty.
```
### 8. Ahalya  [ahalya]
```
Character: Ahalya, a woman of radiant, ageless beauty after years of penance, serene and sorrowful,
long dark hair loose behind her, a simple pale saffron-cream sari with a thin gold border, the
pallu over one shoulder, no jewellery except a thin gold bangle. The calm, luminous air of a sage's
wife. Hands empty.
```
### 9. Gautama  [gautama]
```
Character: the sage Gautama, middle-aged ascetic, stern and austere, a short grey-black beard,
matted hair in a topknot, lean body, a plain white cotton dhoti and a bare chest with a sacred
thread, rudraksha beads. Hands empty.
```
### 10. Sumati  [sumati]
```
Character: Sumati, the dignified king of Vishala, middle-aged, short black beard, kind firm face,
teal-and-gold silk dhoti and a cream upper cloth over one shoulder, a small gold crown band,
gold armlets. Hands empty.
```
### 11. Townsman  [townsman]
```
Character: a townsman of Ayodhya, ordinary middle-aged man, clean-shaven, simple white dhoti and a
saffron shoulder cloth, bare feet, a simple head cloth. Hands empty.
```
### 12. Townswoman  [townswoman]
```
Character: a townswoman of Ayodhya in an elegant teal sari with a gold border, the pallu over one
shoulder, hair in a bun with jasmine flowers, simple gold jewellery, graceful and dignified.
Hands empty.
```
### 13. Gate guard  [guard]
```
Character: an Ayodhya palace guard, strong disciplined man, crimson-and-gold knee-length tunic with
a white sash, a plain gold-trimmed cap, bare calves, sandals. Hands empty.
```

## Later (Mithila, end of the Bala Kanda)
### 14. Sita  [sita]
```
Character: Sita, a young woman of about eighteen, gentle and strong, large lotus-shaped dark eyes,
long dark braid, a sunlit yellow-and-green silk sari with a gold border and the pallu over one
shoulder, simple gold jewellery. Hands empty.
```
### 15. Janaka  [janaka]
```
Character: King Janaka of Videha, a wise sage-king, grey beard, calm eyes, white-and-gold silk
dhoti, a saffron upper cloth, a simple gold crown band, a rudraksha necklace. Hands empty.
```
### 16. Rama, crowned  [rama_crowned]
Same prompt as Rama but add: "wearing a tall tiered gold kireeta crown with a lotus crest and a
ruby at the front". Generate it separately; do not mix with the road-look Rama.

## Tripo settings and checks
1. Image to 3D, one picture at a time. Face/body detail "standard"; textured ON; PBR OFF if there is
   a switch (I only use the colour texture; it keeps the file small).
2. Spin it round: reject results with fused legs, fused arms, a missing hand or a melted face.
3. Download `.glb`. A 15 MB file is fine; I shrink it to about 1 MB.
4. Large figures (Tataka) are fine at any size: I scale them.

## Before anything ships
Check Google's commercial-use terms for the Gemini pictures and your Tripo plan's terms (both are in
`docs/OWNER_TODO.md`, item 22).
