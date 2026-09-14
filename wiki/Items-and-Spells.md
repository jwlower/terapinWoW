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
| **90000-90999** | custom items | 166 |

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

### Progression ladders

Two separate ladders, because they are different tiers of content and merging them
hides both. Greens are the designed pieces with stats; whites are the plain
damage-and-speed tier that fills every gap.

#### Green craftables

Stat-carrying pieces. Shields use `item_level - 5` throughout; the older weapons use -5 for Copper and Bronze but -6 above that, and have no Steel tier - both unintended, from generators written separately.

| line | items | required levels |
|---|---|---|
| **Shield** | 1 | 13 |
| **Thrown** | 5 | 5, 20, 32, 46, 57 |
| **Crossbow** | 5 | 5, 20, 32, 46, 57 |
| **Polearm** | 3 | 5, 20, 32 |
| **Fist weapon** | 1 | 46 |
| **Two-hand mace** | 1 | 32 |
| **Bulwark** | 6 | 5, 20, 33, 41, 47, 58 |
| **Wardingshield** | 6 | 5, 20, 33, 41, 47, 58 |
| **Roundshield** | 6 | 5, 20, 33, 41, 47, 58 |

#### White craftables

One per weapon type per 5 levels, required level 5 to 60. No stats: pure damage and speed, on a DPS curve pooled per weapon family so every two-hander of a tier matches.

| line | items | required levels |
|---|---|---|
| **One-hand axe** | 12 | 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60 |
| **Two-hand axe** | 12 | 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60 |
| **One-hand mace** | 12 | 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60 |
| **Two-hand mace** | 12 | 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60 |
| **Polearm** | 12 | 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60 |
| **One-hand sword** | 12 | 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60 |
| **Two-hand sword** | 12 | 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60 |
| **Fist weapon** | 12 | 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60 |
| **Dagger** | 12 | 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60 |
| **Thrown** | 12 | 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60 |
| **Crossbow** | 12 | 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60 |

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
| 90200 | Copper Hatchet | One-hand axe | 10 | 5 |
| 90201 | Heavy Copper Hatchet | One-hand axe | 15 | 10 |
| 90202 | Bronze Hatchet | One-hand axe | 20 | 15 |
| 90203 | Heavy Bronze Hatchet | One-hand axe | 25 | 20 |
| 90204 | Iron Hatchet | One-hand axe | 30 | 25 |
| 90205 | Heavy Iron Hatchet | One-hand axe | 35 | 30 |
| 90206 | Steel Hatchet | One-hand axe | 40 | 35 |
| 90207 | Heavy Steel Hatchet | One-hand axe | 45 | 40 |
| 90208 | Mithril Hatchet | One-hand axe | 50 | 45 |
| 90209 | Heavy Mithril Hatchet | One-hand axe | 55 | 50 |
| 90210 | Thorium Hatchet | One-hand axe | 60 | 55 |
| 90211 | Heavy Thorium Hatchet | One-hand axe | 65 | 60 |
| 90212 | Copper Waraxe | Two-hand axe | 10 | 5 |
| 90213 | Heavy Copper Waraxe | Two-hand axe | 15 | 10 |
| 90214 | Bronze Waraxe | Two-hand axe | 20 | 15 |
| 90215 | Heavy Bronze Waraxe | Two-hand axe | 25 | 20 |
| 90216 | Iron Waraxe | Two-hand axe | 30 | 25 |
| 90217 | Heavy Iron Waraxe | Two-hand axe | 35 | 30 |
| 90218 | Steel Waraxe | Two-hand axe | 40 | 35 |
| 90219 | Heavy Steel Waraxe | Two-hand axe | 45 | 40 |
| 90220 | Mithril Waraxe | Two-hand axe | 50 | 45 |
| 90221 | Heavy Mithril Waraxe | Two-hand axe | 55 | 50 |
| 90222 | Thorium Waraxe | Two-hand axe | 60 | 55 |
| 90223 | Heavy Thorium Waraxe | Two-hand axe | 65 | 60 |
| 90224 | Copper Cudgel | One-hand mace | 10 | 5 |
| 90225 | Heavy Copper Cudgel | One-hand mace | 15 | 10 |
| 90226 | Bronze Cudgel | One-hand mace | 20 | 15 |
| 90227 | Heavy Bronze Cudgel | One-hand mace | 25 | 20 |
| 90228 | Iron Cudgel | One-hand mace | 30 | 25 |
| 90229 | Heavy Iron Cudgel | One-hand mace | 35 | 30 |
| 90230 | Steel Cudgel | One-hand mace | 40 | 35 |
| 90231 | Heavy Steel Cudgel | One-hand mace | 45 | 40 |
| 90232 | Mithril Cudgel | One-hand mace | 50 | 45 |
| 90233 | Heavy Mithril Cudgel | One-hand mace | 55 | 50 |
| 90234 | Thorium Cudgel | One-hand mace | 60 | 55 |
| 90235 | Heavy Thorium Cudgel | One-hand mace | 65 | 60 |
| 90236 | Copper Sledge | Two-hand mace | 10 | 5 |
| 90237 | Heavy Copper Sledge | Two-hand mace | 15 | 10 |
| 90238 | Bronze Sledge | Two-hand mace | 20 | 15 |
| 90239 | Heavy Bronze Sledge | Two-hand mace | 25 | 20 |
| 90240 | Iron Sledge | Two-hand mace | 30 | 25 |
| 90241 | Heavy Iron Sledge | Two-hand mace | 35 | 30 |
| 90242 | Steel Sledge | Two-hand mace | 40 | 35 |
| 90243 | Heavy Steel Sledge | Two-hand mace | 45 | 40 |
| 90244 | Mithril Sledge | Two-hand mace | 50 | 45 |
| 90245 | Heavy Mithril Sledge | Two-hand mace | 55 | 50 |
| 90246 | Thorium Sledge | Two-hand mace | 60 | 55 |
| 90247 | Heavy Thorium Sledge | Two-hand mace | 65 | 60 |
| 90248 | Copper Halberd | Polearm | 10 | 5 |
| 90249 | Heavy Copper Halberd | Polearm | 15 | 10 |
| 90250 | Bronze Halberd | Polearm | 20 | 15 |
| 90251 | Heavy Bronze Halberd | Polearm | 25 | 20 |
| 90252 | Iron Halberd | Polearm | 30 | 25 |
| 90253 | Heavy Iron Halberd | Polearm | 35 | 30 |
| 90254 | Steel Halberd | Polearm | 40 | 35 |
| 90255 | Heavy Steel Halberd | Polearm | 45 | 40 |
| 90256 | Mithril Halberd | Polearm | 50 | 45 |
| 90257 | Heavy Mithril Halberd | Polearm | 55 | 50 |
| 90258 | Thorium Halberd | Polearm | 60 | 55 |
| 90259 | Heavy Thorium Halberd | Polearm | 65 | 60 |
| 90260 | Copper Shortblade | One-hand sword | 10 | 5 |
| 90261 | Heavy Copper Shortblade | One-hand sword | 15 | 10 |
| 90262 | Bronze Shortblade | One-hand sword | 20 | 15 |
| 90263 | Heavy Bronze Shortblade | One-hand sword | 25 | 20 |
| 90264 | Iron Shortblade | One-hand sword | 30 | 25 |
| 90265 | Heavy Iron Shortblade | One-hand sword | 35 | 30 |
| 90266 | Steel Shortblade | One-hand sword | 40 | 35 |
| 90267 | Heavy Steel Shortblade | One-hand sword | 45 | 40 |
| 90268 | Mithril Shortblade | One-hand sword | 50 | 45 |
| 90269 | Heavy Mithril Shortblade | One-hand sword | 55 | 50 |
| 90270 | Thorium Shortblade | One-hand sword | 60 | 55 |
| 90271 | Heavy Thorium Shortblade | One-hand sword | 65 | 60 |
| 90272 | Copper Greatblade | Two-hand sword | 10 | 5 |
| 90273 | Heavy Copper Greatblade | Two-hand sword | 15 | 10 |
| 90274 | Bronze Greatblade | Two-hand sword | 20 | 15 |
| 90275 | Heavy Bronze Greatblade | Two-hand sword | 25 | 20 |
| 90276 | Iron Greatblade | Two-hand sword | 30 | 25 |
| 90277 | Heavy Iron Greatblade | Two-hand sword | 35 | 30 |
| 90278 | Steel Greatblade | Two-hand sword | 40 | 35 |
| 90279 | Heavy Steel Greatblade | Two-hand sword | 45 | 40 |
| 90280 | Mithril Greatblade | Two-hand sword | 50 | 45 |
| 90281 | Heavy Mithril Greatblade | Two-hand sword | 55 | 50 |
| 90282 | Thorium Greatblade | Two-hand sword | 60 | 55 |
| 90283 | Heavy Thorium Greatblade | Two-hand sword | 65 | 60 |
| 90284 | Copper Grips | Fist weapon | 10 | 5 |
| 90285 | Heavy Copper Grips | Fist weapon | 15 | 10 |
| 90286 | Bronze Grips | Fist weapon | 20 | 15 |
| 90287 | Heavy Bronze Grips | Fist weapon | 25 | 20 |
| 90288 | Iron Grips | Fist weapon | 30 | 25 |
| 90289 | Heavy Iron Grips | Fist weapon | 35 | 30 |
| 90290 | Steel Grips | Fist weapon | 40 | 35 |
| 90291 | Heavy Steel Grips | Fist weapon | 45 | 40 |
| 90292 | Mithril Grips | Fist weapon | 50 | 45 |
| 90293 | Heavy Mithril Grips | Fist weapon | 55 | 50 |
| 90294 | Thorium Grips | Fist weapon | 60 | 55 |
| 90295 | Heavy Thorium Grips | Fist weapon | 65 | 60 |
| 90296 | Copper Dirk | Dagger | 10 | 5 |
| 90297 | Heavy Copper Dirk | Dagger | 15 | 10 |
| 90298 | Bronze Dirk | Dagger | 20 | 15 |
| 90299 | Heavy Bronze Dirk | Dagger | 25 | 20 |
| 90300 | Iron Dirk | Dagger | 30 | 25 |
| 90301 | Heavy Iron Dirk | Dagger | 35 | 30 |
| 90302 | Steel Dirk | Dagger | 40 | 35 |
| 90303 | Heavy Steel Dirk | Dagger | 45 | 40 |
| 90304 | Mithril Dirk | Dagger | 50 | 45 |
| 90305 | Heavy Mithril Dirk | Dagger | 55 | 50 |
| 90306 | Thorium Dirk | Dagger | 60 | 55 |
| 90307 | Heavy Thorium Dirk | Dagger | 65 | 60 |
| 90308 | Copper Throwing Knife | Thrown | 10 | 5 |
| 90309 | Heavy Copper Throwing Knife | Thrown | 15 | 10 |
| 90310 | Bronze Throwing Knife | Thrown | 20 | 15 |
| 90311 | Heavy Bronze Throwing Knife | Thrown | 25 | 20 |
| 90312 | Iron Throwing Knife | Thrown | 30 | 25 |
| 90313 | Heavy Iron Throwing Knife | Thrown | 35 | 30 |
| 90314 | Steel Throwing Knife | Thrown | 40 | 35 |
| 90315 | Heavy Steel Throwing Knife | Thrown | 45 | 40 |
| 90316 | Mithril Throwing Knife | Thrown | 50 | 45 |
| 90317 | Heavy Mithril Throwing Knife | Thrown | 55 | 50 |
| 90318 | Thorium Throwing Knife | Thrown | 60 | 55 |
| 90319 | Heavy Thorium Throwing Knife | Thrown | 65 | 60 |
| 90320 | Copper Handbow | Crossbow | 10 | 5 |
| 90321 | Heavy Copper Handbow | Crossbow | 15 | 10 |
| 90322 | Bronze Handbow | Crossbow | 20 | 15 |
| 90323 | Heavy Bronze Handbow | Crossbow | 25 | 20 |
| 90324 | Iron Handbow | Crossbow | 30 | 25 |
| 90325 | Heavy Iron Handbow | Crossbow | 35 | 30 |
| 90326 | Steel Handbow | Crossbow | 40 | 35 |
| 90327 | Heavy Steel Handbow | Crossbow | 45 | 40 |
| 90328 | Mithril Handbow | Crossbow | 50 | 45 |
| 90329 | Heavy Mithril Handbow | Crossbow | 55 | 50 |
| 90330 | Thorium Handbow | Crossbow | 60 | 55 |
| 90331 | Heavy Thorium Handbow | Crossbow | 65 | 60 |

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
