"""Build TurtleMod's client patch.

    python build.py --noop     round-trip the client's own Spell.dbc unchanged
    python build.py            build with content (once content is defined)
    python build.py --install  build and copy into the client's Data folder

THE SOURCE FILE MATTERS. The client's effective Spell.dbc lives in patch-5.mpq
(28,018 records). The server's extracted copy has only 27,916 - it is MISSING 102
spells the client has. An earlier attempt built the patch from the server copy and
silently deleted those 102 spells, which showed up in game as "Item is Gone".
Always source from the client's own MPQ chain.

MPQ load order: later patches win, and patch-5 is the highest that carries Spell.dbc,
so patch-6 is the correct slot for an override.
"""

import os
import shutil
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "tools"))

import content        # noqa: E402
import dbc            # noqa: E402
import mpqwrite       # noqa: E402
import mpyq           # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
CLIENT_DATA = r"D:\Games\turtlewow\client\Data"
OUT_DIR = os.path.join(HERE, "out")
OUT_MPQ = os.path.join(OUT_DIR, "patch-6.mpq")
SPELL_PATH = "DBFilesClient\\Spell.dbc"

# Highest-numbered patch wins, so search downwards for the live copy.
SEARCH = ["patch-5.mpq", "patch-4.mpq", "patch-3.mpq", "patch-2.mpq",
          "patch-1.mpq", "patch.MPQ", "dbc.MPQ"]


def read_client_spell_dbc():
    """Return (archive_name, raw bytes) of the Spell.dbc the client actually uses."""
    for name in SEARCH:
        path = os.path.join(CLIENT_DATA, name)
        if not os.path.exists(path):
            continue
        try:
            # listfile=False is essential: several patches have an ENCRYPTED (listfile),
            # and reading it raises "Encryption is not supported yet" during construction.
            # Skipping it lets the archive open normally - the files themselves are not
            # encrypted.
            archive = mpyq.MPQArchive(path, listfile=False)
            data = archive.read_file(SPELL_PATH)
        except Exception as exc:
            print("  %-14s unreadable: %s" % (name, exc))
            continue
        if data:
            return name, data
    raise SystemExit("Spell.dbc not found anywhere in the client MPQ chain")


def main():
    noop = "--noop" in sys.argv
    install = "--install" in sys.argv

    src_name, raw = read_client_spell_dbc()
    print("source: %s (%d bytes)" % (src_name, len(raw)))

    table = dbc.Dbc(raw)
    print("parsed: %d records, %d fields, %d bytes/record"
          % (len(table.records), table.field_count, table.record_size))

    if noop:
        print("\n--noop: no content changes, proving the pipeline only")
    else:
        idx = table.index_by_id()

        mods = getattr(content, "MODIFY", [])
        if mods:
            print("\napplying %d modification(s) to existing spells:" % len(mods))
            for spec in mods:
                # Either match_ids (exact, preferred) or match_name + only_if. Names are
                # not unique - "Teleport: Stormwind" is both the teleport and its
                # LEARN_SPELL wrapper - so ids are the safer selector when you know them.
                ids = spec.get("match_ids")
                # match_where is a predicate over the record, for selections that should not
                # be a hand-maintained id list - "every mount aura", say. A drifting list is
                # worse than no list: it silently stops covering new rows.
                where = spec.get("match_where")
                changed = 0
                for rec in table.records:
                    if where is not None:
                        if not where(rec, content.F):
                            continue
                    elif ids is not None:
                        if rec[0] not in ids:
                            continue
                    else:
                        if table.get_string(rec[content.F["name"]]) != spec["match_name"]:
                            continue
                        if any(rec[content.F[k]] != v
                               for k, v in spec.get("only_if", {}).items()):
                            continue
                    for k, v in spec.get("set", {}).items():
                        rec[content.F[k]] = v & 0xFFFFFFFF
                    # or_set ORs bits in instead of assigning. Needed whenever the matched
                    # records do NOT share a common starting value: the 17 gathering spells
                    # carry Attributes 16, 128 and 65680, so an absolute "set" would wipe
                    # whichever bits the other two groups rely on. Also idempotent, so a
                    # rebuild over an already-patched DBC is a no-op rather than a drift.
                    for k, v in spec.get("or_set", {}).items():
                        rec[content.F[k]] = (rec[content.F[k]] | v) & 0xFFFFFFFF
                    changed += 1
                label = spec.get("match_name") or spec.get("label", "by id")
                print("  %-24s %d record(s) -> set=%s or_set=%s"
                      % (label, changed, spec.get("set", {}), spec.get("or_set", {})))
                least = spec.get("expect_at_least")
                if least is not None and changed < least:
                    raise SystemExit(
                        "MODIFY '%s' matched %d record(s), expected at least %d. Refusing to "
                        "ship a selection that has silently stopped matching."
                        % (label, changed, least))
                if ids is not None and changed != len(ids):
                    raise SystemExit(
                        "MODIFY by id expected %d records, changed %d - an id in %s is not "
                        "in this DBC. Refusing to ship a half-applied edit."
                        % (len(ids), changed, sorted(ids)))

        print("\napplying %d content spell(s):" % len(content.SPELLS))
        for spec in content.SPELLS:
            sid = spec["id"]
            if sid in idx:
                rec = table.records[idx[sid]]
                print("  spell %d already present - updating in place" % sid)
            else:
                src = table.records[idx[spec["clone_from"]]]
                rec = list(src)
                table.records.append(rec)
                print("  spell %d cloned from %d (%s)"
                      % (sid, spec["clone_from"],
                         table.get_string(src[content.F["name"]])))
            rec[0] = sid

            # Strings are offsets into the trailing block. Blank the non-enUS locale
            # slots so no stale text from the clone source shows up for other clients.
            for off in range(1, 8):
                rec[content.F["name"] + off] = 0
                rec[content.F["rank"] + off] = 0
                rec[content.F["desc"] + off] = 0
            rec[content.F["name"]] = table.add_string(spec["name"])
            rec[content.F["rank"]] = table.add_string(spec.get("rank", ""))
            rec[content.F["desc"]] = table.add_string(spec.get("desc", ""))

            for key, val in spec["overrides"].items():
                rec[content.F[key]] = val & 0xFFFFFFFF

            print("     %-22s duration_idx=%d interrupt=0x%X points=%d aura=%d cd=%dms"
                  % (spec["name"], rec[content.F["DurationIndex"]],
                     rec[content.F["AuraInterruptFlags"]],
                     rec[content.F["basePoints1"]], rec[content.F["aura1"]],
                     rec[content.F["RecoveryTime"]]))

        # Per-spell icons, applied LAST.
        #
        # This has to run after the content spells above, not before: a cloned spell copies
        # every field from its source, icon included, so setting an icon first meant the
        # clone silently overwrote it. Heavy Throw kept Throw's icon and its trainer wrapper
        # kept Battle Shout's, which is exactly what shipped before this was moved.
        by_id = dict(getattr(content, "SPELL_ICON_BY_ID", {}))
        # Hand-picked art wins over the item-derived recipe icons.
        for spec in getattr(content, "CUSTOM_ICONS", []):
            for sid in spec["spells"]:
                by_id[sid] = spec["id"]
        if by_id:
            hit = 0
            for rec in table.records:
                icon = by_id.get(rec[0])
                if icon:
                    rec[content.F["icon"]] = icon & 0xFFFFFFFF
                    hit += 1
            print("\nspell icons: set on %d of %d spell(s)" % (hit, len(by_id)))

        # The client expects records ordered by id.
        table.records.sort(key=lambda r: r[0])

    rebuilt = table.pack()
    if noop and rebuilt != raw:
        raise SystemExit("ROUND-TRIP FAILED: repacked file differs from the original.\n"
                         "The DBC reader/writer is lossy; fix that before adding content.")
    print("round-trip: repacked %d bytes, identical to source: %s"
          % (len(rebuilt), rebuilt == raw))

    files = [(SPELL_PATH, rebuilt)]

    # ---- SkillLineAbility.dbc: files a recipe under its profession, client-side ----
    sla_specs = getattr(content, "SKILL_LINE_ABILITY", [])
    if sla_specs and not noop:
        sla_name = "DBFilesClient\\SkillLineAbility.dbc"
        sla_src, sla_raw = None, None
        for arch_name in SEARCH:
            p = os.path.join(CLIENT_DATA, arch_name)
            if not os.path.exists(p):
                continue
            try:
                d = mpyq.MPQArchive(p, listfile=False).read_file(sla_name)
            except Exception:
                continue
            if d:
                sla_src, sla_raw = arch_name, d
                break
        if sla_raw is None:
            raise SystemExit("SkillLineAbility.dbc not found in the client MPQ chain")

        sla = dbc.Dbc(sla_raw)
        print("\nSkillLineAbility.dbc from %s: %d records, %d fields"
              % (sla_src, len(sla.records), sla.field_count))

        # Column order confirmed against the live row for spell 2667:
        #   [id, skill, spell, racemask, classmask, _, _, reqSkillValue, _, _, max, min, ...]
        COL = {"id": 0, "skill": 1, "spell": 2, "race_mask": 3, "class_mask": 4,
               "req_skill_value": 7, "max_value": 10, "min_value": 11}
        probe = [r for r in sla.records if r[COL["spell"]] == 2667]
        if not probe or probe[0][COL["req_skill_value"]] != 90:
            raise SystemExit("SkillLineAbility column order is not what was expected - "
                             "refusing to write a row that would land in wrong fields")
        print("  column order verified against spell 2667")

        existing = dict((r[COL["spell"]], i) for i, r in enumerate(sla.records))
        for spec in sla_specs:
            if spec["spell"] in existing:
                rec = sla.records[existing[spec["spell"]]]
                print("  spell %d already filed - updating" % spec["spell"])
            else:
                rec = [0] * sla.field_count
                sla.records.append(rec)
            # Only write the fields the spec actually names.
            #
            # A blanket spec.get(key, 0) would zero anything omitted - which is harmless on
            # a freshly zeroed new record, but destroys an EXISTING row when the spec is a
            # partial edit. The smelting band changes name only spell/min/max, and would
            # otherwise have had their `id` overwritten with 0.
            for key, col in COL.items():
                if key in spec:
                    rec[col] = spec[key] & 0xFFFFFFFF
            print("  spell %d -> skill %s at %s skill (%s-%s)"
                  % (spec["spell"], spec.get("skill", "-"),
                     spec.get("req_skill_value", "-"),
                     spec.get("min_value", "-"), spec.get("max_value", "-")))
        # Removing a spell's skill-line row is what moves it to the GENERAL spellbook tab -
        # General is the absence of a skill line, not a line of its own. It also drops any
        # class_mask gating, which is how a mage-only spell becomes available to everyone.
        drop = set(getattr(content, "SKILL_LINE_ABILITY_REMOVE", []))
        if drop:
            before = len(sla.records)
            sla.records = [r for r in sla.records if r[COL["spell"]] not in drop]
            print("  removed %d row(s) for %d spell(s) -> those spells move to General"
                  % (before - len(sla.records), len(drop)))

        sla.records.sort(key=lambda r: r[0])
        files.append((sla_name, sla.pack()))

    # ---- SkillLine.dbc: mints a whole new skill, and with it a spellbook tab ----
    #
    # A SkillLineAbility row files a spell under a skill. If that SKILL does not exist in the
    # client's own SkillLine.dbc, the row points at nothing and the spell is dropped just as
    # surely as if it had no row at all - so a new profession needs both files, not one.
    #
    # CATEGORY MATTERS MORE THAN IT LOOKS. Category 11 is a PRIMARY profession and the client
    # enforces the two-profession limit on those. Adventuring uses category 9, the same as
    # First Aid and Survival, so it can never cost anyone their Blacksmithing slot.
    skill_specs = getattr(content, "SKILL_LINE", [])
    if skill_specs and not noop:
        sl_name = "DBFilesClient\\SkillLine.dbc"
        sl_src, sl_raw = None, None
        for arch_name in SEARCH:
            p = os.path.join(CLIENT_DATA, arch_name)
            if not os.path.exists(p):
                continue
            try:
                d = mpyq.MPQArchive(p, listfile=False).read_file(sl_name)
            except Exception:
                continue
            if d:
                sl_src, sl_raw = arch_name, d
                break
        if sl_raw is None:
            raise SystemExit("SkillLine.dbc not found in the client MPQ chain")

        sl = dbc.Dbc(sl_raw)
        print("\nSkillLine.dbc from %s: %d records, %d fields"
              % (sl_src, len(sl.records), sl.field_count))

        # Column order confirmed against Blacksmithing (164), which must read category 11.
        SL_ID, SL_CAT, SL_NAME, SL_DESC = 0, 1, 3, 12
        probe = [r for r in sl.records if r[SL_ID] == 164]
        if (not probe or probe[0][SL_CAT] != 11
                or sl.get_string(probe[0][SL_NAME]) != "Blacksmithing"):
            raise SystemExit("SkillLine column order is not what was expected - "
                             "refusing to write a row that would land in wrong fields")
        print("  column order verified against skill 164 (Blacksmithing)")

        existing = dict((r[SL_ID], i) for i, r in enumerate(sl.records))
        for spec in skill_specs:
            if spec["id"] in existing:
                rec = sl.records[existing[spec["id"]]]
                print("  skill %d already present - updating" % spec["id"])
            else:
                rec = [0] * sl.field_count
                sl.records.append(rec)
            rec[SL_ID] = spec["id"]
            rec[SL_CAT] = spec["category"]
            rec[SL_NAME] = sl.add_string(spec["name"])
            if spec.get("description"):
                rec[SL_DESC] = sl.add_string(spec["description"])
            print("  skill %d -> %-16s category %d"
                  % (spec["id"], spec["name"], spec["category"]))

        sl.records.sort(key=lambda r: r[0])
        files.append((sl_name, sl.pack()))

    # ---- Lock.dbc: the skill a gathering node demands ----
    #
    # The server reads its own copy of this file, so every edit here has to be mirrored by
    # patch_server_dbc.py. If they disagree the node still refuses to open - the server has
    # the final say - but the client will happily show it as harvestable first, which is a
    # worse experience than either side saying no on its own.
    lock_specs = getattr(content, "LOCK_SKILL", [])
    if lock_specs and not noop:
        lk_name = "DBFilesClient\\Lock.dbc"
        lk_src, lk_raw = None, None
        for arch_name in SEARCH:
            p = os.path.join(CLIENT_DATA, arch_name)
            if not os.path.exists(p):
                continue
            try:
                d = mpyq.MPQArchive(p, listfile=False).read_file(lk_name)
            except Exception:
                continue
            if d:
                lk_src, lk_raw = arch_name, d
                break
        if lk_raw is None:
            raise SystemExit("Lock.dbc not found in the client MPQ chain")

        lk = dbc.Dbc(lk_raw)
        print("\nLock.dbc from %s: %d records, %d fields"
              % (lk_src, len(lk.records), lk.field_count))

        # Layout: id, then 8 x type, 8 x lock-type index, 8 x required skill value.
        # Verified against lock 1660, the next tier of the same woodcutting ladder.
        LK_TYPE, LK_INDEX, LK_REQ = 1, 9, 17
        probe = [r for r in lk.records if r[0] == 1660]
        if not probe or probe[0][LK_TYPE] != 2 or probe[0][LK_REQ] != 125:
            raise SystemExit("Lock.dbc column order is not what was expected - "
                             "refusing to write a value into the wrong field")
        print("  column order verified against lock 1660 (woodcutting, 125)")

        index = dict((r[0], r) for r in lk.records)
        for spec in lock_specs:
            rec = index.get(spec["lock"])
            if not rec:
                raise SystemExit("Lock %d is not in Lock.dbc" % spec["lock"])
            slot = spec["slot"]
            was = rec[LK_REQ + slot]
            rec[LK_REQ + slot] = spec["required"] & 0xFFFFFFFF
            print("  lock %-6d slot %d  %d -> %d   %s"
                  % (spec["lock"], slot, was, spec["required"], spec.get("note", "")))

        files.append((lk_name, lk.pack()))

    # ---- SpellIcon.dbc: new icon textures for recipes whose item icon had no entry ----
    #
    # SpellIcon.dbc ships with ~1463 textures while items reference tens of thousands, so
    # most recipes could not point at their own item's icon until these rows exist. Two
    # fields only: id, and the texture path.
    # ---- Custom icon art: PNG -> BLP2, shipped inside the patch ----
    #
    # The image and its SpellIcon.dbc row have to travel together: a row pointing at a
    # texture that is not in the archive renders as nothing at all.
    custom_icons = getattr(content, "CUSTOM_ICONS", [])
    icon_rows_from_art = []
    if custom_icons and not noop:
        import blp                                   # noqa: E402
        from PIL import Image                        # noqa: E402
        print("\nconverting %d custom icon(s) PNG -> BLP2:" % len(custom_icons))
        for spec in custom_icons:
            png = os.path.join(HERE, spec["png"])
            if not os.path.exists(png):
                raise SystemExit("custom icon source missing: %s" % png)
            img = Image.open(png).convert("RGBA")
            original = img.size
            if img.size != (64, 64):
                img = img.resize((64, 64), Image.LANCZOS)   # interface icons are 64x64
            # DXT1, not palettised: every icon in the client is colorEncoding 2, so a
            # palettised file gets decoded AS DXT and renders as a collage of garbage.
            data = blp.write_dxt1(img)
            # The FILE keeps its .blp extension; the SpellIcon.dbc ROW must NOT have one.
            # Every one of the client's 1502 rows is stored bare ("Interface\Icons\Temp"),
            # because the client appends .blp itself - a row ending in .blp resolves to
            # "name.blp.blp" and renders nothing, silently.
            path = "Interface\\Icons\\%s.blp" % spec["name"]
            files.append((path, data))
            icon_rows_from_art.append((spec["id"], path[:-4]))
            print("  %-28s %dx%d -> 64x64  %6d bytes  icon id %d  -> %s"
                  % (os.path.basename(png), original[0], original[1], len(data),
                     spec["id"], path))

    new_icons = list(getattr(content, "SPELL_ICONS_ADD", [])) + icon_rows_from_art
    if new_icons and not noop:
        icon_name = "DBFilesClient\\SpellIcon.dbc"
        icon_src, icon_raw = None, None
        for arch_name in SEARCH:
            p = os.path.join(CLIENT_DATA, arch_name)
            if not os.path.exists(p):
                continue
            try:
                d = mpyq.MPQArchive(p, listfile=False).read_file(icon_name)
            except Exception:
                continue
            if d:
                icon_src, icon_raw = arch_name, d
                break
        if icon_raw is None:
            raise SystemExit("SpellIcon.dbc not found in the client MPQ chain")

        icons = dbc.Dbc(icon_raw)
        print("\nSpellIcon.dbc from %s: %d records, %d fields"
              % (icon_src, len(icons.records), icons.field_count))
        have = set(r[0] for r in icons.records)
        added = 0
        for iid, texture in new_icons:
            if iid in have:
                continue
            rec = [0] * icons.field_count
            rec[0] = iid
            rec[1] = icons.add_string(texture)
            icons.records.append(rec)
            added += 1
        icons.records.sort(key=lambda r: r[0])
        print("  added %d new icon texture(s) -> %d total" % (added, len(icons.records)))
        files.append((icon_name, icons.pack()))

    if not os.path.isdir(OUT_DIR):
        os.makedirs(OUT_DIR)
    archive = mpqwrite.build(files)
    with open(OUT_MPQ, "wb") as f:
        f.write(archive)
    print("wrote %s (%.1f MB)" % (OUT_MPQ, len(archive) / 1048576.0))

    mpqwrite.verify(OUT_MPQ, dict(files))
    print("VERIFY OK: all %d file(s) read back byte-identical" % len(files))

    if install:
        dest = os.path.join(CLIENT_DATA, "patch-6.mpq")
        shutil.copy2(OUT_MPQ, dest)
        print("installed -> %s" % dest)
    else:
        print("\nnot installed. Re-run with --install, or copy out/patch-6.mpq to Data\\")


if __name__ == "__main__":
    main()
