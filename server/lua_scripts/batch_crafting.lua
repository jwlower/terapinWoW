-- Batch crafting: set a quantity once, and every recipe you cast makes that many.
--
--     !batch 5      the next craft, and every craft after it, produces five
--     !batch 1      back to normal
--     !batch        report the current setting
--
-- One cast, one animation, the whole batch at the end of it - which is the part vanilla's
-- "Create All" does not do. Create All queues N separate casts and you sit through N
-- animations; this casts once and resolves the rest server-side.
--
-- WHY A CHAT COMMAND AND NOT A UI CONTROL
--   The quantity box in the trade skill window is Blizzard_TradeSkillUI, and driving it would
--   mean shipping an addon that hooks the craft button. Every previous attempt at hooking a
--   protected client control in this project has ended badly - the right-click addon took out
--   camera panning for the whole game. A chat command needs no client code at all and cannot
--   break anything the client already does.
--
-- WHY THE WORK IS DEFERRED BY A TICK
--   PLAYER_EVENT_ON_SPELL_CAST fires from Spell::prepare, PART WAY THROUGH the cast. The
--   original craft has not taken its own reagents yet, and everything below that line in
--   Spell.cpp keeps using state we would be mutating. salvage.lua learned this the hard way
--   with an ACCESS_VIOLATION; see the header there. So the extra iterations run on a later
--   tick, by which time the first craft has completed normally.
--
-- THE ITEM IS CREATED BEFORE THE REAGENTS ARE TAKEN, deliberately and in that order.
--   If the bags are full, AddItem returns nil and the batch stops WITHOUT having destroyed
--   anything - you keep your materials and simply get fewer items. The reverse order would
--   burn reagents into a full bag. The cost of this choice is stopping one craft early when
--   the only free slot is the one the reagent stack itself would have vacated, which is a
--   far better failure than losing the materials.
--
-- SKILL-UPS ARE ROLLED, NOT GRANTED
--   Every item in the batch rolls for a skill point on exactly the odds the core uses, so
--   batching is a convenience and never a shortcut. See SKILL_CHANCE below.

local MAX_BATCH = 10          -- an accident with a 3-digit number should not eat the bank

local SPELL_EFFECT_CREATE_ITEM = 24

local PLAYER_EVENT_ON_LOGIN      = 3
local PLAYER_EVENT_ON_SPELL_CAST = 5
local PLAYER_EVENT_ON_CHAT       = 18

-- Mirrors Player::SkillGainChance (Player.cpp:6933) and the live mangosd.conf. The core reads
-- SkillChance.* and multiplies by 10 to get per-mille; these are those values already
-- multiplied. IF mangosd.conf CHANGES, CHANGE THESE - a batch would otherwise level a
-- profession at a different rate than a normal craft, which is the one thing it must not do.
local SKILL_CHANCE = {
    orange = 1000,            -- SkillChance.Orange = 100
    yellow = 750,             -- SkillChance.Yellow = 75
    green  = 250,             -- SkillChance.Green  = 25
    grey   = 0,               -- SkillChance.Grey   = 0
}
local SKILL_GAIN = 3          -- SkillGain.Crafting = 3

local DEFER_MS = 250          -- long enough for the original cast to finish resolving

-- guid -> quantity, authoritative in memory; the table below is what survives a logout.
local batchOf = {}

-- entry -> recipe details, or false for "looked up, not a recipe". The world database does not
-- change under a running server, so one lookup per spell for the life of the process.
local recipeOf = {}

-- ---------------------------------------------------------------------------------------
-- Persistence
-- ---------------------------------------------------------------------------------------

local function Persist(guid, qty)
    CharDBExecute(string.format(
        "REPLACE INTO terapin_batch (player_guid, qty) VALUES (%d, %d)", guid, qty))
end

local function LoadQty(guid)
    local q = CharDBQuery(string.format(
        "SELECT qty FROM terapin_batch WHERE player_guid = %d", guid))
    if not q then
        return 1
    end
    return q:GetUInt32(0)
end

-- ---------------------------------------------------------------------------------------
-- What a spell makes, and what it costs
-- ---------------------------------------------------------------------------------------

-- Returns a table {item, amount, reagents = {{entry, count}, ...}, skill, minv, maxv}
-- or false when this spell is not a crafting recipe.
local function Recipe(spellId)
    local cached = recipeOf[spellId]
    if cached ~= nil then
        return cached
    end

    local cols = { "effect1", "effectItemType1", "effectBasePoints1",
                   "RecoveryTime", "categoryRecoveryTime" }
    for i = 1, 8 do
        cols[#cols + 1] = "reagent" .. i
        cols[#cols + 1] = "reagentCount" .. i
    end
    local q = WorldDBQuery(string.format(
        "SELECT %s FROM spell_template WHERE entry = %d", table.concat(cols, ", "), spellId))
    if not q then
        recipeOf[spellId] = false
        return false
    end

    local effect = q:GetUInt32(0)
    local item   = q:GetUInt32(1)
    -- CREATE_ITEM stores "one less than the amount made" in base points, the core's usual
    -- off-by-one for effect values: damage_value = base_points + 1.
    local amount = q:GetInt32(2) + 1
    if effect ~= SPELL_EFFECT_CREATE_ITEM or item == 0 then
        recipeOf[spellId] = false
        return false
    end
    if amount < 1 then
        amount = 1
    end

    -- A COOLDOWN IS THE WHOLE POINT OF THE RECIPE, so those can never be batched.
    -- 28 recipes carry one, and they are the most valuable in the game: Transmute: Arcanite
    -- is 48 hours, the Salt Shaker 72. Batching them by ten would not be a convenience, it
    -- would quietly delete the scarcity the entire alchemy economy rests on.
    if q:GetUInt32(3) > 0 or q:GetUInt32(4) > 0 then
        recipeOf[spellId] = false
        return false
    end

    local reagents = {}
    for i = 1, 8 do
        local entry = q:GetUInt32(3 + i * 2)      -- columns 5,7,9... after the first five
        local count = q:GetUInt32(4 + i * 2)
        if entry > 0 and count > 0 then
            reagents[#reagents + 1] = { entry, count }
        end
    end

    -- The skill line gives both the profession and the colour thresholds for a skill-up.
    local skill, minv, maxv = 0, 0, 0
    local s = WorldDBQuery(string.format(
        "SELECT skill_id, min_value, max_value FROM skill_line_ability WHERE spell_id = %d "
        .. "LIMIT 1", spellId))
    if s then
        skill, minv, maxv = s:GetUInt32(0), s:GetUInt32(1), s:GetUInt32(2)
    end

    -- IT MUST COST SOMETHING, AND IT MUST BE A PROFESSION.
    --
    --   No reagents. Skill 237 (Arcane) holds 18 item-creating spells and every one of them
    --   is reagent-free - the mage's Conjure Food and Conjure Water. Batching those would be
    --   ten stacks of food for a single cast's mana, which is not a convenience, it is a
    --   mana-free food printer. Anything that costs nothing to make cannot be batched.
    --
    --   Skill 354 (Demonology) does take a reagent - a soul shard per Healthstone or
    --   Soulstone - so the cost rule alone would let it through. It is excluded anyway
    --   because you may only carry one of each: a batch of ten would eat ten shards and
    --   leave you with one usable stone. Refusing is kinder than obeying.
    if #reagents == 0 or skill == 237 or skill == 354 then
        recipeOf[spellId] = false
        return false
    end

    local r = { item = item, amount = amount, reagents = reagents,
                skill = skill, minv = minv, maxv = maxv }
    recipeOf[spellId] = r
    return r
end

-- ---------------------------------------------------------------------------------------
-- Making the rest of the batch
-- ---------------------------------------------------------------------------------------

-- Exactly Player::SkillGainChance: grey at or above max_value, green at the midpoint,
-- yellow at min_value, orange below that.
local function GainChance(value, minv, maxv)
    if value >= maxv then
        return SKILL_CHANCE.grey
    end
    if value >= math.floor((maxv + minv) / 2) then
        return SKILL_CHANCE.green
    end
    if value >= minv then
        return SKILL_CHANCE.yellow
    end
    return SKILL_CHANCE.orange
end

local function HasReagents(player, reagents)
    for i = 1, #reagents do
        if player:GetItemCount(reagents[i][1]) < reagents[i][2] then
            return false
        end
    end
    return true
end

-- Returns how many EXTRA items were produced, and why it stopped.
local function MakeExtra(player, r, want)
    local made, stopped = 0, nil
    for _ = 1, want do
        if not HasReagents(player, r.reagents) then
            stopped = "out of materials"
            break
        end
        -- Item first: a full bag must not cost the player their reagents. See the header.
        if not player:AddItem(r.item, r.amount) then
            stopped = "bags are full"
            break
        end
        for i = 1, #r.reagents do
            player:RemoveItem(r.reagents[i][1], r.reagents[i][2])
        end
        made = made + 1

        if r.skill > 0 and player:HasSkill(r.skill) then
            local value = player:GetPureSkillValue(r.skill)
            if value < player:GetPureMaxSkillValue(r.skill) then
                if math.random(1, 1000) <= GainChance(value, r.minv, r.maxv) then
                    player:AdvanceSkill(r.skill, SKILL_GAIN)
                end
            end
        end
    end
    return made, stopped
end

local function OnSpellCast(event, player, spell)
    local guid = player:GetGUIDLow()
    local want = (batchOf[guid] or 1) - 1
    if want < 1 then
        return
    end

    local r = Recipe(spell:GetEntry())
    if not r then
        return
    end

    player:RegisterEvent(function(eventId, delay, repeats, pl)
        if not pl then
            return
        end
        local made, stopped = MakeExtra(pl, r, want)
        if made > 0 then
            pl:SendBroadcastMessage(string.format(
                "|cff33ff99Batch:|r %d extra made (%d total).", made, made + 1))
        end
        if stopped then
            pl:SendBroadcastMessage(string.format(
                "|cffffcc00Batch stopped after %d:|r %s.", made + 1, stopped))
        end
    end, DEFER_MS, 1)
end

-- ---------------------------------------------------------------------------------------
-- The command
-- ---------------------------------------------------------------------------------------

local function OnChat(event, player, msg)
    local arg = string.match(string.lower(msg), "^!batch%s*(%d*)%s*$")
    if not arg then
        return
    end

    local guid = player:GetGUIDLow()
    if arg == "" then
        player:SendBroadcastMessage(string.format(
            "|cff33ff99Batch:|r making |cffffffff%d|r per craft. |cff888888!batch <1-%d> to change.|r",
            batchOf[guid] or 1, MAX_BATCH))
        return false
    end

    local qty = tonumber(arg)
    if qty < 1 then qty = 1 end
    if qty > MAX_BATCH then qty = MAX_BATCH end
    batchOf[guid] = qty
    Persist(guid, qty)

    if qty == 1 then
        player:SendBroadcastMessage("|cff33ff99Batch off.|r One item per craft.")
    else
        player:SendBroadcastMessage(string.format(
            "|cff33ff99Batch on:|r every recipe now makes |cffffffff%d|r. "
            .. "Materials for all %d are taken, and each one rolls for a skill-up as normal.",
            qty, qty))
    end
    return false                                 -- swallow the message
end

local function OnLogin(event, player)
    local guid = player:GetGUIDLow()
    local qty = LoadQty(guid)
    batchOf[guid] = qty
    if qty > 1 then
        player:SendBroadcastMessage(string.format(
            "|cff33ff99Batch crafting is on:|r %d per craft. |cff888888!batch 1 to stop.|r", qty))
    end
end

RegisterPlayerEvent(PLAYER_EVENT_ON_SPELL_CAST, OnSpellCast)
RegisterPlayerEvent(PLAYER_EVENT_ON_CHAT, OnChat)
RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, OnLogin)

print("[Terapin] batch_crafting.lua loaded - !batch <n>, max " .. MAX_BATCH)
