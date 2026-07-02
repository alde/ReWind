local ReWind = _G.ReWind
local Auras = ReWind:NewModule("Auras", "AceEvent-3.0")

local TRACKED_AURAS = {
    [ReWind.ZENITH_ID] = {
        name = "Zenith",
        baseDuration = 6,
        stacks = false,
    },
    [116768] = {
        name = "Blackout Kick!",
        baseDuration = 15,
        stacks = true,
    },
    [220358] = {
        name = "Dance of Chi-Ji",
        baseDuration = 15,
        stacks = true,
    },
    [248646] = {
        name = "Tigereye Brew",
        baseDuration = 0,
        stacks = true,
    },
}

ReWind.TRACKED_AURAS = TRACKED_AURAS

local nameToId = {}
for id, info in pairs(TRACKED_AURAS) do
    nameToId[info.name] = id
end

local auraIdCache = {}

local function ResolveSpellId(auraSpellId)
    if auraIdCache[auraSpellId] ~= nil then
        return auraIdCache[auraSpellId]
    end

    if TRACKED_AURAS[auraSpellId] then
        auraIdCache[auraSpellId] = auraSpellId
        return auraSpellId
    end

    local name = C_Spell.GetSpellName(auraSpellId)
    if name and nameToId[name] then
        auraIdCache[auraSpellId] = nameToId[name]
        return nameToId[name]
    end

    auraIdCache[auraSpellId] = false
    return false
end

local scanErrorLogged = false

function Auras:ScanPlayer()
    local found = {}

    local ids = C_UnitAuras.GetUnitAuraInstanceIDs("player", "HELPFUL")
    if not ids then return found end

    for _, instanceId in ipairs(ids) do
        local ok, err = pcall(function()
            local aura = C_UnitAuras.GetAuraDataByAuraInstanceID("player", instanceId)
            if not aura or not aura.spellId or issecretvalue(aura.spellId) then return end

            local trackedId = ResolveSpellId(aura.spellId)
            if not trackedId then return end

            local info = TRACKED_AURAS[trackedId]

            local duration, expirationTime, stacks
            local durOk, d, e = pcall(function()
                return tonumber(aura.duration) or 0, tonumber(aura.expirationTime) or 0
            end)
            if durOk and d and d > 0 then
                duration = d
                expirationTime = e
            else
                duration = info.baseDuration
                expirationTime = duration > 0 and (GetTime() + duration) or 0
            end

            local stackOk, s = pcall(function()
                return aura.applications or 0
            end)
            stacks = stackOk and s or 0

            found[trackedId] = {
                name = info.name,
                duration = duration,
                expirationTime = expirationTime,
                stacks = stacks,
            }
        end)

        if not ok and not scanErrorLogged then
            ReWind:Print("Aura scan error (subsequent errors suppressed): " .. tostring(err))
            scanErrorLogged = true
        end
    end

    return found
end

function Auras:OnEnable()
    self:RegisterEvent("UNIT_AURA")
    ReWind.state.auras = self:ScanPlayer()
end

function Auras:OnDisable()
    self:UnregisterEvent("UNIT_AURA")
    wipe(ReWind.state.auras)
end

function Auras:UNIT_AURA(_, unit)
    if unit ~= "player" then return end

    local previous = ReWind.state.auras or {}
    local current = self:ScanPlayer()

    for spellId, aura in pairs(current) do
        if not previous[spellId] then
            ReWind:SendMessage("REWIND_AURA_GAINED", spellId, aura)
        elseif aura.stacks ~= previous[spellId].stacks then
            ReWind:SendMessage("REWIND_AURA_STACKS", spellId, aura)
        end
    end

    for spellId in pairs(previous) do
        if not current[spellId] then
            ReWind:SendMessage("REWIND_AURA_LOST", spellId)
        end
    end

    ReWind.state.auras = current
    ReWind:SendMessage("REWIND_AURAS_UPDATED")
end

function Auras:GetAura(spellId)
    local auras = ReWind.state.auras
    return auras and auras[spellId]
end

function Auras:IsActive(spellId)
    return self:GetAura(spellId) ~= nil
end
