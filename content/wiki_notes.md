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
