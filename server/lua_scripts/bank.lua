-- Strongbox: open your bank from anywhere.
--
-- WHY NO CORE CHANGE WAS NEEDED
--   WorldSession::CanUseBank (ItemHandler.cpp:1393) already has a bankerless mode:
--
--       bool isUsingBankCommand = (bankerGUID == GetPlayer()->GetObjectGuid() &&
--                                  bankerGUID == m_currentBankerGUID);
--       if (!isUsingBankCommand) { ...require a real banker NPC in range... }
--
--   so when the banker guid IS the player, the proximity check is skipped entirely. That
--   is how the .bank GM command works (Commands.cpp:3664). SendShowBank sets
--   m_currentBankerGUID as a side effect (NPCHandler.cpp:107), which is what makes the
--   comparison above hold for every LATER bank packet too - so deposits and withdrawals
--   work, not just the window opening.
--
-- WHY THE WORK IS NOT DEFERRED, UNLIKE salvage.lua
--   That script had to defer because it DESTROYED the item the running spell still held a
--   pointer to. This one only sends a packet and sets a guid - it frees nothing and the
--   spell's own state is untouched - so it is safe to run inline from the cast hook.
--
-- Player:SendShowBank takes a WorldObject and uses its guid (PlayerMethods.h:1908), so
-- passing the player themselves is the whole trick.

local STRONGBOX_SPELL = 38601

local function OnSpellCast(event, player, spell, skipCheck)
    if spell:GetEntry() ~= STRONGBOX_SPELL then
        return
    end
    player:SendShowBank(player)
end

RegisterPlayerEvent(5, OnSpellCast)   -- 5 = PLAYER_EVENT_ON_SPELL_CAST

print("[Terapin] bank.lua loaded - spell " .. STRONGBOX_SPELL)
