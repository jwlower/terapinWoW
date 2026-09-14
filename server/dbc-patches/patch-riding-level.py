#!/usr/bin/env python
"""
Make riding skill trainable at level 20 instead of 40.

    python patch-riding-level.py            # apply (default target 20)
    python patch-riding-level.py 40         # put it back to stock
    python patch-riding-level.py --check    # report the current value, change nothing

RE-RUN THIS AFTER ANY DBC RE-EXTRACTION. Re-running the extractors overwrites
SkillRaceClassInfo.dbc with the stock file and silently restores the level 40 gate.
It is idempotent, so running it when already patched is a no-op.

WHY A DBC EDIT AND NOT SQL
  WorldSession::SendTrainerList (NPCHandler.cpp:229) filters the trainer list with:

      if (!_player->IsSpellFitByClassAndRace(triggerSpell))
          continue;

  One argument, so pReqlevel is null and Player::IsSpellFitByClassAndRace
  (Player.cpp:21784) takes its `else` branch:

      else                                    // check availble case at train
      {
          if (skillRCEntry->reqLevel && GetLevel() < skillRCEntry->reqLevel)
              return false;
      }

  false -> `continue` -> the spell is left out of the packet altogether. The option is
  absent rather than greyed, and npc_trainer_template.reqlevel is never consulted. The
  same check runs again inside Player::GetTrainerSpellState, so it gates both seeing the
  spell and buying it.

  reqLevel lives in SkillRaceClassInfo.dbc. tw_world does have a `skillraceclassinfo`
  table, but it is EMPTY and the core never reads it - SpellMgr::LoadSkillRaceClassInfoMap
  (SpellMgr.cpp:2670) iterates sSkillRaceClassInfoStore, filled by LoadDBC from the file
  (DBCStores.cpp:280). So SQL cannot move this gate.

  This is a SERVER-side file only. The trainer list is built and filtered on the server,
  so the client's own copy of the DBC is not consulted for this and no client patch is
  needed. DataDir in mangosd.conf decides which copy is authoritative - note the Eluna
  build points its DataDir here, so this one file serves both builds.

FORMAT
  SkillRaceClassInfo.dbc is a WDBC with 8 uint32 fields per record, format string
  "diiiiiix" (DBCfmt.h:57), matching SkillRaceClassInfoEntry (DBCStructure.h:512):
      0 Id   1 skillId   2 raceMask   3 classMask   4 flags   5 reqLevel   6 skillTierId
      7 skillCostIndex (parsed as 'x', ignored)

  The riding record is Id=890, skillId=762 (SKILL_RIDING), raceMask=2047, classMask=1503.

  CAUTION: Id is NOT the record index. The riding row's Id is 890 but it sits at index
  197 of 204 records, so seeking to 20 + 890*32 would land past the end of a 6549-byte
  file. This script always locates the record by scanning for skillId == 762.
"""

import os
import shutil
import struct
import sys

DBC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dbc", "SkillRaceClassInfo.dbc")
SKILL_RIDING = 762
HEADER_SIZE = 20
FIELD_REQLEVEL = 5
EXPECTED_FIELDS = 8
EXPECTED_RECSIZE = 32


def main():
    args = [a for a in sys.argv[1:]]
    check_only = "--check" in args
    args = [a for a in args if a != "--check"]
    target = int(args[0]) if args else 20
    if not 1 <= target <= 60:
        sys.exit("target level must be 1-60, got %d" % target)

    if not os.path.exists(DBC):
        sys.exit("not found: %s" % DBC)

    with open(DBC, "rb") as f:
        data = bytearray(f.read())

    magic, nrec, nfield, recsize, sblock = struct.unpack_from("<4sIIII", data, 0)
    if magic != b"WDBC":
        sys.exit("not a WDBC file (magic %r)" % magic)
    if nfield != EXPECTED_FIELDS or recsize != EXPECTED_RECSIZE:
        sys.exit("unexpected layout: %d fields, %d bytes/record (want %d/%d). "
                 "The DBC version may differ from what this script was written for."
                 % (nfield, nfield and recsize, EXPECTED_FIELDS, EXPECTED_RECSIZE))
    expected_size = HEADER_SIZE + nrec * recsize + sblock
    if len(data) != expected_size:
        sys.exit("size %d != header-implied %d; refusing to touch a malformed file"
                 % (len(data), expected_size))

    hits = []
    for i in range(nrec):
        rec = HEADER_SIZE + i * recsize
        if struct.unpack_from("<I", data, rec + 4)[0] == SKILL_RIDING:
            hits.append(i)

    if not hits:
        sys.exit("no record with skillId %d found in %d records" % (SKILL_RIDING, nrec))

    changed = 0
    for i in hits:
        rec = HEADER_SIZE + i * recsize
        off = rec + FIELD_REQLEVEL * 4
        rid = struct.unpack_from("<I", data, rec)[0]
        cur = struct.unpack_from("<I", data, off)[0]
        if check_only:
            print("record idx %d (Id=%d): reqLevel = %d" % (i, rid, cur))
            continue
        if cur == target:
            print("record idx %d (Id=%d): already %d, nothing to do" % (i, rid, target))
            continue
        struct.pack_into("<I", data, off, target)
        print("record idx %d (Id=%d) at byte %d: reqLevel %d -> %d" % (i, rid, off, cur, target))
        changed += 1

    if check_only or not changed:
        return

    backup = DBC + ".bak-reqlevel40"
    if not os.path.exists(backup):
        shutil.copy2(DBC, backup)
        print("backup written: %s" % os.path.basename(backup))

    with open(DBC, "wb") as f:
        f.write(data)
    print("patched %s (%d record(s)). RESTART mangosd - DBCs load once at startup."
          % (os.path.basename(DBC), changed))


if __name__ == "__main__":
    main()
