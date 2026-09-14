#!/usr/bin/env python
"""
Make the 6 bank bag slots free to unlock.

    python patch-bank-slot-prices.py            # apply (price 0)
    python patch-bank-slot-prices.py --restore  # put the vanilla prices back
    python patch-bank-slot-prices.py --check    # report current prices, change nothing

RE-RUN AFTER ANY DBC RE-EXTRACTION. The extractors overwrite BankBagSlotPrices.dbc with
the stock file and silently restore the prices. Idempotent, so re-running is harmless.

WHY THIS IS NEEDED ALONGSIDE THE SQL
  tuning-bank-slots.sql sets the slot count directly on characters that already exist.
  It cannot help a character created later, because the count is initialised at creation
  and there is no data hook to change that without code (or Eluna, which the TortoiseNew
  binary does not have).

  Setting the price to 0 covers new characters instead: all six slots are still unlocked
  at a banker, but cost nothing. One visit, six clicks, no gold.

WHERE THE PRICE COMES FROM
  WorldSession::HandleBuyBankSlotOpcode (ItemHandler.cpp:1085):

      uint32 slot = _player->GetBankBagSlotCount();
      ++slot;
      BankBagSlotPricesEntry const* slotEntry = sBankBagSlotPricesStore.LookupEntry(slot);
      if (!slotEntry) { ...ERR_BANKSLOT_FAILED_TOO_MANY... }
      uint32 price = slotEntry->price;
      if (_player->GetMoney() < price) { ...ERR_BANKSLOT_INSUFFICIENT_FUNDS... }
      _player->SetBankBagSlotCount(slot);

  So the cost is pure DBC data, keyed by the slot number being bought.

SLOTS 7-12 ARE LEFT UNBUYABLE ON PURPOSE
  The file has 12 rows; the last six are priced 999999999 because only SIX bag slots
  exist - BANK_SLOT_BAG_START 63 .. BANK_SLOT_BAG_END 69 (Player.h:631). Note the handler
  bails out only when LookupEntry returns nothing, and rows 7-12 DO exist, so zeroing
  their price would let a player push GetBankBagSlotCount past the end of that field
  range. The prohibitive price is the only thing stopping it. Do not touch them.

FORMAT
  WDBC, 2 uint32 fields per record ("ni", DBCfmt.h:28), matching BankBagSlotPricesEntry
  (DBCStructure.h:81): 0 = ID (the slot number), 1 = price in copper.
  Stock values: 1000, 10000, 100000, 250000, 500000, 1000000 (10s to 100g, ~186g total).
"""

import os
import shutil
import struct
import sys

DBC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dbc", "BankBagSlotPrices.dbc")
MAX_REAL_SLOT = 6                 # BANK_SLOT_BAG_END - BANK_SLOT_BAG_START
STOCK = {1: 1000, 2: 10000, 3: 100000, 4: 250000, 5: 500000, 6: 1000000}
HEADER_SIZE = 20


def main():
    args = sys.argv[1:]
    check_only = "--check" in args
    restore = "--restore" in args

    if not os.path.exists(DBC):
        sys.exit("not found: %s" % DBC)

    with open(DBC, "rb") as f:
        data = bytearray(f.read())

    magic, nrec, nfield, recsize, sblock = struct.unpack_from("<4sIIII", data, 0)
    if magic != b"WDBC":
        sys.exit("not a WDBC file (magic %r)" % magic)
    if nfield != 2 or recsize != 8:
        sys.exit("unexpected layout: %d fields, %d bytes/record (want 2/8)" % (nfield, recsize))
    if len(data) != HEADER_SIZE + nrec * recsize + sblock:
        sys.exit("size mismatch; refusing to touch a malformed file")

    changed = 0
    for i in range(nrec):
        rec = HEADER_SIZE + i * recsize
        slot, price = struct.unpack_from("<2I", data, rec)

        if slot > MAX_REAL_SLOT:
            if check_only:
                print("slot %2d: %d  (left unbuyable - no field range for it)" % (slot, price))
            continue

        target = STOCK[slot] if restore else 0
        if check_only:
            print("slot %2d: %d" % (slot, price))
            continue
        if price == target:
            print("slot %2d: already %d, nothing to do" % (slot, target))
            continue
        struct.pack_into("<I", data, rec + 4, target)
        print("slot %2d: %d -> %d" % (slot, price, target))
        changed += 1

    if check_only or not changed:
        return

    backup = DBC + ".bak-stockprices"
    if not os.path.exists(backup):
        shutil.copy2(DBC, backup)
        print("backup written: %s" % os.path.basename(backup))

    with open(DBC, "wb") as f:
        f.write(data)
    print("patched %s (%d rows). RESTART mangosd - DBCs load once at startup."
          % (os.path.basename(DBC), changed))


if __name__ == "__main__":
    main()
