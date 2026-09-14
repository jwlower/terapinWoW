# Professions

## Across all professions ✅

| | |
|---|---|
| **Rank cap fixed** | Professions were stuck at **75**. All ranks Apprentice → Artisan are reachable. |
| **Masters teach ranks** | Each profession master teaches its own profession's ranks, so you never hunt for a specific trainer. |
| **Supplier NPC** | One summonable vendor stocking **every** vendor-sold crafting reagent and profession tool. |
| **Recipe icons** | 635 recipes now show the icon of the **item they make**. Every custom recipe previously showed the same generic face. |
| **Gather while mounted** | Mining, Herbalism, Skinning — all ranks. |
| **Batch crafting** | 🟨 Planned. Vanilla's "create all" repeats the cast; a pre-rolled single-animation version needs scripting. |

Sources: `tuning-profession-ranks.sql`, `13-masters-teach-professions.sql`,
`setup-supplier-npc.sql`, `12-recipe-icons.sql`, `18-mount-management.sql`.

### The recipe-icon fix

Worth calling out because the cause was not what it looked like. Trainers showed a generic
face for every custom recipe, and the first diagnosis — that the trainer NPCs were
misconfigured — was wrong. The real cause was `trainerType`, which `SendTrainerList` takes
from `TrainerSpellData` and **not** from `creature_template.trainer_type`. Natural
blacksmiths had icons; the custom NPCs did not.

## Per profession

<details>
<summary><b>Blacksmithing</b> — the only profession with new content ✅</summary>

**34 custom recipes**: 15 weapons + 18 shields (+1 earlier shield).

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
