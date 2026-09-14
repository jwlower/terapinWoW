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
| [`client/`](client) | The `TerapinTips` addon. |
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
| **Weapons** | 15 | Closing measured gaps in Blacksmithing's coverage by type and tier. |
| **Class abilities** | 27 | One per class specialization, on the correct spellbook tab. |
| **Thrown abilities** | 2 | Warrior Fury and rogue Combat *spellbook tabs*, not talents. |
| **Recipe icons** | 635 | Trainers showed a generic face for every custom recipe. |
| **Custom NPCs** | — | Class and profession trainers, dungeon questgivers, a supplier. |

### Client addon — `TerapinTips`

Shift-hover comparison against your equipped item, and vendor prices on tooltips.

Also **auto-dismount on attacking**, which has to live here rather than on the server: while
mounted the 1.12 client drops `CMSG_ATTACKSWING` locally, so the server never gets the chance
to react. It cancels the mount, waits for confirmation, then re-issues the action — hooked on
both the Attack key and right-clicking a mob (with drag detection, so turning the camera past
a mob doesn't throw you off). Mount buffs are matched by **name**, since only 41 of this
client's 484 mount spells use an `Ability_Mount_*` icon; `content/gen_mount_names.py`
regenerates that list from the client's own `Spell.dbc`.

---

## Caveats

- Built for a specific client (OctoWoW on Turtle 1.18.1). Item and spell IDs assume it.
- Balance is tuned for small groups. Raid content is untouched and will feel wrong.
- The server binary in `server/bin/` is built from a patched VMangos tree. If you'd rather
  compile it yourself, apply `core/terapin-core.patch` and build the `mangosd` target.
