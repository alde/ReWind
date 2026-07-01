local ReWind = _G.ReWind
local Core = ReWind:NewModule("Core", "AceEvent-3.0")

-- Abilities that trigger/benefit from Combo Strikes mastery.
-- Matches the 14 "Combo Strikes: X" spells on Wowhead minus
-- Storm, Earth, and Fire (removed in Midnight).
local COMBO_STRIKES_SPELLS = {
    [100780]  = true, -- Tiger Palm
    [100784]  = true, -- Blackout Kick
    [107428]  = true, -- Rising Sun Kick
    [113656]  = true, -- Fists of Fury
    [101546]  = true, -- Spinning Crane Kick
    [152175]  = true, -- Whirling Dragon Punch
    [392983]  = true, -- Strike of the Windlord
    [117952]  = true, -- Crackling Jade Lightning
    [322109]  = true, -- Touch of Death
    [468179]  = true, -- Rushing Wind Kick
    [1217413] = true, -- Slicing Winds
    [443028]  = true, -- Celestial Conduit (hero talent)
    [1272696] = true, -- Zenith Stomp
}

local SOUND_BREAK = 173248      -- go_stackofwood_break02
local SOUND_ZENITH_READY = 73280 -- ui_orderhall_talent_ready_toast

local ZENITH_ID = 1249625
local ZENITH_STOMP_ID = 1272696

local function NewCombatStats()
    return {
        totalCasts = 0,
        breaks = 0,
        breakLog = {},
    }
end

function Core:OnEnable()
    -- UNIT_SPELLCAST_SUCCEEDED is a unit event, not a combat log event,
    -- so it survives the 12.0 CLEU restrictions in instances.
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("CHALLENGE_MODE_START")
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    self:RegisterEvent("CHALLENGE_MODE_RESET")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
end

function Core:OnDisable()
    self:UnregisterAllEvents()
    self.zenithReady = nil
    self.zenithStompReady = nil
end

-- Combo Strikes tracking via unit event (12.0-safe)

function Core:UNIT_SPELLCAST_SUCCEEDED(_, unit, _, spellId)
    if unit ~= "player" then return end
    if not COMBO_STRIKES_SPELLS[spellId] then return end

    self:RecordAbility(spellId)
end

function Core:RecordAbility(spellId)
    local state = ReWind.state
    local maxHistory = ReWind.db.profile.historyCount

    local broke = (spellId == state.lastSpellId)
    state.masteryBroken = broke

    if broke and ReWind.db.profile.soundEnabled then
        PlaySound(SOUND_BREAK, "Master")
    end

    state.lastSpellId = spellId

    table.insert(state.history, 1, {
        spellId = spellId,
        broke = broke,
        time = GetTime(),
    })

    while #state.history > maxHistory do
        table.remove(state.history)
    end

    if state.combat then
        state.combat.totalCasts = state.combat.totalCasts + 1
        if broke then
            state.combat.breaks = state.combat.breaks + 1
            table.insert(state.combat.breakLog, { spellId = spellId, time = GetTime() })
        end
    end

    if state.keystone then
        state.keystone.totalCasts = state.keystone.totalCasts + 1
        if broke then
            state.keystone.breaks = state.keystone.breaks + 1
            table.insert(state.keystone.breakLog, { spellId = spellId, time = GetTime() })
        end
    end

    ReWind:SendMessage("REWIND_HISTORY_UPDATED")
end

-- Zenith / Zenith Stomp cooldown tracking

function Core:SPELL_UPDATE_COOLDOWN()
    if not ReWind.db.profile.zenithAlert then return end

    self:CheckZenithReady(ZENITH_ID, "zenithReady", "Zenith")
    self:CheckZenithReady(ZENITH_STOMP_ID, "zenithStompReady", "Zenith Stomp")
end

function Core:CheckZenithReady(spellId, flag, label)
    if not C_SpellBook.IsSpellKnown(spellId) then return end

    local info = C_Spell.GetSpellCooldown(spellId)
    if not info then return end

    local ready = (info.duration == 0) or (info.startTime + info.duration - GetTime() <= 0)

    if ready and not self[flag] then
        self[flag] = true
        PlaySound(SOUND_ZENITH_READY, "Master")
        ReWind:SendMessage("REWIND_ZENITH_READY", label)
    elseif not ready then
        self[flag] = false
    end
end

-- Combat tracking

function Core:PLAYER_REGEN_DISABLED()
    ReWind.state.combat = NewCombatStats()
    self.zenithReady = nil
    self.zenithStompReady = nil
end

function Core:PLAYER_REGEN_ENABLED()
    local combat = ReWind.state.combat
    if combat and combat.totalCasts > 0 then
        self:PrintCombatReport(combat, "Combat")
    end
    ReWind.state.combat = nil

    if ReWind.db.profile.clearOnCombatEnd then
        wipe(ReWind.state.history)
        ReWind.state.lastSpellId = nil
        ReWind.state.masteryBroken = false
        ReWind:SendMessage("REWIND_HISTORY_UPDATED")
    end
end

-- M+ keystone tracking

function Core:CHALLENGE_MODE_START()
    ReWind.state.keystone = NewCombatStats()
    ReWind:Print("Keystone started — tracking Combo Strikes.")
end

function Core:CHALLENGE_MODE_COMPLETED()
    self:EndKeystone()
end

function Core:CHALLENGE_MODE_RESET()
    self:EndKeystone()
end

function Core:PLAYER_ENTERING_WORLD()
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive
        and C_ChallengeMode.IsChallengeModeActive()
        and not ReWind.state.keystone then
        ReWind.state.keystone = NewCombatStats()
    end
end

function Core:EndKeystone()
    local ks = ReWind.state.keystone
    if ks and ks.totalCasts > 0 then
        self:PrintCombatReport(ks, "Keystone")
    end
    ReWind.state.keystone = nil
end

-- Reporting

function Core:PrintCombatReport(stats, label)
    if not ReWind.db.profile.combatReport then return end

    local pct = stats.totalCasts > 0
        and (1 - stats.breaks / stats.totalCasts) * 100
        or 100

    local color = pct == 100 and "|cff00ff00" or (pct >= 95 and "|cffffff00" or "|cffff4444")
    ReWind:Print(string.format(
        "%s end — %s%.1f%%|r mastery uptime (%d/%d casts, %d break%s)",
        label, color, pct,
        stats.totalCasts - stats.breaks, stats.totalCasts,
        stats.breaks, stats.breaks == 1 and "" or "s"
    ))

    if #stats.breakLog > 0 then
        local counts = {}
        for _, entry in ipairs(stats.breakLog) do
            local info = C_Spell.GetSpellInfo(entry.spellId)
            local name = info and info.name or tostring(entry.spellId)
            counts[name] = (counts[name] or 0) + 1
        end

        local parts = {}
        for name, count in pairs(counts) do
            parts[#parts + 1] = string.format("%s x%d", name, count)
        end
        table.sort(parts)
        ReWind:Print("  Breaks: " .. table.concat(parts, ", "))
    end
end

function Core:InjectTestData()
    local testSpells = { 100780, 100784, 107428, 113656, 101546, 100780, 100780 }
    wipe(ReWind.state.history)
    ReWind.state.lastSpellId = nil
    ReWind.state.masteryBroken = false

    ReWind.state.combat = NewCombatStats()
    for _, id in ipairs(testSpells) do
        self:RecordAbility(id)
    end

    self:PrintCombatReport(ReWind.state.combat, "Test")
    ReWind.state.combat = nil
    ReWind:Print("Injected test data (last two are Tiger Palm repeats).")
end
