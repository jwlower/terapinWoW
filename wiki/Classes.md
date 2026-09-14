# Classes

## Current state — read this first 🧪

**There are no real class changes yet.** What exists is the *scaffolding*, fully proven:

- 27 abilities, one per class specialization, each correctly filed on its **own spellbook
  tab** — Arms, Fury, Protection, and so on for all nine classes.
- Each is trainable from that class's master NPC.
- Each is gated to the right class and appears in the right place.

But every one of them is still the **test** content. Their descriptions read, literally:

> *"This is the Arms test custom spell. Buffs Strength by 5 points."*

They buff one stat by 5, cycling Strength → Agility → Stamina → Intellect → Spirit down the
list regardless of whether that stat suits the spec. Holy priests get Intellect by
coincidence, not design.

**So: the hard part is done and the content is not.** Replacing a placeholder is a
`spell_template` edit plus a `content.py` entry — no new mechanism required. See
[Items and Spells](Items-and-Spells#class-specialization-abilities-38100-38126).

### Why the scaffolding was the hard part

It was initially assumed vanilla had no per-specialization spellbook tabs. That is wrong —
`SkillLine.dbc` carries **62 category-7 class specialization lines**, and `MAX_SKILLLINE_TABS`
is 8. Filing a spell under one of those puts it on the right tab.

Two traps, both of which fail *silently*:

- **A spell with no `skill_line_ability` row is dropped by the client** while the server looks
  perfectly healthy. No error either side. That row is what puts it on a tab at all; without
  one it lands in General.
- **Spell IDs must stay under 60000.** `SMSG_INITIAL_SPELLS` packs them as `uint16`, so
  anything above 65535 is truncated and the client is told about a completely different
  spell. Use the reserved **38000–38999** block.

## Per class

<details>
<summary><b>Warrior</b> — the only class with real content</summary>

| | |
|---|---|
| **Expeditious Retreat** (38000) ✅ | Escape ability. Increases movement speed; ends if you are attacked. Trainable. |
| **Heavy Throw** (38400) ✅ | Thrown attack, on the **Fury** spellbook tab. Custom icon art. |
| **Crippling Throw** (38403) ✅ | Thrown attack that slows, on the **Fury** tab. Custom icon art. |
| **Battle Shout** ✅ | Now lasts **10 minutes** instead of 2. |
| Arms / Fury / Protection Buff 🧪 | Placeholder. |

Thrown abilities are tied to the **spellbook tab**, not to talents — you do not have to spend
points in Fury to get them.

*Removed:* Twin Throw (38401) — its double `TRIGGER_SPELL` misbehaved.
</details>

<details>
<summary><b>Paladin</b></summary>

Holy / Protection / Retribution Buff (38103–38105) 🧪 — placeholder only.
</details>

<details>
<summary><b>Hunter</b></summary>

Beast Mastery / Marksmanship / Survival Buff (38106–38108) 🧪 — placeholder only.

Relevant elsewhere: a **Pet Master** NPC (2600209) combines pet trainer and stable master.
</details>

<details>
<summary><b>Rogue</b></summary>

Assassination / Combat / Subtlety Buff (38109–38111) 🧪 — placeholder only.

🟨 **Planned:** thrown abilities on the **Combat** tab, mirroring the warrior Fury pair. The
mechanism is already proven by 38400/38403 — this is content, not engineering.
</details>

<details>
<summary><b>Priest</b></summary>

Discipline / Holy / Shadow Magic Buff (38112–38114) 🧪 — placeholder only.
</details>

<details>
<summary><b>Shaman</b></summary>

Elemental Combat / Enhancement / Restoration Buff (38115–38117) 🧪 — placeholder only.

🟨 **Planned: totems as relics.** Totem spells currently need a totem *item* in your bags.
The intent is to drop that requirement and make totems **equippable relics** in the slot
shamans otherwise waste on a ranged weapon. Confirmed possible on this build — `INVTYPE_RELIC`
is handled at `Player.cpp:10494` and 65 items already use it. See the roadmap.
</details>

<details>
<summary><b>Mage</b></summary>

Arcane / Fire / Frost Buff (38118–38120) 🧪 — placeholder only.

Note: the mage **teleports are no longer a mage perk** — all eight are granted to every class
at level 1, free and reagentless. See [General Changes](General-Changes#convenience).
</details>

<details>
<summary><b>Warlock</b></summary>

Affliction / Demonology / Destruction Buff (38121–38123) 🧪 — placeholder only.

Relevant elsewhere: a **Demon Master** NPC (2600210) handles demon training.
</details>

<details>
<summary><b>Druid</b></summary>

Balance / Feral Combat / Restoration Buff (38124–38126) 🧪 — placeholder only.
</details>

## Class trainers ✅

One master NPC per class, summonable, offering training **and** quests:

| entry | NPC | | entry | NPC |
|---|---|---|---|---|
| 2600200 | Warrior Master | | 2600205 | Shaman Master |
| 2600201 | Paladin Master | | 2600206 | Mage Master |
| 2600202 | Hunter Master | | 2600207 | Warlock Master |
| 2600203 | Rogue Master | | 2600208 | Druid Master |
| 2600204 | Priest Master | | 2600209 | Pet Master *(pet trainer + stable)* |
| | | | 2600210 | Demon Master |

All are cloned from a friendly, level 1, no-flags base so they are safe anywhere. Talent
resets are **free, anywhere and self-service** (`setup-rbac-players.sql`) — you do not need a
trainer for them.
