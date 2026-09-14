#!/usr/bin/env bash
# Pull the live server's authored files into this repo.
#
#   bash scripts/sync-from-live.sh
#
# Re-runnable. Copies only things that are AUTHORED or CONFIGURED here - never game data,
# never characters, never accounts. See the exclusions at the bottom of this file for what
# is deliberately left behind and why.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIVE="/d/Games/turtlewow/TortoiseNew/TortoiseCompiledNew"
SRV="$LIVE/server"
MOD="/d/Games/turtlewow/TurtleMod"
CLIENT="/d/Games/turtlewow/client"
TURTLE="/d/Games/turtlewow"

say() { printf '  %-46s %s\n' "$1" "$2"; }

mkdir -p "$REPO"/{docs,core,db/{1-tuning,2-setup,3-content},server/{bin,conf,lua_scripts,dbc-patches,launch},client/AddOns,content,scripts}

echo "== server runtime (binaries, libraries) =="
n=0
for f in "$SRV"/*.exe "$SRV"/*.dll; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in mangosd.exe.*) continue;; esac
    cp -p "$f" "$REPO/server/bin/"; n=$((n+1))
done
say "server/bin" "$n files"

echo "== configs =="
n=0
for f in "$SRV"/*.conf "$SRV"/*.conf.dist; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in *.bak-*|*.before-*) continue;; esac
    cp -p "$f" "$REPO/server/conf/"; n=$((n+1))
done
for f in "$SRV"/*.bat; do [ -e "$f" ] && cp -p "$f" "$REPO/server/launch/"; done
say "server/conf" "$n files (.bak-* and .before-* skipped)"

echo "== eluna scripts =="
cp -p "$SRV"/lua_scripts/*.lua "$REPO/server/lua_scripts/" 2>/dev/null || true
say "server/lua_scripts" "$(ls -1 "$REPO/server/lua_scripts" | wc -l) files"

echo "== dbc patchers (server-side DBC edits, must be re-run after re-extraction) =="
for f in "$SRV"/patch-*.py; do [ -e "$f" ] && cp -p "$f" "$REPO/server/dbc-patches/"; done
say "server/dbc-patches" "$(ls -1 "$REPO/server/dbc-patches" 2>/dev/null | wc -l) files"

echo "== database migrations =="
for f in "$LIVE"/tuning-*.sql;  do [ -e "$f" ] && cp -p "$f" "$REPO/db/1-tuning/"; done
for f in "$LIVE"/setup-*.sql;   do [ -e "$f" ] && cp -p "$f" "$REPO/db/2-setup/"; done
cp -p "$MOD"/sql/*.sql "$REPO/db/3-content/"
say "db/1-tuning"  "$(ls -1 "$REPO/db/1-tuning"  | wc -l) files"
say "db/2-setup"   "$(ls -1 "$REPO/db/2-setup"   | wc -l) files"
say "db/3-content" "$(ls -1 "$REPO/db/3-content" | wc -l) files"

echo "== content pipeline =="
cp -p "$MOD"/*.py "$REPO/content/"
mkdir -p "$REPO/content/tools" "$REPO/content/icons"
cp -p "$MOD"/tools/* "$REPO/content/tools/" 2>/dev/null || true
cp -pr "$MOD"/icons/. "$REPO/content/icons/" 2>/dev/null || true
say "content" "$(ls -1 "$REPO/content"/*.py | wc -l) scripts + tools/ + icons/"

echo "== client addon =="
cp -pr "$CLIENT"/Interface/AddOns/TerapinTips "$REPO/client/AddOns/"
say "client/AddOns/TerapinTips" "$(ls -1 "$REPO/client/AddOns/TerapinTips" | wc -l) files"

echo "== core patches =="
for f in "$TURTLE"/*.patch; do [ -e "$f" ] && cp -p "$f" "$REPO/core/"; done
say "core" "$(ls -1 "$REPO/core" | wc -l) files"

echo "== docs =="
for f in "$MOD"/SPELL-IDS.md "$MOD"/ELUNA.md "$TURTLE"/CUSTOM-NPCS.md "$TURTLE"/BISECT.md; do
    [ -e "$f" ] && cp -p "$f" "$REPO/docs/"
done
say "docs" "$(ls -1 "$REPO/docs" | wc -l) files"

echo
echo "DELIBERATELY NOT COPIED:"
echo "  maps/ vmaps/ mmaps/ dbc/   3.75 GB of data extracted from the client. Regenerate"
echo "                             with the extractors in server/bin - see README."
echo "  tw_char / tw_logon         characters and ACCOUNT PASSWORD HASHES. Never commit"
echo "                             these; scripts/backup-db.ps1 dumps them to a gitignored"
echo "                             folder instead."
echo "  transfer-dumps/            old character and logon dumps - same reason."
echo "  out/patch-6.mpq            27 MB, and derived from the client's own Spell.dbc."
echo "                             Rebuild it with: python content/build.py --install"
echo "  logs/ *.pdb mangosd.exe.*  noise and build artifacts."
