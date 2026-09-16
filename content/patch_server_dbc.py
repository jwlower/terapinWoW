"""Adds the Adventuring skill to the SERVER's own SkillLine.dbc.

WHY THIS EXISTS AT ALL - THE CLIENT PATCH IS NOT ENOUGH
  The server keeps its own copy of the DBC files in server/dbc/, entirely separate from the
  client's MPQ chain, and Player::SetSkill (Player.cpp, the "add" branch) does:

      SkillLineEntry const* pSkill = sSkillLineStore.LookupEntry(id);
      if (!pSkill) { sLog.outError("Skill not found in SkillLineStore: skill #%u", id); return; }

  So a skill the server has never heard of is not an error the player ever sees. SetSkill
  simply returns, Adventuring is never granted, every inn teleport is filed under a skill the
  character does not have, and the client drops all 63 of them - with the only trace being one
  line in the server log. That is the same shape of silent failure as the corpse chest
  (Eluna.UseUnsafeMethods) and the empty trainer window (no skill_line_ability row).

  Both files need the row. build.py writes the client's; this writes the server's.

IDEMPOTENT: re-running updates the existing row rather than adding a second one.
A BACKUP is written beside the file the first time it is changed.
"""

import os
import shutil
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "tools"))
import dbc      # noqa: E402

import inns     # noqa: E402

SERVER_DBC = r"D:\Games\turtlewow\TortoiseNew\TortoiseCompiledNew\server\dbc\SkillLine.dbc"
BACKUP = SERVER_DBC + ".bak-before-adventuring"

SL_ID, SL_CAT, SL_NAME, SL_DESC = 0, 1, 3, 12


def main():
    t = dbc.load(SERVER_DBC)
    print("server SkillLine.dbc: %d records, %d fields" % (len(t.records), t.field_count))

    # Same guard as build.py: never write a row into fields we have not proven.
    probe = [r for r in t.records if r[SL_ID] == 164]
    if (not probe or probe[0][SL_CAT] != 11
            or t.get_string(probe[0][SL_NAME]) != "Blacksmithing"):
        raise SystemExit("SkillLine column order is not what was expected - "
                         "refusing to write a row that would land in wrong fields")
    print("  column order verified against skill 164 (Blacksmithing)")

    if not os.path.exists(BACKUP):
        shutil.copy2(SERVER_DBC, BACKUP)
        print("  backup -> %s" % os.path.basename(BACKUP))

    existing = dict((r[SL_ID], i) for i, r in enumerate(t.records))
    sid = inns.SKILL_ADVENTURING
    if sid in existing:
        rec = t.records[existing[sid]]
        print("  skill %d already present - updating" % sid)
    else:
        rec = [0] * t.field_count
        t.records.append(rec)
        print("  skill %d added" % sid)

    rec[SL_ID] = sid
    rec[SL_CAT] = inns.SKILL_CATEGORY
    rec[SL_NAME] = t.add_string("Adventuring")
    rec[SL_DESC] = t.add_string("The roads you have walked, and the way back to them.")

    t.records.sort(key=lambda r: r[SL_ID])
    with open(SERVER_DBC, "wb") as fh:
        fh.write(t.pack())

    check = dbc.load(SERVER_DBC)
    got = [r for r in check.records if r[SL_ID] == sid]
    if not got:
        raise SystemExit("wrote the file but skill %d is not in it" % sid)
    print("  VERIFY OK: %d records, skill %d = %-12s category %d"
          % (len(check.records), sid, check.get_string(got[0][SL_NAME]), got[0][SL_CAT]))


# ---------------------------------------------------------------------------------------
# Lock.dbc - what skill a gathering node demands before it opens
#
# The same two-copies problem as SkillLine: build.py edits the CLIENT's Lock.dbc inside
# patch-6.mpq, and this edits the server's. The server has the final say on whether a node
# opens, so a mismatch shows as a node the client offers and the server then refuses.
# ---------------------------------------------------------------------------------------
SERVER_LOCK = r"D:\Games\turtlewow\TortoiseNew\TortoiseCompiledNew\server\dbc\Lock.dbc"
LOCK_BACKUP = SERVER_LOCK + ".bak-before-terapin"

LK_TYPE, LK_INDEX, LK_REQ = 1, 9, 17


def patch_locks():
    import content

    specs = getattr(content, "LOCK_SKILL", [])
    if not specs:
        return

    t = dbc.load(SERVER_LOCK)
    print("\nserver Lock.dbc: %d records, %d fields" % (len(t.records), t.field_count))

    # Same guard as build.py, against the next tier of the same woodcutting ladder.
    probe = [r for r in t.records if r[0] == 1660]
    if not probe or probe[0][LK_TYPE] != 2 or probe[0][LK_REQ] != 125:
        raise SystemExit("Lock.dbc column order is not what was expected - "
                         "refusing to write a value into the wrong field")
    print("  column order verified against lock 1660 (woodcutting, 125)")

    if not os.path.exists(LOCK_BACKUP):
        shutil.copy2(SERVER_LOCK, LOCK_BACKUP)
        print("  backup -> %s" % os.path.basename(LOCK_BACKUP))

    index = dict((r[0], r) for r in t.records)
    for spec in specs:
        rec = index.get(spec["lock"])
        if not rec:
            raise SystemExit("Lock %d is not in the server's Lock.dbc" % spec["lock"])
        was = rec[LK_REQ + spec["slot"]]
        rec[LK_REQ + spec["slot"]] = spec["required"] & 0xFFFFFFFF
        print("  lock %-6d slot %d  %d -> %d   %s"
              % (spec["lock"], spec["slot"], was, spec["required"], spec.get("note", "")))

    with open(SERVER_LOCK, "wb") as fh:
        fh.write(t.pack())

    check = dbc.load(SERVER_LOCK)
    cindex = dict((r[0], r) for r in check.records)
    for spec in specs:
        got = cindex[spec["lock"]][LK_REQ + spec["slot"]]
        if got != spec["required"]:
            raise SystemExit("wrote the file but lock %d reads %d, wanted %d"
                             % (spec["lock"], got, spec["required"]))
    print("  VERIFY OK: %d lock(s) now require what they should" % len(specs))


# ---------------------------------------------------------------------------------------
# SkillRaceClassInfo.dbc - which races and classes a skill applies to
#
# The client needs this or the skill is granted but never listed. The server keeps its own
# copy and builds mSkillRaceClassInfoMap from it, so both are written for parity.
# ---------------------------------------------------------------------------------------
SERVER_RC = r"D:\Games\turtlewow\TortoiseNew\TortoiseCompiledNew\server\dbc\SkillRaceClassInfo.dbc"
RC_BACKUP = SERVER_RC + ".bak-before-terapin"


def patch_race_class():
    import content

    specs = getattr(content, "SKILL_RACE_CLASS", [])
    if not specs:
        return

    t = dbc.load(SERVER_RC)
    print("\nserver SkillRaceClassInfo.dbc: %d records, %d fields"
          % (len(t.records), t.field_count))

    probe = [r for r in t.records if r[1] == 129]
    if not probe or probe[0][2] != 2047 or probe[0][3] != 1503:
        raise SystemExit("SkillRaceClassInfo column order is not what was expected - "
                         "refusing to write a row that would land in wrong fields")
    print("  column order verified against skill 129 (First Aid)")

    if not os.path.exists(RC_BACKUP):
        shutil.copy2(SERVER_RC, RC_BACKUP)
        print("  backup -> %s" % os.path.basename(RC_BACKUP))

    by_id = dict((r[0], i) for i, r in enumerate(t.records))
    for spec in specs:
        if spec["id"] in by_id:
            rec = t.records[by_id[spec["id"]]]
            print("  id %d already present - updating" % spec["id"])
        else:
            rec = [0] * t.field_count
            t.records.append(rec)
        rec[0] = spec["id"]
        rec[1] = spec["skill"]
        rec[2] = spec["race_mask"]
        rec[3] = spec["class_mask"]
        rec[4] = spec["flags"]
        rec[5] = spec.get("req_level", 0)
        rec[6] = spec.get("tier", 0)
        rec[7] = spec.get("cost", 0)
        print("  skill %-4d -> race %d / class %d flags %d   %s"
              % (spec["skill"], spec["race_mask"], spec["class_mask"], spec["flags"],
                 spec.get("note", "")))

    t.records.sort(key=lambda r: r[0])
    with open(SERVER_RC, "wb") as fh:
        fh.write(t.pack())

    check = dbc.load(SERVER_RC)
    for spec in specs:
        if not any(r[1] == spec["skill"] for r in check.records):
            raise SystemExit("wrote the file but skill %d has no row" % spec["skill"])
    print("  VERIFY OK: %d row(s) present" % len(specs))


if __name__ == "__main__":
    main()
    patch_locks()
    patch_race_class()
