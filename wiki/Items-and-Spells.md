# Items and Spells

**This page is generated** by `content/gen_wiki_catalogue.py` from `spell_template` and
`item_template`. Re-run it after adding content rather than editing it by hand.

## ID allocation

Custom IDs live in reserved blocks so they never collide with Turtle's own content.

| block | used for | count |
|---|---|---|
| **38000-38099** | Misc abilities and their trainers | 4 |
| **38100-38199** | Class specialization abilities | 54 |
| **38300-38399** | Blacksmithing weapon recipes | 30 |
| **38400-38499** | Thrown abilities | 4 |
| **38500-38599** | Blacksmithing shield recipes | 36 |
| **38600-38699** | Universal utility spells | 2 |
| **90000-90999** | custom items | 34 |

> ### The hard ceiling ⛔
> **Custom spell IDs must stay below 60000.** `SMSG_INITIAL_SPELLS` packs the player's
> whole spellbook as 16-bit values, so anything above 65535 wraps: the server thinks it
> told the client about your spell, the client is told about a completely different one,
> and **neither side reports an error**. A second limit, `MAX_SPELL_ID` 60000, makes
> `Spell::cast` return silently above it. Use the 38000-38999 block.

## Custom spells

Rows marked *teacher* are `SPELL_EFFECT_LEARN_SPELL` wrappers. A trainer entry cannot
point at an ability directly - `npc_trainer.spell` must be a teaching spell whose trigger
is the real ability - so every trainable ability needs a pair.

### Misc abilities and their trainers (38000-38099)

| id | name | | what it does |
|---|---|---|---|
| 38000 | **Expeditious Retreat** |  | Increases movement speed by $s1% for $d. The effect ends if you attack. |
| 38001 | **Expeditious Retreat** | *teacher* | Teaches Expeditious Retreat. |
| 38002 | **Runed Copper Shield** |  | Forges a Runed Copper Shield. |
| 38003 | **Runed Copper Shield** | *teacher* | Teaches you how to make a Runed Copper Shield. |

### Class specialization abilities (38100-38199)

27 abilities + 27 teachers. **All 27 are still placeholder test content** - see
[Classes](Classes). The mechanism (one ability per spec, filed on its own
spellbook tab) is proven; the content is not written.

| id | ability | current placeholder effect |
|---|---|---|
| 38100 | Arms Buff | Strength by 5 points |
| 38101 | Fury Buff | Agility by 5 points |
| 38102 | Protection Buff | Stamina by 5 points |
| 38103 | Holy Buff | Intellect by 5 points |
| 38104 | Protection Buff | Spirit by 5 points |
| 38105 | Retribution Buff | Strength by 5 points |
| 38106 | Beast Mastery Buff | Agility by 5 points |
| 38107 | Marksmanship Buff | Stamina by 5 points |
| 38108 | Survival Buff | Intellect by 5 points |
| 38109 | Assassination Buff | Spirit by 5 points |
| 38110 | Combat Buff | Strength by 5 points |
| 38111 | Subtlety Buff | Agility by 5 points |
| 38112 | Discipline Buff | Stamina by 5 points |
| 38113 | Holy Buff | Intellect by 5 points |
| 38114 | Shadow Magic Buff | Spirit by 5 points |
| 38115 | Elemental Combat Buff | Strength by 5 points |
| 38116 | Enhancement Buff | Agility by 5 points |
| 38117 | Restoration Buff | Stamina by 5 points |
| 38118 | Arcane Buff | Intellect by 5 points |
| 38119 | Fire Buff | Spirit by 5 points |
| 38120 | Frost Buff | Strength by 5 points |
| 38121 | Affliction Buff | Agility by 5 points |
| 38122 | Demonology Buff | Stamina by 5 points |
| 38123 | Destruction Buff | Intellect by 5 points |
| 38124 | Balance Buff | Spirit by 5 points |
| 38125 | Feral Combat Buff | Strength by 5 points |
| 38126 | Restoration Buff | Agility by 5 points |

### Blacksmithing weapon recipes (38300-38399)

15 recipes + 15 teachers. The crafted items are listed under
[Custom items](#custom-items).

### Thrown abilities (38400-38499)

| id | name | | what it does |
|---|---|---|---|
| 38400 | **Heavy Throw** |  | Hurls your thrown weapon with great force, causing weapon damage plus $s1. Requires a thro |
| 38403 | **Crippling Throw** |  | Hurls your thrown weapon at the target's legs, causing weapon damage plus $s1 and slowing  |
| 38410 | **Heavy Throw** | *teacher* | Teaches Heavy Throw. |
| 38412 | **Crippling Throw** | *teacher* | Teaches Crippling Throw. |

### Blacksmithing shield recipes (38500-38599)

18 recipes + 18 teachers. The crafted items are listed under
[Custom items](#custom-items).

### Universal utility spells (38600-38699)

| id | name | | what it does |
|---|---|---|---|
| 38600 | **Salvage** |  | Breaks a weapon or piece of armour down into raw materials. Better items yield more. The i |
| 38601 | **Strongbox** |  | Opens your bank from anywhere. |

## Custom items

Every one is **crafted by Blacksmithing** - none drop. Quality is uncommon (green)
throughout: the stat budgets are deliberately modest so craftables do not outclass quest
rewards of the same level.

### Progression ladder

Shield required levels are derived as `item_level - 5`, consistent across all three
shapes. **Weapons are not consistent with them**: Copper and Bronze use -5, but Iron,
Mithril and Thorium use -6, so a weapon unlocks one level before the shield of the same
item level. Harmless, but unintended - the two generators were written separately and
only shields were later given an explicit rule.

**Weapons also have no Steel tier.** Steel was added to the shield line and never
back-filled to weapons, which is why that column is empty for them below.

| line | Copper | Bronze | Iron | Steel | Mithril | Thorium |
|---|---|---|---|---|---|---|
| **Thrown** | lvl 5 | lvl 20 | lvl 32 | — | lvl 46 | lvl 57 |
| **Crossbow** | lvl 5 | lvl 20 | lvl 32 | — | lvl 46 | lvl 57 |
| **Polearm** | lvl 5 | lvl 20 | lvl 32 | — | — | — |
| **Fist weapon** | — | — | — | — | lvl 46 | — |
| **Two-hand mace** | — | — | lvl 32 | — | — | — |
| **Bulwark** | lvl 5 | lvl 20 | lvl 33 | lvl 41 | lvl 47 | lvl 58 |
| **Wardingshield** | lvl 5 | lvl 20 | lvl 33 | lvl 41 | lvl 47 | lvl 58 |
| **Roundshield** | lvl 5 | lvl 20 | lvl 33 | lvl 41 | lvl 47 | lvl 58 |

### Full list

| id | item | type | ilvl | req |
|---|---|---|---|---|
| 90100 | Runed Copper Shield | Shield | 18 | 13 |
| 90120 | Copper Throwing Blade | Thrown | 10 | 5 |
| 90121 | Bronze Throwing Blade | Thrown | 25 | 20 |
| 90122 | Iron Throwing Blade | Thrown | 38 | 32 |
| 90123 | Mithril Throwing Blade | Thrown | 52 | 46 |
| 90124 | Thorium Throwing Blade | Thrown | 63 | 57 |
| 90125 | Copper Crossbow | Crossbow | 10 | 5 |
| 90126 | Bronze Crossbow | Crossbow | 25 | 20 |
| 90127 | Iron Crossbow | Crossbow | 38 | 32 |
| 90128 | Mithril Crossbow | Crossbow | 52 | 46 |
| 90129 | Thorium Crossbow | Crossbow | 63 | 57 |
| 90130 | Copper Pike | Polearm | 10 | 5 |
| 90131 | Bronze Pike | Polearm | 25 | 20 |
| 90132 | Iron Pike | Polearm | 38 | 32 |
| 90133 | Mithril Claw | Fist weapon | 52 | 46 |
| 90134 | Iron Maul | Two-hand mace | 38 | 32 |
| 90140 | Copper Bulwark | Shield | 10 | 5 |
| 90141 | Bronze Bulwark | Shield | 25 | 20 |
| 90142 | Iron Bulwark | Shield | 38 | 33 |
| 90143 | Steel Bulwark | Shield | 46 | 41 |
| 90144 | Mithril Bulwark | Shield | 52 | 47 |
| 90145 | Thorium Bulwark | Shield | 63 | 58 |
| 90146 | Copper Wardingshield | Shield | 10 | 5 |
| 90147 | Bronze Wardingshield | Shield | 25 | 20 |
| 90148 | Iron Wardingshield | Shield | 38 | 33 |
| 90149 | Steel Wardingshield | Shield | 46 | 41 |
| 90150 | Mithril Wardingshield | Shield | 52 | 47 |
| 90151 | Thorium Wardingshield | Shield | 63 | 58 |
| 90152 | Copper Roundshield | Shield | 10 | 5 |
| 90153 | Bronze Roundshield | Shield | 25 | 20 |
| 90154 | Iron Roundshield | Shield | 38 | 33 |
| 90155 | Steel Roundshield | Shield | 46 | 41 |
| 90156 | Mithril Roundshield | Shield | 52 | 47 |
| 90157 | Thorium Roundshield | Shield | 63 | 58 |

## Changes to vanilla content

Existing spells and items that were altered rather than added. These matter more than the
new content, because they change things players already know.

| what | change | why |
|---|---|---|
| **Battle Shout** | 2 min → **10 min** duration | Re-buffing every two minutes is pure friction for a duo. Needed `DurationIndex` changed on **both** sides: the client builds tooltips from its own `Spell.dbc`, so a server-only change left it still reading "2 min". |
| **Mining / Herbalism / Skinning** (17 ranks) | castable while mounted | One bit, `SPELL_ATTR_CASTABLE_WHILE_MOUNTED`, set on **both** sides so you stay mounted. |
| **All other spells** (27,534) | castable while mounted, **client side only** | The divergence is the feature: the client sends the cast, the server dismounts you and fires it. Adding the matching SQL would break it. |
| **Smelting** (high tiers) | real skill-up bands | Mithril dead-ended mid-tier; it now carries you to 230 before greying. |
| **Mage teleports** (8) | granted to every class, level 1, free, no reagent | Travel time is not the interesting part of the game. |
| **Every stackable item** | 99 stacks | |
| **Every bag** | capacity doubled, capped at 36 | 36 is a hard core limit: the container slot list is a fixed 72-field block. |
| **Bank bag slots** | all 6 open, and free to unlock | |
| **All gear** | no durability loss, no repair | A wipe should cost time, not gold. |
| **Boss loot** | +2 guaranteed rare-or-better | |
| **Dungeon bosses** | respawn, no 7-day lockout | The lockout is *derived* from the respawn time - see [Dungeons](Dungeons). |
| **Recipes** (635) | show the icon of the item they make | Every custom recipe previously showed the same generic face. |
| **1,991 world objects** | usable while mounted | Chests via a core change, the other 948 via `allowMounted`. |
| **Riding** | trainable at 20, not 40 | A server-side DBC edit (`patch-riding-level.py`); **re-run it after any DBC re-extraction**, which silently restores the level 40 gate. |

## Why things were changed

The through-line is **party size**. Vanilla assumes five people and an unlimited calendar;
these changes assume one to four people and a couple of evenings a week. Anything that
existed only to consume a fifth player's time, or to slow a guild down, got shortened.

What deliberately did **not** change:

- **Stat budgets on craftables.** Modest on purpose - 3 to 12 split over two stats - so
  crafted greens do not outclass quest rewards of the same level. Making everything trivial
  is not the goal.
- **Raid content.** Untouched, and it will feel wrong at this party size.
- **Item quality.** Every custom item is uncommon. No custom epics.

## Adding new content

Three rules, each learned the expensive way:

1. **Spell IDs below 60000**, from the 38000-38999 block. Above 65535 they are silently
   truncated to `uint16` and arrive as a different spell, with no error on either side.
2. **Every trainable spell needs a `skill_line_ability` row.** Without one the client
   silently drops the trainer entry while the server looks perfectly healthy. The row is also
   what files the spell on a spellbook tab; with none it lands in General.
3. **Clone teaching spells from a real trainer wrapper** such as 2754 - never from a `Plans:`
   spell. Those are cast by the recipe *item* and target the caster, so a trainer using one
   teaches **itself** the recipe instead of teaching you.

Full pipeline details are in the [README](../blob/main/README.md#making-changes).
