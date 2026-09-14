# Spell ID range — the hard ceiling, and why

**Every custom spell in this mod must have an ID below 60000. Use the reserved block 38000-38999.**

This is not a style preference. Two independent limits sit above us, and the first one
fails *silently*, which is what made it expensive to find.

## Limit 1 — the 1.12 wire protocol packs spell IDs as uint16

`Player::SendInitialSpells` (game/Objects/Player.cpp:4270) writes the player's whole
spellbook as 16-bit values:

```cpp
data << uint16(spell.first);       // <-- spell id, TRUNCATED
data << uint16(0);                 // it's not slot id
```

Anything above 65535 wraps. The server thinks it told the client about our spell; the
client is told about a completely different one, and neither side reports an error.

This is exactly what we hit. The observed symptoms were not two separate mysteries:

| we used | & 0xFFFF | client actually received      | symptom the player reported             |
|---------|----------|-------------------------------|-----------------------------------------|
| 90200   | 24664    | **Sleep**                     | "a new general spell called sleep?"     |
| 90201   | 24665    | (no such spell)               | nothing appeared                        |
| 90202   | 24666    | Increase Frost Dam 132        | shield recipe never showed in Blacksmithing |
| 90203   | 24667    | Increase Frost Dam 72         | —                                       |

The Blacksmithing window is built from the player's known spells, so the craft spell was
truncated the same way and the recipe could never appear. One root cause, both symptoms.

## Limit 2 — the core refuses to cast above MAX_SPELL_ID

`game/Spells/Spell.h:42` defines `MAX_SPELL_ID 60000`, and `Spell::cast`
(game/Spells/Spell.cpp:3778) bails out before doing anything:

```cpp
if (m_spellInfo->Id <= 0 || m_spellInfo->Id > MAX_SPELL_ID)
    return;                        // no error, no message, no cast
```

So even if the spellbook packet were widened, a spell above 60000 still could not be cast.

## What is NOT limited

- **Item IDs are fine above 65535** — items travel as uint32. Item 90100 (Runed Copper
  Shield) displayed correctly the whole time, which is why the shield was visible at a
  vendor while its recipe was not.
- `spell_template` loading is fine — `mSpellEntryMap` is a vector sized from
  `MAX(entry)`, so the row loads and `.lookup spell` finds it. Loading is not the problem;
  *reaching the client* is.

## The reserved block

`38000-38999` is verified free in the client's `Spell.dbc` (the largest free run under
60000 is 37100-40000, 2901 ids). Currently allocated:

| id    | what                                        |
|-------|---------------------------------------------|
| 38000 | Expeditious Retreat (the ability)           |
| 38001 | Expeditious Retreat (teacher, LEARN_SPELL)  |
| 38002 | Runed Copper Shield (craft)                 |
| 38003 | Plans: Runed Copper Shield (teacher)        |

Before allocating a new id, confirm it is free on **both** sides — the client DBC and
`spell_template` — because they do not hold the same set.

## Corroboration

The same ceiling is reported upstream in celguar/spp-classics-cmangos#368, where custom
spells at 45000/50000/150000 produced "random unknown spells" in the spellbook and the
maintainer's answer was to stay below the core's max spell id.
