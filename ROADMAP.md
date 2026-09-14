# Terapin WoW — Roadmap

A Turtle WoW (1.12) server rebuilt around a **solo and small-group** experience, with
crafting as the spine of progression rather than an afterthought.

Everything below is annotated with what it actually costs to build on this core, because
the features differ enormously in that respect and it is not obvious from the outside.

---

## Status legend

| tag | meaning |
|---|---|
| ✅ **Live** | built and running |
| 🟩 **Data** | SQL + client DBC only. The existing generator pipeline handles it |
| 🟨 **Eluna** | needs server-side Lua scripting. Each of these is a small project |
| 🟥 **Core** | needs C++ changes and a rebuilt `mangosd` |
| ⛔ **Blocked** | cannot work as originally specified — see the note |

The distinction that matters most: **🟩 is hours, 🟨 is days, 🟥 is a rebuild plus a
regression hunt.** Eluna is now live, so 🟨 items are buildable.

---

## Prerequisites

Two pieces of groundwork gate a lot of the list.

### Eluna — ✅ Live

**Running on the newest core (`e21b68b`) with Eluna enabled and creature movement working** —
the first build to have both. Every 🟨 item below is now unblocked.

The regression that blocked this was found by bisect and turned out to have nothing to do
with playerbots, which had been the leading suspect for weeks.

**Cause.** `Map::UpdateCells` discarded every queued motion update when the motion thread
pool was unavailable:

```cpp
if (IsContinent() && m_cellThreads->status() == READY)
    UpdateActiveCellsAsynch(now, diff);
else
    UpdateActiveCellsSynch(now, diff);      // cells HAVE a synchronous fallback

if (IsContinent() && m_motionThreads->status() == READY && !unitsMvtUpdate.empty())
{ ...UpdateMotionAsync(diff)... }           // motion had NONE
unitsMvtUpdate.clear();                     // so the work was silently thrown away
```

Enabling Eluna forces `Continents.MotionUpdate.Threads` to 0 — correctly, since a map's Lua
state is single-threaded — so the pool never reached `READY` and no creature's `MotionMaster`
was ever updated.

**Fix.** A synchronous `else` branch mirroring the cell path. 22 lines, no revert, Eluna
kept. Saved as `motion-sync-fallback.patch` and commented in place.

It explains every symptom, including the ones that looked contradictory: `MoveChase` fired
and built a valid path (zero spline rejections, zero path-build errors) because the tick that
would consume it never ran; waypoint patrol was unaffected because it does not go through
`UpdateMotionAsync`; and only continents were affected, per the `IsContinent()` guard.

**Build configuration:** `BUILD_ELUNA=ON`, `BUILD_PLAYERBOTS=OFF`,
`MODULE_MOD_PLAYERBOTS=disabled`.

### Playerbots — ⛔ Out of scope

Deliberately not built: `BUILD_PLAYERBOTS=OFF`, `MODULE_MOD_PLAYERBOTS=disabled`,
`AiPlayerbot.Enabled = 0`. The server targets a solo and small-group experience instead.

Worth recording, because it was the leading suspect for weeks and was **wrong**: bots did not
cause the chase regression. Builds with bots compiled out still reproduced it. See the Eluna
section for the real cause.

Two findings if this is ever revisited:

* The module does not currently compile against this tree
  (`PlayerbotAIConfig.h: error C2061: syntax error: identifier 'PlayerbotAI'`), and commit
  `7c997e9` conversely fails to build with bots *off*. The module's build wiring is fragile
  around this era of the repo.
* BG-only bots are *nearly* expressible in config: `RandomBotAutoJoinBG = 0` makes bots queue
  only once a real player has queued, and they bracket-match on level. But
  `RandomBotAutologin` must stay on - bots cannot join a battleground they are not logged
  into - so "no bots in the world, bots only in battlegrounds" needs a code change.

### Content pipeline — ✅ Live

Already built and proven:

- `Spell.dbc`, `SkillLineAbility.dbc`, `SpellIcon.dbc` and arbitrary files packed into
  `patch-6.mpq`
- PNG → BLP2 icon conversion written from scratch (no external tool)
- A cross-check that fails loudly if the server and client halves ever disagree

**Hard constraint:** custom spell IDs must stay below 60000. Higher IDs are silently
truncated to 16 bits and arrive at the client as a completely different spell.

---

## Major changes

### Stacking — ✅ Live
All items that can stack now stack as high as possible.

### Gathering yield — ✅ Live
2× on herb, ore and cloth.

### Mounts — ✅ Live
Two changes that only make sense together.

**Gather while mounted.** Mining, Herb Gathering and Skinning — *all 17 ranks* — now carry
`SPELL_ATTR_CASTABLE_WHILE_MOUNTED` (bit 24) in both `spell_template` and the client's
`Spell.dbc`. That single bit is the whole feature: `Spell.cpp:5971` is the only thing in the
core that throws a player off a mount for casting, and the bit makes it skip the branch. No
Lua, no core change.

All ranks matter — the client casts the *highest rank you know*, so flagging only rank 1
would work until someone trained Journeyman and then quietly stop.

**Auto-dismount when *you* go to attack — not when you are attacked.** Mounted escape is
worth keeping, so "entering combat" is the wrong trigger: `Unit::SetInCombatState` fires in
both directions and cannot tell them apart. (A first attempt hooked it anyway and had to be
retired — a mob aggroing you threw you off your horse.)

`AURA_INTERRUPT_FLAG_MELEE_ATTACK` (0x1000) *can* tell them apart. The last line of
`Unit::AttackerStateUpdate` (`Unit.cpp:2561`) is:

```cpp
pVictim->AttackedBy(this);
RemoveAurasWithInterruptFlags(AURA_INTERRUPT_FLAG_MELEE_ATTACK);
```

`this` is the unit doing the swinging, so it fires on the **attacker** only. The bit is now
set on all 484 mount auras. Removing the aura is a real dismount, not a dropped buff icon —
`Aura::HandleAuraMounted` calls `target->Unmount(true)` on removal.

Hostile *spells* were already covered by `Spell.cpp:5971`, which dismounts for any cast
lacking `SPELL_ATTR_CASTABLE_WHILE_MOUNTED`. Between the two, every way of starting a fight
dismounts you and nothing else does — no script, no core change.

Precedent: Turtle's own Gnome and Goblin Racing Cars already ship with this bit set.

**Interact with the world while mounted.** `GameObject::Use` (`GameObject.cpp:1493`) is a
single gate — `if (!m_goInfo->IsUsableMounted()) user->RemoveSpellsCausingAura(SPELL_AURA_MOUNTED);`
— and `IsUsableMounted()` has exactly one caller, so opening it up changes nothing else.

| object type | count that dismounted you | how |
|---|---|---|
| chest (ore, herbs, treasure) | 1043 | core — no `allowMounted` field exists; all 16 chest slots are used |
| questgiver | 495 | data — `allowMounted` |
| goober | 279 | data — `allowMounted` |
| text | 159 | data — `allowMounted` |
| spellcaster | 15 | data — `allowMounted` |

Chests were the one that mattered for gathering, and the one that needed code. The other 948
are `sql/21`. This is not a new mechanism: stock data already ships the bounty boards, guild
vaults and the Karazhan portal with `allowMounted` set.

*This is also why "gather while mounted" looked half-broken at first.* The cast survived —
the spell attribute worked — but `Spell::SendLoot` routes a chest through `GameObject::Use`,
so the mount vanished a moment later at the **loot** step. The attribute and the chest change
are both required; neither is sufficient alone.

**The client is the real gatekeeper — and it decides before the server ever hears.** This is
the single most important thing to know before writing anything mount-related.

While mounted, the 1.12 client **drops `CMSG_ATTACKSWING` and `CMSG_GAMEOBJ_USE` locally**.
Measured from a session log: across two mounted windows it sent nothing but `MSG_MOVE_*`, and
the session's only attack swing arrived *one second after* the mount aura was removed with
`AURA_REMOVE_BY_CANCEL` — the player had dismounted by hand — and then worked perfectly.

So the discriminator is **how the interaction reaches the server**:

| arrives as | mounted behaviour | fixable server-side? |
|---|---|---|
| a **spell cast** (gathering, abilities) | client sends it normally | ✅ yes |
| a **bare opcode** (melee swing, object click) | never leaves the client | ❌ no |

That is why gathering was fixable and melee was not. Two server-side fixes were built and
shipped before this was measured — `AURA_INTERRUPT_FLAG_MELEE_ATTACK` on mount auras, then
changing `Unit::Attack` to dismount rather than refuse. Both are correct; both are
unreachable. **Check the opcode log before writing server code for this.**

Melee auto-dismount therefore lives in `client/AddOns/TerapinTips/dismount.lua`, which
cancels the mount, waits for the server to confirm, and re-issues the action. Two traps
there, both measured rather than assumed:

- **Mount buffs cannot be identified by icon.** Of 484 mount spells only **41** use an
  `Ability_Mount_*` icon; 83 use `Spell_Nature_Swiftness` and 48 use
  `Ability_Hunter_BeastCall`. The 1.12 API gives no spell id for a buff either, so it matches
  the tooltip **name** against a 475-entry set generated from the client's own `Spell.dbc`.
- **`IsMounted()` and `Dismount()` do not exist in this client** — both grep to zero hits in
  `WoW.exe`. Detection is buff-scanning; dismounting is `CancelPlayerBuff`.

**Swimming does not dismount you, server-side.** Worth stating because it is easy to assume
otherwise. Every mount-removal path in `src/game` was checked and none is water-related; the
only water interaction is `Spell.cpp:6674`, which blocks *mounting* while in water
(`SPELL_FAILED_ONLY_ABOVEWATER`) but never removes an existing mount. `DismountCheck()`
re-runs `CheckCast` on area change but acts only on `NO_MOUNTS_ALLOWED`/`NOT_HERE`, not on
that result. And `AURA_INTERRUPT_FLAG_NOT_ABOVEWATER` (0x80) is set on **zero** mount auras
in both `spell_template` and the client's `Spell.dbc`. If the client still dismounts on deep
water it is doing so on its own, and no data on either side controls it.

*Implementation note:* `or_set` was added to the content pipeline's `MODIFY` for this. The
three professions start from different `Attributes` values (16, 128, 65680), so an absolute
assignment would have wiped whichever bits the other two relied on. OR-ing is also idempotent,
so a rebuild over an already-patched DBC is a no-op rather than drift.

### Drop rates — ✅ Live *(tuned down from the original plan)*

| quality | multiplier |
|---|---|
| grey | 1× |
| white | 1.5× |
| uncommon | 1.25× |
| rare / epic / legendary | 2× |

The original "+50% on uncommon and above" was tried and **reverted**. The problem was not
the multiplier but a 1% *floor* applied per loot row: creatures carry hundreds of green rows
across several loot groups, so flooring each one guaranteed roughly three greens per kill.
The multiplier alone is fine; a floor on a large pool is not.

### Class-aware boss loot — 🟨 Eluna

> Bosses drop one of their rare items, uniquely, based on the classes present.

Loot rolls from static tables with no knowledge of who is in the group, so this needs a
script. The biggest single item in this document, and the most distinctive.

**Design notes**
- Roll the boss's normal table first, then substitute or append a class-appropriate item
- Fall back to "a good item per party member + 1" when the boss has nothing for that class
- Needs a class→item mapping per boss; largely derivable from existing loot plus armour type
  and stat weights

---

## Auto-scaling — ⛔ Blocked as specified, ✅ **built in a narrower form**

> On entry to a dungeon with a level 18, 33 and 45, mobs scale so each player gains XP.

**This cannot work.** A creature has one level and one health pool. It cannot be level 18 for
one player and level 45 for another simultaneously, and no amount of scripting changes that.

Worked example with the real XP formula — a 27-level spread has no solution:

| mob level | lvl 18 sees | lvl 45 sees |
|---|---|---|
| 20 | fair fight | **grey — zero XP** (grey cut-off is 35) |
| 35 | **one-shot** | green, partial XP |
| 45 | unsurvivable | full XP |

**What is achievable:** scale the instance **once on entry**, to a level derived from the
group. That works well for the realistic duo/trio case of a 3-5 level spread, and is a
reasonable 🟨 feature.

**Recommendation:** promise *"dungeons scale to your group"* rather than *"every player is
individually challenged"*, and lean on the XP formula's own tolerance — a level 45 still
earns from anything above level 35.

---

### What was built instead — ✅ Live

Mobs still cannot scale to a party, but the **player** can scale to the dungeon, which solves
the same problem from the other side. Dungeon mentor scaling reduces a too-high character's
damage, healing and maximum health toward the dungeon's own level — −70% for a level 60 in
Ragefire Chasm, −5% in Stratholme, nothing at all at level.

Gear, talents and abilities are untouched; only output changes. Toggle with `!scale`.
Full details in the [Dungeons wiki page](wiki/Dungeons).


## Racial abilities — 🟩 Data

**Planned, not built.** Vanilla racials are mostly flat, forgettable passives. The intent is
to make each race's identity felt while moving around and playing, not just on a stat sheet.

Three worked examples, with what each would actually take:

| race | idea | how |
|---|---|---|
| **Gnome** | +5% to your maximum rage, mana or energy | `SPELL_AURA_MOD_INCREASE_ENERGY_PERCENT` (132). One passive; the aura applies to whichever resource the class uses, so a single spell covers all three. |
| **Night Elf** | +5% run speed | `SPELL_AURA_MOD_INCREASE_SPEED` (31), the same aura every speed effect uses. |
| **Tauren** | **Plainsrunning** — speed ramps 1%/sec while running outdoors, up to 20%, and drops when you stop | **Already implemented.** See below. |

### Plainsrunning already exists on this build ✅

Worth knowing before anyone writes it from scratch. Turtle has built the whole mechanic:

| | |
|---|---|
| spells | **12566** (the ramp, aura 23 periodic-trigger), **12567**, **12568** (aura 31, the speed itself) |
| cancelled by damage | `Unit.cpp:1157` — steps down through `PLAINSRUNNING_SECOND_TICK`, `FIRST_TICK`, then the base aura |
| cancelled by casting | `SpellHandler.cpp:392`, unless the spell is castable while mounted |

So the Tauren item is not "build a ramping speed system" — it is "decide the numbers and make
sure Tauren actually get it". The stock ramp goes considerably higher than 20%.

### Where racials come from

They are ordinary spells granted through `playercreateinfo_spell` per race, and filed in
`skill_line_ability` with a **`race_mask`** rather than a class mask — Stoneform is race_mask
4 (Dwarf), Shadowmeld 8 (Night Elf), Will of the Forsaken 16 (Undead), War Stomp 32 (Tauren),
Blood Fury 2 (Orc).

That means changing a racial is the same shape of job as
[the weapon-skill grant](../blob/main/db/3-content/31-start-with-weapon-skills.sql): derive
from the mask, grant at creation, and back-fill existing characters. No core work.

**The one thing to watch:** a racial that changes a tooltip needs the client `Spell.dbc`
changed too, not just `spell_template` — the same trap that made Battle Shout keep reading
"2 min". Any numeric change here is a two-sided edit.

---

## Shaman totems as relics — 🟩 Data

**Planned, not built.** Shaman totem spells currently require a totem *item* — Earth, Fire,
Water and Air Totem (5175–5178) — carried in your bags and consumed as a reagent-style
requirement via `totem1`. The removal of crafting tools in `db/1-tuning` deliberately left
these alone, because `totem1` is a generic "required item" field and stripping it there would
have hit shamans as collateral.

The intent instead: **drop the item requirement entirely, and make totems equippable relics**
that drop as rewards, filling the slot shamans otherwise waste on a ranged weapon.

### It is achievable on this build

Checked rather than assumed — relics are already a working concept here:

| | |
|---|---|
| `INVTYPE_RELIC = 28` | defined at `ItemPrototype.h:139` |
| equip handling | `Player.cpp:10494` has a case for it |
| items already using it | **65**, e.g. *Idol of Acidity* |

So this needs no core work. Three data steps:

1. **Clear `totem1`/`totem2`** on the shaman totem spells, exactly as `sql/30` did for trade
   recipes — the same two-sided treatment, since the client enforces it from its own
   `Spell.dbc`.
2. **Create relic items** with `inventory_type = 28`, class-restricted to shaman, carrying
   totem-flavoured bonuses.
3. **Place them as rewards** rather than vendor stock, so the slot is something you fill over
   time.

Worth deciding before building: whether relics should be *required* to cast totems (a
straight swap of one requirement for another) or purely a **bonus** slot. The latter is more
in keeping with everything else here — the tool removal was about deleting friction, and
re-adding a mandatory item would undo that.

---

## Crafting

### Non-exclusive specializations — 🟩 Data
All weaponsmith masteries, both goblin and gnomish engineering, learnable together. The
exclusivity is enforced by spell and quest gating that can be removed.

### Batch crafting — ✅ Live
`!batch 5` and every recipe you cast makes five. One cast, one animation, the whole batch at
the end of it — which is the part vanilla's "Create All" does not do: Create All queues N
separate casts and you sit through N animations. `!batch 1` turns it off, `!batch` reports.

`lua_scripts/batch_crafting.lua` on `PLAYER_EVENT_ON_SPELL_CAST`. The first craft runs
normally and the remaining N-1 resolve on a later tick — deferred for the same reason
salvage is, since the hook fires *part way through* `Spell::prepare`.

**Skill-ups are rolled, never granted.** Each item in the batch rolls on exactly the odds
`Player::SkillGainChance` uses, so batching is convenience and not a shortcut.

**The item is created before the reagents are taken**, deliberately: if the bags are full the
batch stops without having destroyed anything, so a full bag costs you items and never
materials.

No client code — the quantity box belongs to `Blizzard_TradeSkillUI`, and the last addon here
that hooked a protected control disabled camera panning for the whole game.

### Salvaging — ✅ Live
Break gear back down into bars, leather or cloth. **Universal and free** — every class,
known from level 1, no profession requirement, no reagent, no cost.

Spell **38600**, cloned from Disenchant so it inherits the item-targeting cursor, with the
effect switched to `SPELL_EFFECT_DUMMY`. `lua_scripts/salvage.lua` watches
`PLAYER_EVENT_ON_SPELL_CAST` and does the work.

Material follows the item's class (weapons, mail and plate give bars; leather gives leather;
cloth gives cloth) and the **tier follows item level**, so a level 40 breastplate yields
Mithril rather than Copper. Equipped items are refused so a misclick cannot destroy what you
are wearing; soulbound is allowed, since that is most of what anyone wants to salvage.

*Implementation note:* the Eluna item-dummy hook is keyed by item entry, which would have
meant registering across all 14,937 weapons and armour pieces. `PLAYER_EVENT_ON_SPELL_CAST`
is global and exposes `Spell:GetTarget()`, which avoids that entirely.

*Implementation note — the destroy MUST be deferred by a tick.* `PLAYER_EVENT_ON_SPELL_CAST`
fires from `Spell::prepare` (`Spell.cpp:3884`), **part way through the cast**. Everything
below that line — `TakeReagents()`, `SendSpellGo()`, `handle_immediate()` →
`DoAllEffectOnTarget(ItemTargetInfo*)` → `HandleEffects(nullptr, target->item, …)` — keeps
using the raw `Item*` the hook was handed.

Destroying it inline crashes the server, *intermittently*. `Player::DestroyItem` ends in
`SetState(ITEM_REMOVED)`, and `Item::SetState` (`Item.cpp:802`) reads:

```cpp
if (uState == ITEM_NEW && state == ITEM_REMOVED) { RemoveFromUpdateQueueOf(forplayer); delete this; return; }
```

So an item not yet written to the database — **anything freshly looted** — is freed on the
spot and the spell then dereferences freed memory. An item that had already been saved is
merely detached, and the same code appears to work fine. That is exactly why this passed
testing and crashed later with an `ACCESS_VIOLATION`.

The script now reads the item's properties in the hook (reads are harmless) and does the
destroy and the grant from a one-shot `RegisterEvent` timer on a later tick. It re-finds the
item **by GUID**, so a player holding two of the same thing loses the one they clicked, and
grants nothing if the item has gone in the meantime — failing toward "no reward" rather than
toward duplication.

*Implementation note — `Item:GetItemLink()` returns French.* It overrides the English name
whenever *any* `locales_item` row exists, and indexes `Name[]` with a raw `LocaleConstant`:

```cpp
if (ItemLocale const* il = eObjectMgr->GetItemLocale(temp->ItemId)) name = il->Name[locale];
```

Those are different index spaces. `ObjectMgr::GetOrNewIndexForLocale` returns **-1 for enUS**
and packs the remaining locales densely in first-seen order, so with French rows loaded,
index 0 *is* French — and `DEFAULT_LOCALE` is 0. The script keeps the link the client already
renders and swaps only the bracketed name for `Item:GetName()`, which reads `Name1` and has
no locale lookup. The underlying Eluna method is still wrong for any future script; it also
dereferences `item->GetOwner()` without a null check.

| item quality | returns |
|---|---|
| white | 0-2 |
| green | 1-5 *(scaled by item value)* |
| blue | 2-6 *(scaled by item value)* |

Higher tiers also refund cloth, leather and gems. Instant, not channelled — players will do
this in bulk.

---

## Professions

### Alchemy — 🟩 Data
- A potion for every stat at every tier
- Utility potions from common trade drops: beast tracking, treasure detection, attack speed
  at the cost of spirit
- **Transmutation chains** — each ore tier converts up to its valuable counterpart (copper →
  silver, iron → gold, mithril → truesilver). Same for gems, herbs, leather and cloth.
  Typically 5:1, tightening to 3:1 at higher tiers
- Weapon oils using enchanting residuals: chance to cast fireball, leech health, extra
  attack, refund a spell; fire damage at the cost of frost (mage only)

### Blacksmithing — ✅ Mostly live, 🟩 for the rest

**166 custom recipes shipped:** 132 white weapons (11 types × 12 level bands), 15 green
weapons, 18 shields (six tiers × three shapes, each with its own appearance), plus the
original Runed Copper Shield. Tools and workbenches are gone profession-wide.

Remaining 🟩: quest rewards as learnable recipes, masterwork upgrades, reforging kits.

#### The measurement that motivated all of it

Taken **before** any of the above was built, and kept because it is the evidence, not a
current state:

| type | white | green | blue+ | total |
|---|---|---|---|---|
| plate | 0 | 38 | 55 | 93 |
| mail | 5 | 54 | 33 | 92 |
| shields | 0 | 20 | 2 | 22 |
| 1H sword | 2 | 4 | 7 | 13 |
| fist | 1 | 3 | 2 | 6 |
| polearm | 0 | 3 | 3 | 6 |
| thrown / crossbow | 0 | 5 / 5 | 0 | 10 |

The white column is the story: **13 white weapons in the entire profession, all below level
25**, and none at all for polearms, thrown or crossbows. Greens and blues were well covered;
the plain make-it-yourself tier stopped existing almost immediately. That is the gap the 132
white weapons fill.

*(No white plate is correct, not a gap — plate is not wearable until 40, by which point green
is the floor.)*

**Shields — ✅ Live.** Blacksmithing made **four** shields in total, two of them item level
70, so nothing was craftable between roughly level 18 and 60 for a profession built around
protection. Eighteen added, three per tier on three axes:

| name | axis | stats | mats |
|---|---|---|---|
| *Tier* **Bulwark** | all metal | strength + stamina | bars |
| *Tier* **Wardingshield** | leather + metal | intellect + spirit | bars + leather |
| *Tier* **Roundshield** | wood + metal | stamina + agility | bars + Survival sticks |

**Copper → Bronze → Iron → Steel → Mithril → Thorium**, at crafting skill
45 / 115 / 165 / 190 / 220 / 270.

Each of the three shields in a tier has its **own appearance**, taken from a real shield of
that item-level band so the art matches the armour sets of its era — they are not three
recolours of one model.

Armour and block are **inherited by cloning a real shield of each item level** rather than
invented, so they sit on the existing curve (189 armour / 4 block at ilvl 10, up to
1918 / 36 at ilvl 63). Stat budgets are deliberately modest — 3 to 12 split over two stats —
so craftable greens do not outclass quest rewards of the same level.

`required_level` is the one thing NOT inherited. Five of the six clone sources happen to
carry `item_level - 5`, the vanilla convention for a green — but Visionary Buckler (the Iron
source) carries 0, which left the entire Iron tier wearable at level 1 and sitting out of
order between Bronze and Steel. It is now derived, giving a monotonic ladder of
5 / 20 / 33 / 41 / 47 / 58.

The wood variant takes Survival's stick bundles, the same cross-profession link the
crossbows use.

**Weapons** — every type at every tier. Polearms, fist weapons, daggers, 1H/2H maces, axes
and swords, plus crossbows (overlapping Survival for wood and rope) and thrown. White
variants from bars and grindstones; green variants later in each tier using leather,
grindstones, gems and a common trade drop.

Stat themes: polearms, fist weapons and daggers lean agility; maces, axes and swords mix
strength and agility; two-handers split between warrior and paladin support.

**Masterwork upgrade** — the capstone of each tier. Consumes one of each gem of the tier, a
large quantity of leather and bars, the tier's valuable bar, and a common mob trade drop.
Lifts the target item to roughly mid-next-tier quality.

**Upgrade and reforging kits** — from bronze onward, at every tier.

**Already covered — do not duplicate:**
- **Skeleton keys** — Silver, Golden, Truesilver and Arcanite, one per precious metal
- **Sharpening stones and weightstones** — a full chain to item level 60 (Rough, Coarse,
  Heavy, Solid, Dense, Elemental). The single gap is an **Elemental Weightstone**, which has
  no ilvl 60 counterpart to the Elemental Sharpening Stone

**Quest rewards as recipes** — Whirlwind Axe and similar become learnable rather than
one-time awards.

### Enchanting — 🟩 Data
- An enchant for every gear slot and weapon at every tier
- A new wand type per tier. Arcane wands are cheap; other damage types need gems, ore,
  potions, herbs or leather
- Enchants for every stat including block and hit. Narrow effects (damage to beasts,
  humanoids, demons) hit harder but need rare, thematic materials
- **Instant disenchant**, and all materials stack to maximum
- A **random-enchant recipe** per tier, applying an "of the Animal"-style suffix appropriate
  to that tier

### Engineering — 🟩 Data, 🟨 for the zanier effects
- More bombs per tier, most not requiring Engineering to use, more instant-cast
- Elemental bombs using alchemy reagents — frost oil for a bomb that roots via Frost Nova
- Mechanical companions beyond combat: a healbot built from healing potions that funnels
  health until destroyed
- Mines that slow, bombs that silence, resistance totems, ammunition with damage types
- Goblin/gnomish: borrowed spells with a chance of catastrophic failure, more
  transformations, augmentations that add on-use effects to common items — **🟨, these need
  scripting**

### Leatherworking — 🟩 Data
- **Bags** — a large general bag per tier plus gathering-specific bags
- **Leather upgrading** — light → medium and so on, as each tier's capstone; hides rip into
  their common leather
- **Shields** from leather and wood — shaman-focused, two per tier minimum, also paladin
- **Masterwork** items, as Blacksmithing
- **Cloaks** for leather and mail wearers, plus strength cloaks for warriors and paladins
- **Salvaging** leather gear back into leather and, rarely, hides — 🟨

### Tailoring — 🟩 Data
- Masterwork items, overlapping alchemy, jewelcrafting and enchanting for caster materials
- Bags, and the **ropes** Survival depends on, as a basic item at each tier
- Cloaks for cloth wearers and paladin healers
- Salvaging cloth gear back into bolts — 🟨

### Survival — 🟩 Data, 🟨 for wood XP
- **Gathering wood grants XP** and works with any axe or the tool type — 🟨, XP for gathering
  is not a data-level feature
- More bows per tier, hunter-focused; some strength bows that hit hard, wanted by melee
  hunters
- Staves as a generalist weapon — damage casters, healers, and strength/agility users
- On-hit effects: trips and stuns, slows, parry for warriors and hunters

### Cooking — 🟩 Data, 🟨 for feasts
- **Feasts** — a placeable object party members click for a timed stamina and spirit buff — 🟨
- Campfire variants granting cooking and stat bonuses
- Expanded well-fed buffs
- **Drinks**, and a new **Slaked** buff: rage and energy generation, mana regen, and higher
  maximum rage, energy and mana
- **Pet foods** buffing armour, attack speed, strength, agility, mana and movement speed
- Movement-speed drinks per tier
- Resistance and poison-immunity food

### Fishing — 🟥 Core
- **No bobber click.** When the timer ends you get the item; clicking at the right moment
  guarantees a fish. Below-level fishing still returns grey trash but raises skill
- Floating wreckage scales with fishing skill — pearls become reliably obtainable

Bobber interaction is client behaviour as much as server, so this is the most expensive item
in the document relative to its size. Worth deferring until Eluna is settled.

### First Aid — 🟨 Eluna
- **Patches** built from healing, mana, rage and energy potions. Applied out of combat as an
  hour-long buff; consumed automatically when the relevant resource drops below a threshold
  in combat

Health thresholds are borderline expressible in spell data; mana, rage and energy are not.

---

## Suggested order

1. ~~**Bisect the chase regression and build with Eluna**~~ — ✅ **done.** Newest core, Eluna
   enabled, movement working. Every 🟨 item is unblocked
2. ~~**Shields**~~ — ✅ **done.** 18 added, three per tier on three axes, each with its own look
3. ~~**Blacksmithing weapon tiers**~~ — ✅ **done.** 132 white weapons, 11 types × 12 bands
4. **Alchemy transmutes and the potion/oil matrix** — high value, low cost
5. **Class-aware boss loot** — the most distinctive feature, first real Eluna project
6. **Salvaging and batch crafting** — the quality-of-life pair that makes crafting the spine
7. **Instance scaling**, scoped to group rather than per-player
8. **Fishing**, last — most expensive, least dependent on anything else
