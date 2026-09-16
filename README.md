# Terapin WoW

A private vanilla (1.12) server built on a VMangos-derived core, tuned for **solo and
small-group play**. Battlegrounds and playerbots are deliberately out of scope; everything
here is aimed at one to four people who want to actually finish things.

- [**wiki/**](wiki) — what the server does today, page by page: general, combat, classes,
  professions, dungeons, small-group play, and a generated catalogue of every custom item and spell.
- [**ROADMAP.md**](ROADMAP.md) — what's planned, what's live, and what is *not possible* on
  this client and why.
- [**docs/**](docs) — the hard-won specifics. Read [SPELL-IDS.md](docs/SPELL-IDS.md) before
  adding a spell; it will save you an afternoon.

---

## What's in here

| | |
|---|---|
| [`server/`](server) | The server itself — binaries, configs, Eluna scripts, DBC patchers. |
| [`db/`](db) | Every database change, as ordered idempotent migrations. |
| [`content/`](content) | The pipeline that builds the client patch (new spells, items, icons). |
| [`client/`](client) | The `TerapinTips` and `TerapinTravel` addons. |
| [`core/`](core) | Patches against the server source tree. |
| [`scripts/`](scripts) | Sync from the live install; back up the databases. |

**What is deliberately *not* in here**, and why it matters:

- **`maps/` `vmaps/` `mmaps/` `dbc/`** — 3.75 GB extracted from the client. Not ours to
  redistribute, and regenerable in an hour. See [Setting up](#setting-up).
- **Characters and accounts** — `tw_logon` holds account **password hashes**. Committing it
  would publish credentials to everyone the repo is shared with, and git history keeps them
  after a delete. `scripts/backup-db.ps1` dumps these to a gitignored folder instead.
- **`patch-6.mpq`** — 27 MB, and derived from the client's own `Spell.dbc`. Build it with
  `python content/build.py --install`.

That's what keeps this repo at ~25 MB and safe to hand to a friend.

---

## Setting up

You need a **Turtle WoW 1.12 client** and **MySQL**. The client is where the map data comes
from, so this won't work without one.

1. **Extract the game data** — run `mapextractor.exe`, `vmapextractor.exe` +
   `vmap_assembler.exe`, and `MoveMapGen.exe` from `server/bin/` against your client. This
   produces `dbc/ maps/ vmaps/ mmaps/` next to the server. It takes a while; do it once.
2. **Load a stock Turtle world database**, then apply everything on top:
   ```bash
   pwsh -File db/apply-all.ps1
   ```
3. **Re-run the DBC patchers.** `server/dbc-patches/*.py` edit the *server's* extracted DBCs
   — riding trainable at 20, free bank slots. **Step 1 overwrites these**, so they must run
   after any re-extraction. Both are idempotent and have a `--check` mode.
4. **Build the client patch** and install the addon:
   ```bash
   python content/build.py --install
   ```
   Copy `client/AddOns/TerapinTips` into your client's `Interface/AddOns/`.
5. **Start it** — MySQL first, then `server/launch/start-all.bat`.

The committed configs use `mangos/mangos` on localhost. Change them in `server/conf/` if you
ever expose the server beyond your own machine.

---

## Making changes

**Database changes go in `db/` as a numbered file — never as a one-off query.** Every file
is idempotent, so re-running the whole set is a no-op rather than a duplication. That is what
lets `db/apply-all.ps1` be the rebuild path instead of a database dump, and it's why this
repo can be 25 MB instead of 400 MB.

Order is the directory numbering: `1-tuning/` (rates and loot, broad updates against stock
data) → `2-setup/` (custom NPCs, which want the tuning in place) → `3-content/` (new spells
and items; `00-remove-old-ids.sql` runs first).

**Client-side changes go through `content/build.py`**, which writes `patch-6.mpq`. Two rules
it enforces, both learned the hard way:

- **Source `Spell.dbc` from the client's own MPQ chain, never the server's extracted copy.**
  The server copy is missing 102 spells the client has. Building from it silently deleted
  them, which showed up in game as "Item is Gone".
- **Custom spell IDs must be below 60000** — use the reserved 38000–38999 block. The 1.12
  wire protocol packs spell IDs as `uint16` in `SMSG_INITIAL_SPELLS`, so anything above
  65535 is truncated with no error on either side. See [docs/SPELL-IDS.md](docs/SPELL-IDS.md).

**Custom icon art** comes from the icon pack at `D:/Games/turtlewow/wowiconpack` — 8,628
PNGs sorted by category. It is kept outside the repo on purpose: at 8,636 files it was 99% of
the file count and nothing references it. Drop a PNG into `content/icons/` and add it to
`CUSTOM_ICONS` to have `build.py` convert it to BLP2 and wire up a `SpellIcon.dbc` row.

**Core changes live in `core/terapin-core.patch`**, applied with `git apply` against the
source tree. Kept small and standalone so a fresh checkout can be brought up to date in one
command.

**In-game commands use `!name` and are handled by Eluna's `PLAYER_EVENT_ON_COMMAND`, never
the chat hook.** `ChatHandler::ParseCommands` treats a leading `!` or `.` as a *command* and
consumes the message, so a handler on `PLAYER_EVENT_ON_CHAT` can never fire — it silently
does nothing while the player gets "There is no such command". The convention is also
inverted from the chat hook: return **false** to mark the command handled, **true** to let
the core answer. This needs `PlayerCommands = 1` in `mangosd.conf`, which is noted there.

**Never put a comment on a config *value* line.** `Config::GetBoolDefault` does an exact
`strcmp` against `"true"`, so `Eluna.UseUnsafeMethods = true  # why` reads as **false** and
silently disables the setting. Comments go on their own line above.

After editing anything in the live install, pull it back in with:

```bash
bash scripts/sync-from-live.sh
```

---

## What's different about this server

### Progression

| | |
|---|---|
| **Stacking** | Everything that can stack now stacks as high as the client allows. |
| **Gathering yield** | 2× on herbs, ore and cloth. |
| **Drop rates** | Tuned down. Vanilla's green rate on a modern loot table meant two or three greens per kill. |
| **Smelting** | Rebanded so Mithril carries you to skill 230 before it greys. |
| **Riding** | Trainable at level 20 instead of 40. Bank bag slots are free. |
| **All weapon skills** | Every character starts trained in every weapon its class can learn — derived from `class_mask`, so it grants exactly what a weapon master would have. |
| **No tools, no workbenches** | 2,127 trade recipes need no hammer, rod, spanner, anvil, forge or alchemy lab. Craft anywhere. |
| **Batch crafting** | `!batch 5` and every recipe makes five, in **one cast and one animation** — the part vanilla's "Create All" does not do. 2,320 recipes qualify. |
| **Survival** | The Simple Wood Tree is chopable from skill 1. It asked for 5 while Survival starts you at 1, so the first tree anyone met was the one tree they could not chop. |

### Mounts

**Gather while mounted.** Mining, Herb Gathering and Skinning — all 17 ranks — carry
`SPELL_ATTR_CASTABLE_WHILE_MOUNTED`, so the cast no longer throws you off.

**Interact with the world while mounted.** Ore veins, herbs, treasure chests, quest objects
and signs no longer dismount you — 1043 chests via a one-line core change (chests have no
`allowMounted` field), the other 948 objects via data.

**Auto-dismount when you go to attack** — and *not* when you are attacked, so riding away
from a mob stays viable. `Unit::Attack` now dismounts instead of refusing outright, which is
also what makes attacking-while-mounted possible at all.

### Salvaging

Break any weapon or armour piece into bars, leather or cloth. **Universal and free** — every
class, level 1, no profession, no reagent. Material follows the item's class; the *tier*
follows item level, so a level 40 breastplate yields Mithril, not Copper. Equipped items are
refused; soulbound is allowed.

### Teleports for everyone

The eight mage teleports, granted to **every class**, General tab, level 1, no reagent, free.

### New content

| | count | notes |
|---|---|---|
| **Shields** | 18 | Six tiers (Copper → Thorium) in three shapes, each with its **own** appearance, gated on `item_level - 5`: 5 / 20 / 33 / 41 / 47 / 58. |
| **White weapons** | 132 | One per weapon type per 5 levels, required level 5→60. Damage from a DPS curve pooled per weapon family, so every two-hander of a tier matches and only speed differs. |
| **Green weapons** | 15 | Closing measured gaps in Blacksmithing's coverage by type and tier. |
| **Class abilities** | 27 | One per class specialization, on the correct spellbook tab. |
| **Thrown abilities** | 2 | Warrior Fury and rogue Combat *spellbook tabs*, not talents. |
| **Recipe icons** | 635 | Trainers showed a generic face for every custom recipe. |
| **Custom NPCs** | — | Class and profession trainers, dungeon questgivers, a supplier, a banker, a Challenge Master. |
| **Summons** | 11 | Call your class trainer, a banker, or the Challenge Master — General tab, free, level 1. |
| **Craftable gear** | 272 | Plate and mail from Blacksmithing, leather from Leatherworking, cloth from Tailoring. Four bands at skill 20 / 90 / 165 / 245. Fills a real hole: before this there was **no craftable epic below skill 226** in any profession. |
| **Inn teleports** | 63 | One per inn, earned by walking in. See [Adventuring](#adventuring). |
| **Dungeon portals** | 29 | One per dungeon, earned at its summoning stone. |

### Adventuring

A new secondary skill, and the way you get around. **Walk into an inn and you keep the road
back to it**; **use the summoning stone outside a dungeon** and you keep the way to its door.
Each is a ten second teleport that breaks on damage, with **no cooldown** — useless in a
fight, and no tedium getting anywhere you have already been.

Nothing is bought and there is no trainer. The only way to get one is to have stood there,
so the tab fills in as a record of where you have actually been. The skill value is the
number of places found (**92** in total), so the bar doubles as a completion meter.
`!inns` and `!portals` list what you have.

It is a **secondary** skill, deliberately — the same category as First Aid — so it never
costs anyone a primary profession slot.

Dungeon portals land you **outside** the door, not inside the instance, so you still walk in
and a group can still gather.

Every field is derived rather than typed: the inn list and its names from `areatrigger_tavern`,
coordinates from `AreaTrigger.dbc`, landing spots from the 48 Innkeeper spawns, town names
from `game_tele`, and level ranges from the hostile spawns around each inn.

### Dungeon mentor scaling

Walk into a dungeon well above its level and your damage, healing and maximum health are
scaled down toward it. Leave and it is gone. A level 60 can run Ragefire Chasm with a level 15
friend without trivialising it — **−70%** there, **−5%** in Stratholme, nothing at all if you
are at level.

**Gear, talents and abilities are untouched.** Only the numbers coming out the other end
change, so good gear still feels good. Type `!scale` to toggle it.

### Optional challenges

Beyond Turtle's ten built-in ones (three of which do nothing on this build — see the
[wiki](wiki/Challenges)), the **Challenge Master** offers **Old School** as a quest.

Die, and you lose **everything** — every item in every bag, and everything you were wearing.
Then a choice: take the spirit healer and you also lose all progress toward your next level,
or walk back to your body and recover **four random pieces** of the gear you had on.

So death is never free, but the long walk is worth making. Drop it with `!oldschool`.

It replaces the earlier Fragile and Butterfingers, which each took a little on death. Three
overlapping death penalties was confusing rather than interesting, and one that actually
hurts is worth more than two that do not.

**Resurrection sickness is off server-wide** — not part of the challenge, it applies to
everyone. Old School is the penalty for dying now; a ten-minute stat debuff on top of it
would just be tedious.

### Client addons

**`TerapinTips`** — shift-hover comparison against your equipped item, and vendor prices on
tooltips.

Also **auto-dismount on attacking**, which has to live here rather than on the server: while
mounted the 1.12 client drops `CMSG_ATTACKSWING` locally, so the server never gets the chance
to react. It cancels the mount, waits for confirmation, then re-issues the action — hooked on
both the Attack key and right-clicking a mob (with drag detection, so turning the camera past
a mob doesn't throw you off). Mount buffs are matched by **name**, since only 41 of this
client's 484 mount spells use an `Ability_Mount_*` icon; `content/gen_mount_names.py`
regenerates that list from the client's own `Spell.dbc`.

Note the attack-key hook only covers the Attack **keybind**. Right-clicking a mob cannot
be intercepted — `TurnOrActionStart/Stop` are protected functions, and wrapping them breaks
every right-click including camera panning.

**`TerapinTravel`** — pins every inn and dungeon you have discovered on the world map and
minimap. `/travel` re-pins on demand.

This is the one piece of Adventuring that *cannot* be done from the server: the world map is
drawn entirely by the client and no packet says "put a pin here". It rides on **pfQuest**
rather than drawing its own layer — `pfMap:AddNode` already handles the map, minimap,
clustering, tooltips and redraws — so it hooks nothing, which matters given what the
right-click hook above cost.

It needs no server messaging and saves nothing: the teleports *are* the record, so it reads
your spellbook and matches by name against generated data. Learn one and the pin appears.

---

## Caveats

- Built for a specific client (OctoWoW on Turtle 1.18.1). Item and spell IDs assume it.
- Balance is tuned for small groups. Raid content is untouched and will feel wrong.
- The server binary in `server/bin/` is built from a patched VMangos tree. If you'd rather
  compile it yourself, apply `core/terapin-core.patch` and build the `mangosd` target.
