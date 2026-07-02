local ReWind = _G.ReWind
local Core = ReWind:NewModule("Core", "AceEvent-3.0")

local TIGER_PALM_ID = 100780

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

local function NewCombatStats()
    return {
        totalCasts = 0,
        breaks = 0,
        breakLog = {},
        casts = {},
        startTime = GetTime(),
    }
end

local function RecordToStats(stats, spellId, now, broke)
    stats.totalCasts = stats.totalCasts + 1
    table.insert(stats.casts, { spellId = spellId, time = now, broke = broke })
    if broke then
        stats.breaks = stats.breaks + 1
        table.insert(stats.breakLog, { spellId = spellId, time = now })
    end
end

function Core:OnEnable()
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
    self.zenithActiveUntil = nil
end

-- Combo Strikes tracking

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
        ReWind:PlayConfigSound("breakSound")
    end

    if spellId == TIGER_PALM_ID and ReWind.db.profile.zenithWasteAlert then
        local auras = ReWind:GetModule("Auras", true)
        local zenithActive = (auras and auras:IsActive(ReWind.ZENITH_ID))
            or (self.zenithActiveUntil and GetTime() < self.zenithActiveUntil)
        ReWind:Debug("Tiger Palm cast, Zenith active:", tostring(zenithActive))
        if zenithActive then
            ReWind:PlayConfigSound("zenithWasteSound")
            ReWind:SendMessage("REWIND_ZENITH_WASTE", spellId)
        end
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

    local now = GetTime()
    if state.combat then RecordToStats(state.combat, spellId, now, broke) end
    if state.keystone then RecordToStats(state.keystone, spellId, now, broke) end

    ReWind:SendMessage("REWIND_HISTORY_UPDATED")
end

-- Zenith / Zenith Stomp tracking

function Core:SPELL_UPDATE_COOLDOWN()
    self:CheckZenithReady()
end

function Core:CheckZenithReady()
    if not IsPlayerSpell(ReWind.ZENITH_ID) then return end

    local info = C_Spell.GetSpellCooldown(ReWind.ZENITH_ID)
    if not info then return end

    local ready = not info.isActive

    if ready and not self.zenithReady then
        self.zenithReady = true
        if ReWind.db.profile.zenithAlert then
            ReWind:PlayConfigSound("zenithSound")
        end
        ReWind:SendMessage("REWIND_ZENITH_READY", "Zenith")
    elseif not ready and self.zenithReady then
        self.zenithReady = false
        self.zenithActiveUntil = GetTime() + 15
        ReWind:Debug("Zenith pressed, window until", string.format("%.1f", self.zenithActiveUntil))
        ReWind:SendMessage("REWIND_ZENITH_COOLDOWN", "Zenith")
    elseif not ready then
        self.zenithReady = false
    end
end

-- Combat tracking

function Core:PLAYER_REGEN_DISABLED()
    ReWind.state.combat = NewCombatStats()
end

function Core:PLAYER_REGEN_ENABLED()
    local combat = ReWind.state.combat
    if combat and combat.totalCasts > 0 then
        combat.endTime = GetTime()
        self:PrintCombatReport(combat, "Combat")
        ReWind.state.lastEncounter = combat
        ReWind:SendMessage("REWIND_ENCOUNTER_END", combat)
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
        ks.endTime = GetTime()
        self:PrintCombatReport(ks, "Keystone")
        ReWind.state.lastEncounter = ks
        ReWind:SendMessage("REWIND_ENCOUNTER_END", ks)
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

    local combat = ReWind.state.combat
    combat.endTime = GetTime()
    self:PrintCombatReport(combat, "Test")
    ReWind.state.lastEncounter = combat
    ReWind.state.combat = nil

    local timeline = ReWind:GetModule("Timeline", true)
    if timeline then timeline:Show(combat) end

    ReWind:Print("Injected test data (last two are Tiger Palm repeats).")
end
