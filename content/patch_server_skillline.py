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


if __name__ == "__main__":
    main()
