# Terapin WoW — Roadmap

A Turtle WoW (1.12) server rebuilt around a **solo and small-group** experience, with
crafting as the spine of progression rather than an afterthought.

Everything below is annotated with what it actually costs to build on this core, because
the features differ enormously in that respect and it is not obvious from the outside.

---

## Status legend

| tag | meaning |
|---|---|
| ✅ **Live** | built and running |
| 🟩 **Data** | SQL + client DBC only. The existing generator pipeline handles it |
| 🟨 **Eluna** | needs server-side Lua scripting. Each of these is a small project |
| 🟥 **Core** | needs C++ changes and a rebuilt `mangosd` |
| ⛔ **Blocked** | cannot work as originally specified — see the note |

The distinction that matters most: **🟩 is hours, 🟨 is days, 🟥 is a rebuild plus a
regression hunt.** Eluna is not yet enabled on the live server (see *Prerequisites*).

---

## Prerequisites

Two pieces of groundwork gate a lot of the list.

### Eluna — 🟥 then unlocks 🟨

Eluna is in the source and `BUILD_ELUNA` is ON by default, but the running server is a
**2026-08-23 prebuilt with no Lua engine**. Verified directly: 0 Eluna symbols in the live
binary, 11 in a build that has it.

The catch is that Eluna merged on **2026-08-31**, inside the window where creatures stopped
chasing players. So no existing build has both working chase and scripting. The fix is a
`git bisect` over ~48 commits to find the regression, then build with Eluna on.

Until that lands, every 🟨 item is blocked.

### Content pipeline — ✅ Live

Already built and proven:

- `Spell.dbc`, `SkillLineAbility.dbc`, `SpellIcon.dbc` and arbitrary files packed into
  `patch-6.mpq`
- PNG → BLP2 icon conversion written from scratch (no external tool)
- A cross-check that fails loudly if the server and client halves ever disagree

**Hard constraint:** custom spell IDs must stay below 60000. Higher IDs are silently
truncated to 16 bits and arrive at the client as a completely different spell.

---

## Major changes

### Stacking — ✅ Live
All items that can stack now stack as high as possible.

### Gathering yield — ✅ Live
2× on herb, ore and cloth.

### Drop rates — ✅ Live *(tuned down from the original plan)*

| quality | multiplier |
|---|---|
| grey | 1× |
| white | 1.5× |
| uncommon | 1.25× |
| rare / epic / legendary | 2× |

The original "+50% on uncommon and above" was tried and **reverted**. The problem was not
the multiplier but a 1% *floor* applied per loot row: creatures carry hundreds of green rows
across several loot groups, so flooring each one guaranteed roughly three greens per kill.
The multiplier alone is fine; a floor on a large pool is not.

### Class-aware boss loot — 🟨 Eluna

> Bosses drop one of their rare items, uniquely, based on the classes present.

Loot rolls from static tables with no knowledge of who is in the group, so this needs a
script. The biggest single item in this document, and the most distinctive.

**Design notes**
- Roll the boss's normal table first, then substitute or append a class-appropriate item
- Fall back to "a good item per party member + 1" when the boss has nothing for that class
- Needs a class→item mapping per boss; largely derivable from existing loot plus armour type
  and stat weights

---

## Auto-scaling — ⛔ Blocked as specified, 🟨 achievable in a narrower form

> On entry to a dungeon with a level 18, 33 and 45, mobs scale so each player gains XP.

**This cannot work.** A creature has one level and one health pool. It cannot be level 18 for
one player and level 45 for another simultaneously, and no amount of scripting changes that.

Worked example with the real XP formula — a 27-level spread has no solution:

| mob level | lvl 18 sees | lvl 45 sees |
|---|---|---|
| 20 | fair fight | **grey — zero XP** (grey cut-off is 35) |
| 35 | **one-shot** | green, partial XP |
| 45 | unsurvivable | full XP |

**What is achievable:** scale the instance **once on entry**, to a level derived from the
group. That works well for the realistic duo/trio case of a 3-5 level spread, and is a
reasonable 🟨 feature.

**Recommendation:** promise *"dungeons scale to your group"* rather than *"every player is
individually challenged"*, and lean on the XP formula's own tolerance — a level 45 still
earns from anything above level 35.

---

## Crafting

### Non-exclusive specializations — 🟩 Data
All weaponsmith masteries, both goblin and gnomish engineering, learnable together. The
exclusivity is enforced by spell and quest gating that can be removed.

### Batch crafting — 🟨 Eluna (🟥 for true instancing)
Select a quantity, the possible skill-ups are pre-rolled, and the whole batch completes at
the end of one animation.

Vanilla already has a "create all" that repeats the cast. The *pre-calculated, single
animation* version needs scripting; making it genuinely instant may need core work.

### Salvaging — 🟨 Eluna
Break gear back down into bars, leather or cloth.

Disenchant is a real spell effect with its own loot tables; salvage is not, so it needs a
script that inspects the item and returns materials scaled by quality and item level.

| item quality | returns |
|---|---|
| white | 0-2 |
| green | 1-5 *(scaled by item value)* |
| blue | 2-6 *(scaled by item value)* |

Higher tiers also refund cloth, leather and gems. Instant, not channelled — players will do
this in bulk.

---

## Professions

### Alchemy — 🟩 Data
- A potion for every stat at every tier
- Utility potions from common trade drops: beast tracking, treasure detection, attack speed
  at the cost of spirit
- **Transmutation chains** — each ore tier converts up to its valuable counterpart (copper →
  silver, iron → gold, mithril → truesilver). Same for gems, herbs, leather and cloth.
  Typically 5:1, tightening to 3:1 at higher tiers
- Weapon oils using enchanting residuals: chance to cast fireball, leech health, extra
  attack, refund a spell; fire damage at the cost of frost (mage only)

### Blacksmithing — 🟩 Data

Measured coverage today, by item level band:

| type | white | green | blue+ | total |
|---|---|---|---|---|
| plate | 0 | 38 | 55 | 93 |
| mail | 5 | 54 | 33 | 92 |
| **shields** | **0** | **2** | **2** | **4** |
| 1H sword | 2 | 4 | 7 | 13 |
| fist | 1 | 3 | 2 | 6 |
| polearm | 0 | 3 | 3 | 6 |
| thrown / crossbow | 0 | 5 / 5 | 0 | 10 ✅ |

*(No white plate is correct, not a gap — plate is not wearable until 40, by which point
green is the floor.)*

**Shields are the worst hole in the profession — four items in total.** Three per tier
across six tiers closes it:

- **all metal** — warrior/paladin, including intellect and spirit variants for healers
- **leather + metal** — shaman, intellect with spell damage or healing
- **wood + metal** — mixed

**Weapons** — every type at every tier. Polearms, fist weapons, daggers, 1H/2H maces, axes
and swords, plus crossbows (overlapping Survival for wood and rope) and thrown. White
variants from bars and grindstones; green variants later in each tier using leather,
grindstones, gems and a common trade drop.

Stat themes: polearms, fist weapons and daggers lean agility; maces, axes and swords mix
strength and agility; two-handers split between warrior and paladin support.

**Masterwork upgrade** — the capstone of each tier. Consumes one of each gem of the tier, a
large quantity of leather and bars, the tier's valuable bar, and a common mob trade drop.
Lifts the target item to roughly mid-next-tier quality.

**Upgrade and reforging kits** — from bronze onward, at every tier.

**Already covered — do not duplicate:**
- **Skeleton keys** — Silver, Golden, Truesilver and Arcanite, one per precious metal
- **Sharpening stones and weightstones** — a full chain to item level 60 (Rough, Coarse,
  Heavy, Solid, Dense, Elemental). The single gap is an **Elemental Weightstone**, which has
  no ilvl 60 counterpart to the Elemental Sharpening Stone

**Quest rewards as recipes** — Whirlwind Axe and similar become learnable rather than
one-time awards.

### Enchanting — 🟩 Data
- An enchant for every gear slot and weapon at every tier
- A new wand type per tier. Arcane wands are cheap; other damage types need gems, ore,
  potions, herbs or leather
- Enchants for every stat including block and hit. Narrow effects (damage to beasts,
  humanoids, demons) hit harder but need rare, thematic materials
- **Instant disenchant**, and all materials stack to maximum
- A **random-enchant recipe** per tier, applying an "of the Animal"-style suffix appropriate
  to that tier

### Engineering — 🟩 Data, 🟨 for the zanier effects
- More bombs per tier, most not requiring Engineering to use, more instant-cast
- Elemental bombs using alchemy reagents — frost oil for a bomb that roots via Frost Nova
- Mechanical companions beyond combat: a healbot built from healing potions that funnels
  health until destroyed
- Mines that slow, bombs that silence, resistance totems, ammunition with damage types
- Goblin/gnomish: borrowed spells with a chance of catastrophic failure, more
  transformations, augmentations that add on-use effects to common items — **🟨, these need
  scripting**

### Leatherworking — 🟩 Data
- **Bags** — a large general bag per tier plus gathering-specific bags
- **Leather upgrading** — light → medium and so on, as each tier's capstone; hides rip into
  their common leather
- **Shields** from leather and wood — shaman-focused, two per tier minimum, also paladin
- **Masterwork** items, as Blacksmithing
- **Cloaks** for leather and mail wearers, plus strength cloaks for warriors and paladins
- **Salvaging** leather gear back into leather and, rarely, hides — 🟨

### Tailoring — 🟩 Data
- Masterwork items, overlapping alchemy, jewelcrafting and enchanting for caster materials
- Bags, and the **ropes** Survival depends on, as a basic item at each tier
- Cloaks for cloth wearers and paladin healers
- Salvaging cloth gear back into bolts — 🟨

### Survival — 🟩 Data, 🟨 for wood XP
- **Gathering wood grants XP** and works with any axe or the tool type — 🟨, XP for gathering
  is not a data-level feature
- More bows per tier, hunter-focused; some strength bows that hit hard, wanted by melee
  hunters
- Staves as a generalist weapon — damage casters, healers, and strength/agility users
- On-hit effects: trips and stuns, slows, parry for warriors and hunters

### Cooking — 🟩 Data, 🟨 for feasts
- **Feasts** — a placeable object party members click for a timed stamina and spirit buff — 🟨
- Campfire variants granting cooking and stat bonuses
- Expanded well-fed buffs
- **Drinks**, and a new **Slaked** buff: rage and energy generation, mana regen, and higher
  maximum rage, energy and mana
- **Pet foods** buffing armour, attack speed, strength, agility, mana and movement speed
- Movement-speed drinks per tier
- Resistance and poison-immunity food

### Fishing — 🟥 Core
- **No bobber click.** When the timer ends you get the item; clicking at the right moment
  guarantees a fish. Below-level fishing still returns grey trash but raises skill
- Floating wreckage scales with fishing skill — pearls become reliably obtainable

Bobber interaction is client behaviour as much as server, so this is the most expensive item
in the document relative to its size. Worth deferring until Eluna is settled.

### First Aid — 🟨 Eluna
- **Patches** built from healing, mana, rage and energy potions. Applied out of combat as an
  hour-long buff; consumed automatically when the relevant resource drops below a threshold
  in combat

Health thresholds are borderline expressible in spell data; mana, rage and energy are not.

---

## Suggested order

1. **Bisect the chase regression and build with Eluna** — gates everything 🟨
2. **Shields** — the clearest gap, pure data, generator already exists
3. **Blacksmithing weapon tiers** — the largest 🟩 win
4. **Alchemy transmutes and the potion/oil matrix** — high value, low cost
5. **Class-aware boss loot** — the most distinctive feature, first real Eluna project
6. **Salvaging and batch crafting** — the quality-of-life pair that makes crafting the spine
7. **Instance scaling**, scoped to group rather than per-player
8. **Fishing**, last — most expensive, least dependent on anything else
