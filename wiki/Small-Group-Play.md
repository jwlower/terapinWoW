# Small Group Play

The design target is **one to four players**. Battlegrounds and playerbots are deliberately
out of scope — that trade was made on purpose, to spend the effort here instead.

This page collects the changes whose *reason for existing* is party size. Each is described
in full on its own page; this is the argument that ties them together.

## The four problems with playing vanilla short-handed

### 1. You cannot field a full group, so content gates you out

| | |
|---|---|
| **Boss loot doubled** | Two guaranteed rare-or-better drops per boss, so a duo still gears up. |
| **Bosses respawn** | You can re-clear rather than waiting a week for four other people. |
| **No lockouts** | Killing a boss no longer stamps a 7-day instance reset. |
| **Dungeon questgivers** | One NPC per dungeon offers and accepts all of its quests. |

See [Dungeons](Dungeons).

### 2. Nobody else is around to cover the roles you lack

| | |
|---|---|
| **Free talent reset** | Anywhere, self-service, for every player. Respec to cover a missing role. |
| **Class masters** | One per class, summonable, training and quests. |
| **Pet / Demon masters** | Dedicated NPCs so pet classes are not hunting specific trainers. |
| **No repair** | A wipe costs time, not money — there is no guild bank behind you. |
| **Free teleports** | All eight, every class, level 1. Getting somewhere is not the interesting part. |

### 3. Nobody else is around to supply you

| | |
|---|---|
| **Supplier NPC** | Every vendor-sold reagent and profession tool in one summonable vendor. |
| **Profession masters** | One per profession — trainer, supplies and quests together. |
| **Rank cap fixed** | Professions no longer stall at 75. |
| **Salvage** | Universal and free, so gear you cannot sell becomes materials you can use. |
| **Masters teach ranks** | No hunting for the one trainer who sells the next rank. |

See [Professions](Professions).

### 4. Everything takes longer with fewer hands

| | |
|---|---|
| **2× gathering**, whole node in one loot | Less time per material. |
| **99 stacks**, doubled bags, 4×36 starting bags | Fewer trips back to town. |
| **Strongbox** | Bank from anywhere — 240 slots without the trip. |
| **Gather while mounted** | No dismount-remount cycle on every node. |
| **Riding at 20** | Half the levelling done at mount speed. |
| **Drop rates tuned down** | Less time vendoring junk. |

See [General Changes](General-Changes).

## Loot that works for two people

The boss-loot change is worth explaining, because the obvious implementation is a trap.

`LootTemplate::LootGroup::Roll` (`LootMgr.cpp:1151`) ends with:

```cpp
if (!ExplicitlyChanced.empty()) { ...roll, maybe return... }
if (!EqualChanced.empty())
    return &EqualChanced[irand(0, EqualChanced.size() - 1)];
return nullptr;
```

Rows with `ChanceOrQuestChance = 0` land in `EqualChanced`. A group made **entirely** of
chance-0 rows has an empty `ExplicitlyChanced` list, so the first block is skipped and the
second **always** returns something.

That is a guaranteed drop, uniformly chosen, with no arithmetic — no making chances sum to
exactly 100, and no risk of the cumulative-overflow bug that silently kills entries past the
100 mark. Two such groups, two guaranteed items, each a random rare-or-better from that
boss's own table.

## What small-group play still cannot have ⛔

Stated plainly so nobody spends a weekend on it:

- **Mobs scaling to party size.** One creature is one level. There is no per-observer level
  in this core.
- **Arenas.** There is no arena system in 1.12.
- **Bots to fill out a group.** Dropped deliberately; the playerbot module also turned out to
  be a red herring in a long-running chase-behaviour bug.

The narrower, achievable version of the first is 🟨 tuning a specific dungeon's creatures
outright — which changes them for everyone, not per player.
