# Custom NPCs

Every one is summoned with `.npc summon <entry>` - already granted to your account via
RBAC permissions 1 and 2. None are spawned in the world by default; a summoned copy is
temporary, so use `.npc save` if you want one to stay.

All are faction 35 (friendly to everyone) and level 1, cloned from template 21002.

In a macro, prefix with `/s`:

```
/s .npc summon 2600200
```

**73 NPCs total.**

## Class masters - trainer + every class quest

One per class. They cannot be merged: `Creature::IsTrainerOf` does a hard
`pPlayer->GetClass() != trainer_class` check with no bypass.

| entry | NPC | trains | quests |
|---|---|---|---|
| `2600200` | Warrior Master | 104 | 141 |
| `2600201` | Paladin Master | 159 | 122 |
| `2600202` | Hunter Master | 126 | 129 |
| `2600203` | Rogue Master | 114 | 117 |
| `2600204` | Priest Master | 191 | 136 |
| `2600205` | Shaman Master | 176 | 121 |
| `2600206` | Mage Master | 167 | 129 |
| `2600207` | Warlock Master | 144 | 171 |
| `2600208` | Druid Master | 190 | 118 |
| `2600209` | Pet Master | 117 | 41 |
| `2600210` | Demon Master | 22 | 18 |

## Profession masters - trainer + vendor + quests

`trainer_spell = 0`, which skips the profession gate entirely, so any character can use
them regardless of what they have learned. Each also stocks the five tools (Mining Pick,
Blacksmith Hammer, Skinning Knife, Fishing Pole, Strong Fishing Pole).

| entry | NPC | trains | quests | sells |
|---|---|---|---|---|
| `2600300` | Blacksmithing Master | 90 | 57 | 13 |
| `2600301` | Leatherworking Master | 85 | 28 | 16 |
| `2600302` | Alchemy Master | 38 | 7 | 11 |
| `2600303` | Tailoring Master | 102 | 8 | 23 |
| `2600304` | Engineering Master | 80 | 21 | 16 |
| `2600305` | Enchanting Master | 66 | 7 | 16 |
| `2600306` | Jewelcrafting Master | 81 | 15 | 13 |
| `2600307` | Cooking Master | 10 | 13 | 18 |
| `2600308` | First Aid Master | 10 | 4 | 5 |
| `2600309` | Mining Master | 13 | 5 | 7 |
| `2600310` | Herbalism Master | 4 | 5 | 5 |
| `2600311` | Skinning Master | 4 | 5 | 5 |
| `2600312` | Fishing Master | 2 | 14 | 5 |
| `2600313` | Survivalist Master | 91 | 1 | 26 |

Low trainer counts on the gathering professions are correct, not missing data -
Herbalism and Skinning have only rank upgrades to teach, and Fishing has two.

## Supplier

| entry | NPC | sells |
|---|---|---|
| `2600100` | Master Supplier | 64 |

Tools plus vendor-only crafting reagents (threads, dyes, bleach, spices, vials, flux,
powders, oils). Gatherable materials are deliberately excluded so herbalism, mining and
skinning stay worth doing.

## Dungeon questgivers - every quest for one dungeon

| entry | dungeon | quests |
|---|---|---|
| `2600001` | Ahn'Qiraj | 79 |
| `2600002` | Alterac Valley | 84 |
| `2600003` | Arathi Basin | 58 |
| `2600004` | Blackfathom Deeps | 12 |
| `2600005` | Blackwing Lair | 4 |
| `2600006` | Blood Ring | 4 |
| `2600007` | Crescent Grove | 5 |
| `2600008` | Deeprun Tram | 2 |
| `2600009` | Dire Maul | 46 |
| `2600010` | Dragonmaw Retreat | 10 |
| `2600011` | Frostmane Hollow | 5 |
| `2600012` | Gnomeregan | 2 |
| `2600013` | Hateforge Quarry | 7 |
| `2600014` | Maraudon | 13 |
| `2600015` | Molten Core | 9 |
| `2600016` | Naxxramas | 91 |
| `2600017` | Ragefire Chasm | 6 |
| `2600018` | Razorfen Downs | 10 |
| `2600019` | Ruins of Ahn'Qiraj | 1 |
| `2600020` | Scarlet Monastery | 12 |
| `2600021` | Scholomance | 12 |
| `2600022` | Shadowfang Keep | 7 |
| `2600023` | Stormwind Vault | 6 |
| `2600024` | Stormwrought Ruins | 13 |
| `2600025` | Stratholme | 18 |
| `2600026` | Sunken Temple | 9 |
| `2600027` | Sunnyglade Valley | 2 |
| `2600028` | The Deadmines | 9 |
| `2600029` | The Stockade | 7 |
| `2600030` | Timbermaw Hold | 27 |
| `2600031` | Tower of Karazhan | 15 |
| `2600032` | Wailing Caverns | 14 |
| `2600033` | Warsong Gulch | 59 |
| `2600034` | Windhorn Canyon | 4 |
| `2600035` | Winter Veil Vale | 26 |
| `2600036` | Zul'Gurub | 48 |
| `2600037` | Blackrock Spire | 67 |
| `2600038` | Blackrock Depths | 26 |
| `2600039` | Uldaman | 23 |
| `2600040` | Emerald Sanctum | 15 |
| `2600041` | Gilneas City | 14 |
| `2600042` | Onyxia's Lair | 10 |
| `2600043` | Razorfen Kraul | 9 |
| `2600044` | Zul'Farrak | 8 |
| `2600045` | The Black Morass | 7 |
| `2600046` | Lower Karazhan Halls | 6 |
| `2600047` | Karazhan Crypt | 1 |

**922 quests across 47 dungeons.**

## Entry ranges

| range | use |
|---|---|
| 2600001-2600047 | dungeon questgivers |
| 2600100 | Master Supplier |
| 2600200-2600208 | class masters |
| 2600300-2600313 | profession masters |

## Notes for adding more

- **`npc_flags` in this core**: GOSSIP `0x01`, QUESTGIVER `0x02`, VENDOR `0x04`,
  TRAINER `0x10`. So 3 = gossip+questgiver, 5 = gossip+vendor, 19 = gossip+questgiver+
  trainer, 23 = that plus vendor. **VENDOR is `0x04` here, not stock MaNGOS's `0x80`** -
  using `0x80` produces an NPC whose vendor window silently never opens.
- **Vendors cap at 128 items** (`MAX_VENDOR_ITEMS`, Creature.h:486). Overflow is dropped
  silently rather than erroring. Trainers have no such cap.
- **Never enumerate `creature_template` columns** in an INSERT..SELECT. This core has
  `display_id1`, not `modelid_1`. Clone the whole row with `CREATE TABLE LIKE` +
  `SELECT *`, then `UPDATE` only the fields that differ.
- **`skill_line_ability` only partially covers recipes** - 146 rows for Alchemy, but the
  spells trainers actually teach are largely absent. Attribute via `npc_trainer.reqskill`
  plus the teaching NPC's subname instead.
- **Turtle's reagent data has errors** - spell 47009 lists an epic helm as a reagent, so
  filter reagents to non-equipment, quality <= 2.

Built by `setup-dungeon-questgivers.sql`, `setup-supplier-npc.sql` and
`setup-class-and-profession-npcs.sql`, all in the TortoiseCompiledNew folder.
