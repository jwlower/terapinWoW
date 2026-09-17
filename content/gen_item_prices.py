"""Prices every custom item (90100-90719: the Runed Copper Shield, green weapons, the 18
systematic shields, the 132 white weapons, and the 272 craftable gear pieces) against the
real game's own pricing, instead of leaving it at whatever a clone happened to carry.

THE GAP THIS FILLS
  8 of the 438 have sell_price/buy_price of exactly 0 - unsellable, and free from a vendor
  if buy_price is ever checked. The rest mostly look fine, inherited from whichever real item
  gear.py/shields.py/weapons.py cloned - but "mostly fine" means nobody has actually checked,
  and the same clone-inheritance bug that made armour values a lottery (sql/33's median fix)
  applies here too: a lucky or unlucky clone source, not a measured price.

THE METHOD - THE SAME ONE THAT FIXED ARMOUR VALUES
  sell_price is the MEDIAN of every real item (entry < 38000, Quality > 0, name NOT LIKE
  'Deprecated%', sell_price > 0) sharing the same class, subclass and quality, within a
  window around the target's item level. The window starts at +/-5 and widens by 5 up to 30
  only when there is genuinely nothing nearby - exactly gen_gear.py's ARMOUR_WINDOW logic,
  because it is solving the identical problem: one weird item at the exact item level would
  otherwise set the price outright.

  buy_price = sell_price x 5. Measured, not assumed: among real weapons and armour with both
  prices set, buy is exactly 5x sell for 8317 of the ~10,500 that have any clean ratio at all
  (4x is a distant second at 1765) - see the module's own check in main().

WHY NOT TOUCH THE JEWELCRAFTING REWARDS OR THE OTHER RECIPE-TARGET ITEMS
  Querying "every item any custom spell creates" turns up ~881 rows, but most of those are
  PRE-EXISTING real items (some genuinely obscure - the White Darcy Shirt jewelcrafting
  reward prices at 50000/200000, clearly a leftover Blizzard dev placeholder) that a custom
  recipe merely targets as its output, not new item_template rows this project created. That
  is a different, more delicate question - editing a shared real item's price could matter
  wherever else it appears - and out of scope here. This script only touches the 438 items in
  90100-90719, which exist for no reason other than this project.
"""

import subprocess

MYSQL = r"D:\Games\turtlewow\tortoise-oneclick-compiler\DB\bin\mysql.exe"

ITEM_LO, ITEM_HI = 90100, 90719
BUY_RATIO = 5

WINDOW_START = 5
WINDOW_MAX = 30
MIN_PEERS = 3


def q(sql):
    r = subprocess.run([MYSQL, "-h127.0.0.1", "-P3307", "-umangos", "-pmangos", "tw_world",
                        "-N", "-B", "-e", sql], capture_output=True, text=True, encoding="utf-8")
    if r.returncode:
        raise SystemExit("mysql failed: %s" % r.stderr.strip()[:400])
    return [l.split("\t") for l in r.stdout.strip().split("\n") if l]


def execute(sql):
    r = subprocess.run([MYSQL, "-h127.0.0.1", "-P3307", "-umangos", "-pmangos", "tw_world",
                        "-e", sql], capture_output=True, text=True, encoding="utf-8")
    if r.returncode:
        raise SystemExit("mysql failed: %s" % r.stderr.strip()[:400])


def median(xs):
    xs = sorted(xs)
    n = len(xs)
    return xs[n // 2] if n % 2 else (xs[n // 2 - 1] + xs[n // 2]) // 2


def main():
    # Sanity-check the ratio claim against live data before trusting it.
    ratio_rows = q(
        "SELECT ROUND(buy_price/sell_price) r, COUNT(*) n FROM item_template "
        "WHERE entry < 38000 AND class IN (2,4) AND sell_price > 0 AND buy_price > 0 "
        "GROUP BY r ORDER BY n DESC LIMIT 3")
    top_ratio, top_n = ratio_rows[0]
    print("measured buy/sell ratio for real weapons+armour: %sx is most common (%s items)"
          % (top_ratio, top_n))
    if int(round(float(top_ratio))) != BUY_RATIO:
        raise SystemExit("BUY_RATIO=%d no longer matches the measured %sx - re-check before "
                         "shipping a price nobody verified" % (BUY_RATIO, top_ratio))

    items = q(
        "SELECT entry, name, class, subclass, Quality, item_level, sell_price, buy_price "
        "FROM item_template WHERE entry BETWEEN %d AND %d ORDER BY entry" % (ITEM_LO, ITEM_HI))
    print("pricing %d custom items" % len(items))

    def peers_for(cls, sub, qual, cache={}):
        key = (cls, sub, qual)
        if key not in cache:
            cache[key] = [(int(il), int(sp)) for il, sp in q(
                "SELECT item_level, sell_price FROM item_template "
                "WHERE class = %d AND subclass = %d AND Quality = %d "
                "AND entry < 38000 AND item_level > 0 AND sell_price > 0 "
                "AND name NOT LIKE 'Deprecated%%'" % (cls, sub, qual))]
        return cache[key]

    updates, widened, relaxed, unpriced = [], [], [], []

    for entry, name, cls, sub, qual, ilvl, old_sell, old_buy in items:
        entry, cls, sub, qual, ilvl = int(entry), int(cls), int(sub), int(qual), int(ilvl)
        old_sell, old_buy = int(old_sell), int(old_buy)

        peers = peers_for(cls, sub, qual)
        win = WINDOW_START
        while True:
            near = [sp for il, sp in peers if abs(il - ilvl) <= win]
            if len(near) >= MIN_PEERS or win >= WINDOW_MAX:
                break
            win += 5

        # FALLBACK 1: some quality/subclass combinations are genuinely thin in the real
        # game - only 1 real quality-2 crossbow exists at ANY item level - so no window,
        # however wide, will ever find 3 peers at the exact quality. Relax to the ADJACENT
        # qualities (+/-1, clamped) and search again. Bounded on purpose: pooling a green
        # with real greens-and-blues-nearby is reasonable, pooling it with epics is not.
        was_relaxed = False
        if not near:
            pool = []
            for q2 in (qual - 1, qual + 1):
                if 0 <= q2 <= 4:
                    pool += peers_for(cls, sub, q2)
            win = WINDOW_START
            while True:
                near = [sp for il, sp in pool if abs(il - ilvl) <= win]
                if len(near) >= MIN_PEERS or win >= WINDOW_MAX:
                    break
                win += 5
            was_relaxed = bool(near)

        # FALLBACK 2 - LAST RESORT: some categories are just this sparse in the real game -
        # only 5 quality 0-2 crossbows exist at ANY item level, nearest one 31 levels away.
        # Past that point "widen the window further" stops being a search and starts being a
        # way to avoid admitting there is no close match. The true nearest few, however far
        # away, are the best real reference that exists - closer to "what a crossbow costs"
        # than any invented number would be.
        used_nearest = False
        if not near:
            pool = [(il, sp) for il, sp in peers_for(cls, sub, qual)]
            for q2 in (qual - 1, qual + 1):
                if 0 <= q2 <= 4:
                    pool += peers_for(cls, sub, q2)
            if pool:
                by_dist = sorted((abs(il - ilvl), sp) for il, sp in pool)
                near = [sp for _, sp in by_dist[:MIN_PEERS]]
            used_nearest = bool(near)

        if not near:
            unpriced.append((entry, name, cls, sub, qual, ilvl))
            continue
        if used_nearest:
            relaxed.append((name, cls, sub, qual, ilvl, -1, len(near)))
        elif was_relaxed:
            relaxed.append((name, cls, sub, qual, ilvl, win, len(near)))
        elif win > WINDOW_START:
            widened.append((name, cls, sub, qual, ilvl, win, len(near)))

        new_sell = median(near)
        new_buy = new_sell * BUY_RATIO
        if new_sell != old_sell or new_buy != old_buy:
            updates.append((entry, name, old_sell, old_buy, new_sell, new_buy))

    sql = ["-- ---------------------------------------------------------------------------------------",
           "-- Prices for the 438 custom items (90100-90719), measured against real peers.",
           "--",
           "-- GENERATED by gen_item_prices.py - do not edit by hand.",
           "-- Run against tw_world. IDEMPOTENT.",
           "-- ---------------------------------------------------------------------------------------",
           "", "USE tw_world;", ""]
    for entry, name, old_sell, old_buy, new_sell, new_buy in updates:
        sql.append("-- %-30s sell %6d -> %6d   buy %7d -> %7d"
                   % (name[:30], old_sell, new_sell, old_buy, new_buy))
        sql.append("UPDATE item_template SET sell_price = %d, buy_price = %d WHERE entry = %d;"
                   % (new_sell, new_buy, entry))
    sql.append("")
    sql.append("SELECT COUNT(*) AS repriced FROM item_template "
              "WHERE entry BETWEEN %d AND %d AND sell_price > 0;" % (ITEM_LO, ITEM_HI))

    path = r"D:\Games\turtlewow\TurtleMod\sql\39-custom-item-prices.sql"
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(sql) + "\n")

    print("wrote %s" % path)
    print("  %d item(s) changed price, %d unchanged" % (len(updates), len(items) - len(updates) - len(unpriced)))
    if widened:
        print("  %d item(s) needed a widened window (no close real peer):" % len(widened))
        for name, cls, sub, qual, ilvl, win, n in widened[:10]:
            print("    %-30s class=%d sub=%-2d q=%d ilvl=%-3d -> +/-%d (%d peers)"
                  % (name[:30], cls, sub, qual, ilvl, win, n))
    if relaxed:
        print("  %d item(s) had NO peer at their own quality anywhere - priced against "
              "quality+/-1 instead:" % len(relaxed))
        for name, cls, sub, qual, ilvl, win, n in relaxed:
            where = ("nearest %d regardless of distance" % n) if win < 0 else ("+/-%d (%d peers)" % (win, n))
            print("    %-30s class=%d sub=%-2d q=%d ilvl=%-3d -> quality %d-%d, %s"
                  % (name[:30], cls, sub, qual, ilvl, max(qual-1,0), min(qual+1,4), where))
    if unpriced:
        print("  %d item(s) have NO real peer at all - left untouched, needs a manual look:"
              % len(unpriced))
        for entry, name, cls, sub, qual, ilvl in unpriced:
            print("    %-8d %-30s class=%d sub=%-2d q=%d ilvl=%d" % (entry, name[:30], cls, sub, qual, ilvl))


if __name__ == "__main__":
    main()
