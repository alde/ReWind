local ReWind = LibStub("AceAddon-3.0"):NewAddon("ReWind", "AceConsole-3.0", "AceEvent-3.0")
_G.ReWind = ReWind

ReWind:SetDefaultModuleState(false)
ReWind.VERSION = "1"

local WW_SPEC_ID = 269

ReWind.ZENITH_ID = 1249625

ReWind.state = {
    history = {},
    lastSpellId = nil,
    masteryBroken = false,
    combat = nil,
    keystone = nil,
}

function ReWind:IsWindwalker()
    local spec = GetSpecialization()
    return spec and GetSpecializationInfo(spec) == WW_SPEC_ID
end

function ReWind:GetClassColor()
    local _, class = UnitClass("player")
    local color = RAID_CLASS_COLORS[class]
    if color then return color.r, color.g, color.b end
    return 0, 1, 0.59
end

function ReWind:GetGlowColor()
    local c = self.db.profile.zenithGlowColor
    if c then return c.r, c.g, c.b end
    return self:GetClassColor()
end

function ReWind:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("ReWindDB", self:GetDefaults(), true)
    self:RegisterChatCommand("rewind", "OnSlashCommand")
    self:RegisterChatCommand("rw", "OnSlashCommand")
end

function ReWind:OnEnable()
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

    local config = self:GetModule("Config", true)
    if config then config:Enable() end

    if self:IsWindwalker() then
        self:EnableModules()
    end
end

function ReWind:PLAYER_SPECIALIZATION_CHANGED(_, unit)
    if unit and unit ~= "player" then return end

    if self:IsWindwalker() then
        self:EnableModules()
    else
        self:DisableModules()
    end
end

function ReWind:EnableModules()
    for _, name in ipairs({ "Core", "Display", "Timeline" }) do
        local mod = self:GetModule(name, true)
        if mod and not mod:IsEnabled() then
            mod:Enable()
        end
    end
end

function ReWind:DisableModules()
    wipe(self.state.history)
    self.state.lastSpellId = nil
    self.state.masteryBroken = false

    for _, name in ipairs({ "Timeline", "Display", "Core" }) do
        local mod = self:GetModule(name, true)
        if mod and mod:IsEnabled() then
            mod:Disable()
        end
    end

    local display = self:GetModule("Display", true)
    if display and display.frame then
        display.frame:Hide()
    end
end

function ReWind:CreateMovableFrame(name, positionKey, defaults)
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(defaults.width or 48, defaults.height or 48)
    if defaults.backdrop then
        f:SetBackdrop(defaults.backdrop)
        if defaults.backdropColor then
            f:SetBackdropColor(unpack(defaults.backdropColor))
        end
        if defaults.borderColor then
            f:SetBackdropBorderColor(unpack(defaults.borderColor))
        end
    end
    f:SetFrameStrata(defaults.strata or "MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not ReWind.db.profile.locked then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        ReWind.db.profile[positionKey] = { point = point, relPoint = relPoint, x = x, y = y }
    end)

    local pos = ReWind.db.profile[positionKey]
    if pos then
        f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        f:SetPoint(defaults.defaultPoint or "CENTER", UIParent,
            defaults.defaultRelPoint or "CENTER",
            defaults.defaultX or 0, defaults.defaultY or 0)
    end

    return f
end

function ReWind:ToggleDisplay()
    self:GetModule("Display"):Toggle()
end

function ReWind:SetLocked(locked)
    self.db.profile.locked = locked
    local display = self:GetModule("Display", true)
    if display then display:ApplyLock() end
end

function ReWind:ToggleLock()
    self:SetLocked(not self.db.profile.locked)
    self:Print("Panel " .. (self.db.profile.locked and "locked" or "unlocked") .. ".")
end

function ReWind:OnSlashCommand(input)
    local cmd = self:GetArgs(input, 1)
    cmd = cmd and cmd:lower() or ""

    if cmd == "" then
        self:ToggleDisplay()
    elseif cmd == "config" or cmd == "options" then
        self:OpenConfig()
    elseif cmd == "timeline" or cmd == "tl" then
        self:ToggleTimeline()
    elseif cmd == "lock" then
        self:ToggleLock()
    elseif cmd == "reset" then
        wipe(self.state.history)
        self.state.lastSpellId = nil
        self.state.masteryBroken = false
        self:SendMessage("REWIND_HISTORY_UPDATED")
        self:Print("History cleared.")
    elseif cmd == "test" then
        self:GetModule("Core"):InjectTestData()
    else
        self:Print("ReWind v" .. self.VERSION)
        self:Print("  /rw            — Toggle display")
        self:Print("  /rw config     — Open options")
        self:Print("  /rw timeline   — Show last encounter timeline")
        self:Print("  /rw lock       — Lock/unlock frame")
        self:Print("  /rw reset      — Clear history")
        self:Print("  /rw test       — Inject test data")
    end
end

function ReWind:ToggleTimeline()
    self:GetModule("Timeline"):Toggle()
end

-- Stubs — implemented by modules
function ReWind:OpenConfig() end
