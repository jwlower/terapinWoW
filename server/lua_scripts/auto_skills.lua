-- Every character always has every profession, and weapon/defense skill always sits at its
-- level cap.
--
-- PROFESSIONS: sql/31-start-with-weapon-skills.sql already grants every weapon PROFICIENCY
-- (which weapons you may equip) at creation, by inserting the class's proficiency spells into
-- playercreateinfo_spell/character_spell directly - bypassing the runtime trainer-learn code
-- path entirely, which is where vanilla's real restrictions live (2-primary-profession cap,
-- weapon class gating). This does the same thing for the 10 primary profession skill lines,
-- but via Player:SetSkill instead of a spell grant, since there is no single "you now know
-- this profession" spell that real trainers teach (see gen_gear.py/13-masters-teach-
-- professions.sql's own investigation - profession base ranks are not taught through
-- npc_trainer at all in this data set). SetSkill writes the skill line directly and is the
-- same mechanism a GM's .setskill command uses, so it is equally exempt from the cap check.
--
-- WEAPON/DEFENSE SKILL VALUE: proficiency alone does not raise the numeric skill - vanilla
-- still makes you grind it up through combat use, even though the client-visible MAX already
-- rises for free on every level (Player::UpdateSkillsForLevel, called before this hook fires).
-- So the current VALUE is walked up to match that already-updated MAX on every login and
-- level-up, which is the only gap: nothing here invents a formula, it just stops making you
-- wait for the grind to catch up to a cap the core already gave you.

local PROFESSIONS = {164, 165, 171, 182, 186, 197, 202, 333, 393, 755}
-- Blacksmithing, Leatherworking, Alchemy, Herb Gathering, Mining, Tailoring, Engineering,
-- Enchanting, Skinning, Jewelcrafting - the 10 real primary (2-max, category 11) professions.
-- Cooking/First Aid/Fishing are secondary skills, uncapped and untouched by this.

local PROFESSION_CAP = 300     -- Artisan; skip the 3 rank-up trainer visits, not just the cap

local TRACKED_SKILLS = {
    43, 44, 45, 46, 54, 55, 95, 136, 160, 172, 173, 176, 226, 227, 228, 229, 473,
}
-- The 16 weapon skill lines from 31-start-with-weapon-skills.sql, plus Defense (95). Not
-- Unarmed (162) or Dual Wield (118) - see that file's comment on why those are excluded.

local function GrantProfessions(player)
    for _, skill in ipairs(PROFESSIONS) do
        if not player:HasSkill(skill) then
            player:SetSkill(skill, 1, 1, PROFESSION_CAP)
        end
    end
end

local function MaxWeaponAndDefense(player)
    for _, skill in ipairs(TRACKED_SKILLS) do
        if player:HasSkill(skill) then
            local cap = player:GetPureMaxSkillValue(skill)
            if cap > 0 and player:GetSkillValue(skill) < cap then
                player:SetSkill(skill, 1, cap, cap)
            end
        end
    end
end

local function OnLogin(event, player)
    GrantProfessions(player)
    MaxWeaponAndDefense(player)
end

local function OnLevelChanged(event, player, oldLevel)
    MaxWeaponAndDefense(player)
end

RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, OnLogin)
RegisterPlayerEvent(PLAYER_EVENT_ON_LEVEL_CHANGE, OnLevelChanged)

print("[Terapin] auto_skills.lua loaded")
