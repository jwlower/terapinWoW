# Terapin WoW

A private vanilla (1.12) server on a VMangos-derived core, tuned for **solo and small-group
play**. One to four people who want to actually finish things — not a raid guild.

## Pages

| | |
|---|---|
| [General Changes](General-Changes) | Inventory, gathering, loot, riding, mounts, quality of life. |
| [Combat Changes](Combat-Changes) | What changed about fighting, dying and repairing. |
| [Classes](Classes) | Per-class, with the current state stated honestly. |
| [Professions](Professions) | Per-profession. Blacksmithing is the one with real new content. |
| [Items and Spells](Items-and-Spells) | The catalogue — every custom ID, what it replaced, and why. |
| [Dungeons](Dungeons) | Respawning bosses, no lockouts, one questgiver per dungeon. |
| [Small Group Play](Small-Group-Play) | The whole point. What makes 1–4 players work, and what doesn't. |

Design reasoning and feasibility live in [ROADMAP.md](../blob/main/ROADMAP.md); this wiki
describes what the server **does today**.

## Status legend

Used throughout so you can tell finished work from scaffolding:

| | |
|---|---|
| ✅ **Live** | Done, in the database, playable. |
| 🧪 **Placeholder** | The mechanism works and is proven, but the content is a stand-in. |
| 🟨 **Planned** | Known to be possible; not built. |
| ⛔ **Blocked** | Not possible on this client. The reason is always given. |

## The one rule worth knowing before you change anything

**The client is not a passive renderer.** It enforces a great deal on its own, before the
server ever sees a packet, using its own copy of `Spell.dbc`. Several changes here look like
server work and are not:

- Gathering while mounted is a **client** DBC bit, not a server rule.
- Casting while mounted needed the bit set **client-side only** — the divergence from the
  server is what makes the dismount happen.
- Melee swings and object clicks while mounted **never leave the client**, so no server-side
  fix can reach them.

When something mounted-, cast- or click-related does not behave, check whether the client is
even sending it before writing server code. See [Combat Changes](Combat-Changes#mounts).
