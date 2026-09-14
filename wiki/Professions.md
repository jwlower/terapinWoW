# Professions

## Across all professions ✅

| | |
|---|---|
| **Rank cap fixed** | Professions were stuck at **75**. All ranks Apprentice → Artisan are reachable. |
| **Masters teach ranks** | Each profession master teaches its own profession's ranks, so you never hunt for a specific trainer. |
| **Supplier NPC** | One summonable vendor stocking **every** vendor-sold crafting reagent and profession tool. |
| **Recipe icons** | 635 recipes now show the icon of the **item they make**. Every custom recipe previously showed the same generic face. |
| **Gather while mounted** | Mining, Herbalism, Skinning — all ranks. |
| **No tools** | Blacksmith Hammer, Jewelers Kits, Runed Rods, Arclight Spanner, Whittle — **1041 recipes** no longer need any tool at all. |
| **No workbenches** | Anvils, forges, the Alchemy Lab, Moon Wells. Craft anything, anywhere. |
| **Batch crafting** | ✅ Live. `!batch 5` and every recipe makes five — one cast, one animation, the whole batch at the end of it. `!batch 1` turns it off, `!batch` reports the setting. Each item still rolls for its own skill-up on the core's own odds. |
| **Craftable gear** | ✅ Live. **272 new pieces** — plate and mail from Blacksmithing, leather from Leatherworking, cloth from Tailoring — in four bands from skill 20 to 245. Fills a real hole: before this there was **no craftable epic below skill 226** in any profession. |

Sources: `tuning-profession-ranks.sql`, `13-masters-teach-professions.sql`,
`setup-supplier-npc.sql`, `12-recipe-icons.sql`, `18-mount-management.sql`,
`33-craftable-gear.sql`, `34-trainer-requires.sql`, `35-batch-crafting.sql`.

### Tools and workbenches — how it was removed

Worth recording because a server-only change would have done nothing visible. **The client
enforces both requirements from its own `Spell.dbc`**, exactly as it enforces the
mounted-cast restriction, so it would have kept refusing to start the cast.

The two sides did not even agree on scope: **912** server-side trade spells carried a tool,
but only **362** records in the client's DBC did. Each had to be cleared independently.

`totem1`/`totem2` were not in the pipeline's field map. They are at DBC fields **40 and 41**,
found by taking every record with a non-zero field 40 and correlating it against
`spell_template.totem1` — 362 of 362 agreed.

**Shaman totems are deliberately untouched.** `totem1` is a generic "required item" field and
shaman totem spells use it for their totem item, so the change is scoped to spells filed
under a trade skill only. Verified: Stoneskin, Searing and Healing Stream all still require
theirs.

### The recipe-icon fix

Worth calling out because the cause was not what it looked like. Trainers showed a generic
face for every custom recipe, and the first diagnosis — that the trainer NPCs were
misconfigured — was wrong. The real cause was `trainerType`, which `SendTrainerList` takes
from `TrainerSpellData` and **not** from `creature_template.trainer_type`. Natural
blacksmiths had icons; the custom NPCs did not.

## Per profession

<details>
<summary><b>Blacksmithing</b> — the only profession with new content ✅</summary>

**166 custom recipes**: 132 white weapons, 15 green weapons, 18 shields (+1 earlier shield).

### White weapons — the plain tier ✅

**11 weapon types × 12 level bands = 132 items**, required level 5 through 60. This was the
biggest gap in the profession and it was measured before it was filled: Blacksmithing could
make 186 green, 88 blue and 45 epic items, but only **13 white weapons — all below level 25**,
with nothing at all for polearms, thrown or crossbows. The cheap, make-it-yourself tier
stopped existing almost immediately.

| | |
|---|---|
| types | 1H/2H axe, 1H/2H mace, 1H/2H sword, dagger, fist, polearm, thrown, crossbow |
| bands | required level 5, 10, 15 … 60 — two per metal tier, the upper one prefixed *Heavy* |
| stats | **none** — that is what makes them white. Pure damage and speed. |

*Damage is cloned, not invented.* Each item takes its speed from a real weapon of the same
type and item level, and its **DPS from a curve pooled per weapon family** (one-hand,
two-hand, ranged). That means every two-hander of a tier does matching DPS and differs only
in swing speed — which is how vanilla actually works.

Pooling by family rather than by individual weapon type was a correction worth recording: the
per-type version left polearms at 3.5 DPS where every other two-hander of that tier was
5.9–6.4, because this database has **no polearm at all below item level 21** and the lookup
had to reach a long way to find anything. An earlier attempt that ratio-scaled off the
nearest weapon was worse still — it produced a Copper Halberd doing 35 DPS for a level 5
character, scaled ×10 off a *Farmer's Pitchfork*.

The ladder is verified **monotonic across all 11 lines**: no tier ever hits softer than the
one below it. Thin families (8 thrown, 1 low-level crossbow) made the raw curve noisy enough
to produce a crossbow that got weaker from level 20 to 25, so it is clamped.


**Shields — 18, six tiers × three shapes.** Each of the eighteen has its **own appearance**,
taken from a real shield of that item-level band so the art matches the armour sets of its
era. They are not three recolours of one model.

| shape | made from | stats |
|---|---|---|
| *Tier* **Bulwark** | metal only | Strength + Stamina |
| *Tier* **Wardingshield** | leather + metal | Intellect + Spirit |
| *Tier* **Roundshield** | wood + metal | Stamina + Agility |

Tiers: Copper, Bronze, Iron, **Steel**, Mithril, Thorium. Armour and block are inherited by
cloning a real shield of each item level, so they sit on the existing curve — 189 armour / 4
block at ilvl 10, up to 1918 / 36 at ilvl 63. Required level is derived as `item_level - 5`,
giving a monotonic ladder of **5 / 20 / 33 / 41 / 47 / 58**.

**Weapons — 15**, closing measured gaps in coverage by weapon type and tier:

| | tiers |
|---|---|
| Throwing Blade | Copper, Bronze, Iron, Mithril, Thorium |
| Crossbow | Copper, Bronze, Iron, Mithril, Thorium |
| Pike (polearm) | Copper, Bronze, Iron |
| Claw | Mithril |
| Maul | Iron |

**Cross-profession reagents.** Crossbows and Roundshields need wood from Survival —
`Bundle of Simple Sticks` through `Bundle of Star Wood Sticks` (42149–42153). That is
deliberate: it gives the gathering professions a customer.

🟨 **Planned:** quest rewards as learnable recipes, masterwork upgrades, reforging kits.
</details>

<details>
<summary><b>Mining</b> ✅</summary>

| | |
|---|---|
| **Smelting bands** | Mithril now carries you to skill **230** before greying. The high tiers previously dead-ended mid-tier. |
| **Node yield** | 2× ore, and a node gives its **whole** yield in one loot rather than several. |
| **Precious ore** | Silver, Gold and Truesilver as rare bonus drops from the common nodes. |
| **Gems** | Tripled from ore nodes. |
| **Mine while mounted** | All 7 ranks of Mining. |
</details>

<details>
<summary><b>Herbalism</b> ✅</summary>

2× herb yield, more nodes, faster turnover, whole yield in one loot, and all 6 ranks of Herb
Gathering are castable while mounted.
</details>

<details>
<summary><b>Skinning</b> ✅</summary>

More leather per skin, and all 4 ranks of Skinning castable while mounted.
</details>

<details>
<summary><b>Survival / Survivalist</b> 🟨</summary>

A **Survivalist Master** NPC (2600313) exists, and its wood bundles (42149–42153) are already
consumed by Blacksmithing's crossbows and Roundshields.

What does **not** exist yet is a Survival gathering skill of its own — there are no custom
Survival gathering spells. The reagents are currently obtained as ordinary items.

🟨 Planned: wood gathering as a real skill, XP for gathering wood, usable with any axe.
</details>

<details>
<summary><b>Leatherworking</b> 🟨</summary>

No custom recipes yet. Benefits from the shared changes: rank cap fix, master NPC, supplier,
recipe icons, and more leather per skin.

🟨 Planned: leather and wood shields (shaman-focused, two per tier minimum).
</details>

<details>
<summary><b>Tailoring</b> 🟨</summary>

No custom recipes yet. More cloth per kill; shared changes apply.

🟨 Planned: a large general bag per tier plus gathering-specific bags.
</details>

<details>
<summary><b>Alchemy</b> 🟨</summary>

No custom recipes yet. Shared changes apply.
</details>

<details>
<summary><b>Enchanting</b> 🟨</summary>

No custom recipes yet. Shared changes apply.

Note: **Salvage is not Enchanting.** It is universal and free for every class from level 1,
and it is shaped like Disenchant only because it was cloned from it to inherit the
item-targeting cursor. Disenchant itself is untouched.
</details>

<details>
<summary><b>Engineering</b> 🟨</summary>

No custom recipes yet. Shared changes apply.

🟨 Planned: goblin and gnomish specializations learnable **together** — the exclusivity is
enforced by spell and quest gating that can be removed.
</details>

<details>
<summary><b>Cooking, First Aid, Fishing</b> ✅🟨</summary>

Faster fishing pool respawns, tripled gems from clams, plus the shared changes (rank cap,
master NPC, supplier, icons).

🟨 Planned: feasts, and First Aid improvements.
</details>

## Profession masters ✅

One summonable master per profession — trainer, supplies and quests in one NPC:

| entry | | entry | | entry | |
|---|---|---|---|---|---|
| 2600300 | Blacksmithing | 2600305 | Enchanting | 2600310 | Herbalism |
| 2600301 | Leatherworking | 2600306 | Jewelcrafting | 2600311 | Skinning |
| 2600302 | Alchemy | 2600307 | Cooking | 2600312 | Fishing |
| 2600303 | Tailoring | 2600308 | First Aid | 2600313 | Survivalist |
| 2600304 | Engineering | 2600309 | Mining | | |
