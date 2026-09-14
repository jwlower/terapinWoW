# Challenges

Ten opt-in challenge modes inherited from Turtle WoW. Each is held as a **known spell**, all
are flagged `CANT_CANCEL`, and they are applied at login from a `PendingChallengeMask`
player variable — so once a character has one, there is no in-game way to drop it.

A GM can remove one, because `HasChallenge` is only `HasSpell`:

```
.unlearn 50008
```

## What they actually do

Every row below was read from this build's source, **not from the tooltip** — several
tooltips describe behaviour that is not implemented here.

| | challenge | spell | status | what the code actually does |
|---|---|---|---|---|
| 0 | **Slow & Steady** | 50000 | ✅ | Kill XP ×0.5 (solo and group). Bypasses the server XP rate multipliers entirely. **−5%** of current-level XP on death. Mails rewards on level-up. |
| 1 | **Exhaustion** | 50004 | ✅ | No rested XP — `SetRestBonus` is forced to 0. **Also doubles weapon skill gain**, which the tooltip never mentions. |
| 2 | **War Mode** | 50008 | ✅ | **+20%** XP from kills, quests and exploration. PvP flag permanently on and unclearable. |
| 3 | **Hardcore** | 50001 | ✅ | The heaviest by far — see below. |
| 4 | **Vagrant's Endeavor** | 50014 | ✅ | Cannot equip above **common** quality until max level. Cannot enchant equipped items. Title *the Wanderer* + mailed rewards at 60. |
| 5 | **Boaring Adventure** | 50071 | ✅ | XP comes only from boars. Title *Swine Slayer* + mailed rewards at 60. |
| 6 | **Traveling Craftmaster** | 57738 | ❌ | **Not implemented.** See below. |
| 7 | **Level One Lunatic** | 57736 | ⚠️ | Partial. Only relaxes level-gated area triggers and quest conditions. |
| 8 | **Path of the Brewmaster** | 57746 | ❌ | **Not implemented.** See below. |
| 9 | **Trial of Heroism** | 57846 | ✅ | No exploration XP. No quest XP unless the quest is at least your level + 3. All XP stops at 58. Title *Hero of Azeroth*. |

### Three of them do nothing here ⛔

- **Traveling Craftmaster** claims *"Equip only what you craft."* There is **no enforcement
  anywhere** in this build. The only reference outside the login table is a line excluding it
  from battleground XP. You can wear whatever you like.
- **Path of the Brewmaster** claims *"You gain no experience unless you're completely
  smashed."* It has **zero** code references outside the login table. It is a title and
  nothing else.
- **Level One Lunatic** does not keep you at level one. Nothing stops XP. What it actually
  does is let you *through* level-gated area triggers and satisfy `CONDITION_LUNATIC` quest
  conditions — it is scaffolding for the challenge, not the challenge.

If you want any of those three to mean something, they need implementing — which is now
straightforward, see [Building more](#building-more).

### War Mode: the tooltip is wrong

It claims **5%** XP, plus battleground XP and reputation bonuses, plus XP for open-world
player kills. Reality: **20%** XP from kills, quests and exploration, and **none** of the
battleground or player-kill parts exist. Since battlegrounds are out of scope here anyway,
War Mode is effectively **+20% XP for a drawback that costs a PvE server nothing** — unless
your friends roll the opposite faction, in which case you are permanently attackable by each
other.

### Hardcore is not just "you die once"

`Player::SetupHardcoreMode` runs the moment you take it, and it is aggressive:

- removes you from your group and cancels all invites
- cancels any trade in progress
- **sets your money to 0**
- **destroys every equipped item worth more than 1 silver**
- strips temporary and permanent enchants from what remains
- restricts your auction house access

Then on death (`Player.cpp:5996`) your status becomes `HARDCORE_MODE_STATUS_DEAD`, a dirge
plays, and you are **disconnected after 120 seconds**. Permanently.

Take it on a fresh character, never on one you care about.

## Suitability for a small-group server

Battlegrounds are out of scope here, so anything hanging off them is dead weight:

| good fit | why |
|---|---|
| **Hardcore** | Works entirely in PvE. The whole point survives intact. |
| **Slow & Steady** | Pure XP maths. Makes a duo last longer. |
| **Vagrant's Endeavor** | Gear restriction, fully enforced, no PvP involvement. |
| **Trial of Heroism** | Forces you into level-appropriate-or-harder content. |
| **Exhaustion** | Mild. And it quietly hands you double weapon skill gain. |

| poor fit | why |
|---|---|
| **War Mode** | Free XP. The drawback does not exist without a PvP population. |
| **Boaring Adventure** | Works, but needs boars to exist at every level band. |
| **Craftmaster / Brewmaster / Lunatic** | Not implemented. |

## Terapin's own challenges ✅

Not part of Turtle's `PendingChallengeMask` system — these are ordinary spells, so they are
**opt-in and reversible**. They will never appear on the character-creation challenge screen:
that list is hardcoded bits in a mask the client sends, with no data table to extend and no
challenge strings in `WoW.exe` at all.

Instead, the **Challenge Master** (creature 2600401) offers them as quests. Summon her with
**Call Challenge Master** (38711), in the General tab:

| quest | | grants |
|---|---|---|
| 80500 | *The Fragile Path* | Fragile (38720) |
| 80501 | *Butterfingers* | Butterfingers (38721) |

To drop one, type `!fragile` or `!butterfingers` in say. The message is swallowed rather
than broadcast.

> **A trainer does not work for these, and the reason was already written down.** From
> `sql/17-salvage.sql`: *"NO skill_line_ability ROW ON PURPOSE... the client drops trainer
> entries filed under no skill line."* Fragile and Butterfingers are General-tab spells with
> no skill line, so a trainer window for them comes up **completely empty** — a trainer and a
> General-tab spell are mutually exclusive on this client.
>
> Turtle solves this for Hardcore the same way: the Mysterious Stranger (81030) is a
> **questgiver**, and quest 80388 carries `RewSpell = 50006`. A quest reward has no
> skill-line requirement.

| spell | | on death |
|---|---|---|
| **38720** | **Fragile** | one random piece of equipped gear falls to your corpse |
| **38721** | **Butterfingers** | 20% of your carried stacks fall to your corpse |

They stack — take both and you drop a piece of gear *and* a share of your bags.

### The chest

Nothing is destroyed. Everything you drop goes into a **Spilled Belongings** chest (GO
2600500) spawned exactly where you died, and only you can open it. Losing gear outright is a
punishment; losing it somewhere you can walk back to is a decision.

Deliberate exclusions in Butterfingers:

- **Bags are never taken.** Losing a 36-slot bag takes everything inside it too, which is a
  far bigger hit than "a fifth of your items".
- **Quest items are never taken.** A bad roll could otherwise hard-block a quest chain with
  no way to recover.

### Two implementation notes worth keeping

**The work happens on release, not on death.** `PLAYER_EVENT_ON_REPOP` (35) is a clean
player-initiated packet; death itself is mid-update, and destroying items there is the exact
lifetime trap that crashed Salvage. Release also guarantees the corpse exists, which is where
the chest goes.

**The contents live in `tw_char.terapin_corpse_chest`, not in a Lua table.** An in-memory
table would lose every pending chest on a server restart, and these are real player items.
The script re-spawns a chest on login for anything still owed, so a restart, a disconnect or
a long walk home cannot eat your gear by accident.

*The click works because `GAMEOBJECT_EVENT_ON_USE` reaches Eluna by an unobvious route. It is
**not** bridged through `ElunaGameObjectScript`, which only forwards AddWorld, RemoveWorld and
Update. `GameObject::Use` (`GameObject.cpp:1496`) calls `sScriptMgr.OnGameObjectUse`, which
forwards to Eluna (`ScriptMgr.cpp:2279`) when no C++ script claims the object.*

## Building more

Everything needed is already available to Eluna — **no core change required**:

| | |
|---|---|
| `PLAYER_EVENT_ON_REPOP` (35) | fires when you release after dying, bridged at `ElunaScriptBridge.cpp:70` |
| `PLAYER_EVENT_ON_KILLED_BY_CREATURE` (8) | fires on the killing blow |
| `Player:GetEquippedItemBySlot(slot)` | walk equipment slots 0–18 |
| `Player:GetItemByPos(bag, slot)` | walk bags |
| `Player:RemoveItem(item, count)` | destroy a specific item |

`Fragile` and `Butterfingers` above are worked examples of exactly this. Ideas that would
now be straightforward:

- **Implement the three dead ones.** Craftmaster needs a check in the equip path (Vagrant's
  Endeavor already shows how); Brewmaster needs a drunk check on XP gain.
- **Durability on death**, since repair is free here and death otherwise costs nothing.
- **Gear loss scaled by how you died** — more from a player kill than a fall.
