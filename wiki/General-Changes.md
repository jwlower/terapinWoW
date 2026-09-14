# General Changes

Everything that isn't combat, class or profession specific. All of it is data, applied by
the numbered migrations in [`db/`](../tree/main/db).

## Inventory and storage ✅

| | | source |
|---|---|---|
| **Stacking** | Every stackable item raised to a **99** stack. | `tuning-stack-sizes.sql` |
| **Bag capacity** | Every bag's capacity **doubled**, capped at 36. | `tuning-bag-sizes.sql` |
| **Starting bags** | Every new character starts with **four 36-slot** Loremaster's Backpacks, equipped. | `tuning-starting-bags.sql` |
| **Bank bag slots** | All **6** bank bag slots unlocked, and free to buy for new characters. | `tuning-bank-slots.sql` + `patch-bank-slot-prices.py` |
| **Strongbox** (38601) | Opens your bank **from anywhere**. Free, level 1, General tab. | `22-strongbox.sql` |

### Why the backpack is still 16 slots ⛔

It is not an item, so there is no field to change. It is a fixed range of player update
fields, and the bank begins immediately after it with no gap:

```
INVENTORY_SLOT_BAG_START  = 19,  INVENTORY_SLOT_BAG_END  = 23   <- 4 bag slots
INVENTORY_SLOT_ITEM_START = 23,  INVENTORY_SLOT_ITEM_END = 39   <- the backpack
BANK_SLOT_ITEM_START      = 39                                  <- starts here
```

The client indexes that same layout with compiled-in offsets, so widening the backpack — or
adding a fifth bag slot, which would have to live at field 23 — would shift the bank
underneath it. The UI *is* patchable (Turtle already raised `MAX_CONTAINER_ITEMS` from 20 to
36 in `patch-4.mpq` so 36-slot bags would draw), but drawing a slot that has no storage
behind it achieves nothing.

**The real ceiling:** 16 backpack + 4×36 bags = **160 carried**, plus **240** in the bank.
Strongbox exists to make that bank reachable rather than to fight the field layout.

## Gathering ✅

| | |
|---|---|
| **Yield** | 2× on herbs, ore and cloth. |
| **Node density** | More herb and ore nodes available, and faster turnover. |
| **One loot per node** | A node gives its **whole** yield in a single loot rather than several. |
| **Gems** | Tripled from ore nodes and clams. |
| **Fishing** | Faster pool respawns. |
| **Leather and cloth** | More leather per skin, more cloth per kill. |
| **Precious ore** | Silver, Gold and Truesilver as rare bonus drops from common nodes. |
| **Gather while mounted** | Mining, Herbalism and Skinning — all 17 ranks — no longer dismount you. |

Sources: `tuning-gathering.sql`, `tuning-node-yield.sql`, `tuning-gems-and-fishing.sql`,
`tuning-leather-and-cloth.sql`, `tuning-precious-ore-drops.sql`, `18-mount-management.sql`.

## Loot ✅

**Drop rates were tuned down, not up.** Vanilla's green rate applied to a modern loot table
meant two or three greens per kill. The rebalance is in `tuning-loot-boost.sql`: fewer
recipes, more bags, more uncommon gear.

That file also documents a mistake worth not repeating — an earlier version put a flat 0.5%
**floor** on every recipe row, which is catastrophic because recipe rows are enormous per
creature:

```
Blackwing Technician    546 recipe rows  ->  273% aggregate
Lord Kazzak              97 recipe rows  ->  392% aggregate
```

Boss loot is covered in [Small Group Play](Small-Group-Play#loot-that-works-for-two-people).

## Riding and mounts ✅

| | |
|---|---|
| **Riding skill** | Trainable at level **20**, not 40 (`patch-riding-level.py`, a server DBC edit). |
| **Riding tiers** | 50% at 20, 100% at 40, 150% at 60. |
| **Mount purchase** | Tier-1 mounts buyable and usable at 20; the 150% tier stays at 60. |
| **Gather while mounted** | See above. |
| **Interact while mounted** | Ore veins, herbs, chests, quest objects and signs no longer dismount you. |
| **Dismount on attack** | Casting anything hostile dismounts you and fires. |

**Interact while mounted** covers 1,991 objects, split by mechanism:

| object type | count | how |
|---|---|---|
| chest (ore, herbs, treasure) | 1043 | core — chests have no `allowMounted` field |
| questgiver | 495 | data |
| goober | 279 | data |
| text (signs, posters) | 159 | data |
| spellcaster | 15 | data |

Sources: `tuning-riding-tiers.sql`, `tuning-mount-purchase.sql`, `21-interact-while-mounted.sql`.

## Convenience ✅

| | |
|---|---|
| **Teleports** | All eight mage city teleports, for **every class**, General tab, level 1, free, no reagent. |
| **Salvage** (38600) | Break any weapon or armour into bars, leather or cloth. Universal and free. |
| **Talent reset** | Free, anywhere, self-service, for every player. |
| **No repair** | Nothing takes durability damage and nothing ever breaks. |
| **Profession cap** | Fixed — professions were stuck at 75. |
| **Smelting** | Mithril now carries you to skill 230 before it greys, instead of dead-ending. |

Sources: `10-teleports-for-all.sql`, `17-salvage.sql`, `setup-rbac-players.sql`,
`tuning-no-repair.sql`, `tuning-profession-ranks.sql`, `16-smelting-skill-bands.sql`.

### Salvage yields

Material follows the item's class; the **tier follows item level**, so a level 40 breastplate
yields Mithril, not Copper.

| quality | returns |
|---|---|
| white | 0–2 |
| green | 1–5 |
| blue | 2–6 |
| purple | 3–8 |

Equipped items are refused so a misclick cannot destroy what you are wearing. Soulbound is
allowed — that is most of what anyone wants to salvage.
