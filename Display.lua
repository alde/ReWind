local ReWind = _G.ReWind
local Display = ReWind:NewModule("Display", "AceEvent-3.0")

local PADDING = 4
local BORDER_SIZE = 2

local ZENITH_FLASH_DURATION = 3.0
local ASSISTED_COMBAT_POLL = 0.1
local SEPARATOR_WIDTH = 6

function Display:OnEnable()
    self:RegisterMessage("REWIND_HISTORY_UPDATED", "Refresh")
    self:RegisterMessage("REWIND_ZENITH_READY", "OnZenithReady")
    self:RegisterMessage("REWIND_ZENITH_COOLDOWN", "OnZenithCooldown")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function Display:OnDisable()
    self:UnregisterAllMessages()
    self:UnregisterAllEvents()
    if self.zenithFrame then self.zenithFrame:Hide() end
    if self.assistedFrame then self.assistedFrame:Hide() end
    self:HideZenithIcon()
end

function Display:GetFrame()
    if self.frame then return self.frame end

    local f = CreateFrame("Frame", "ReWindPanel", UIParent, "BackdropTemplate")
    f:SetFrameStrata("MEDIUM")
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
        ReWind.db.profile.position = { point = point, relPoint = relPoint, x = x, y = y }
    end)

    f.icons = {}
    self.frame = f
    ReWind:ApplyAppearance()
    self:RestorePosition()
    self:LayoutFrame()

    return f
end

function Display:RestorePosition()
    local pos = ReWind.db.profile.position
    if pos then
        self.frame:ClearAllPoints()
        self.frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    end
end

function Display:ShouldShowAssisted()
    return ReWind.db.profile.assistedCombat
        and C_AssistedCombat ~= nil
        and C_AssistedCombat.GetNextCastSpell ~= nil
end

function Display:LayoutFrame()
    local f = self:GetFrame()
    local db = ReWind.db.profile
    local iconSize = db.iconSize
    local visible = math.min(#ReWind.state.history, db.historyCount)
    if visible == 0 then visible = 1 end
    local totalWidth = (iconSize * visible) + (PADDING * (visible - 1)) + (BORDER_SIZE * 2) + 8

    if self:ShouldShowAssisted() then
        totalWidth = totalWidth + SEPARATOR_WIDTH + iconSize + PADDING
    end

    local totalHeight = iconSize + (BORDER_SIZE * 2) + 8
    f:SetSize(totalWidth, totalHeight)
end

function Display:GetIcon(index)
    local f = self.frame
    if f.icons[index] then return f.icons[index] end

    local container = CreateFrame("Frame", nil, f)

    local border = container:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    container.border = border

    local icon = container:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
    icon:SetPoint("BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    container.icon = icon

    local glow = container:CreateTexture(nil, "OVERLAY")
    glow:SetPoint("CENTER")
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0)
    container.glow = glow

    f.icons[index] = container
    return container
end

function Display:Refresh()
    local f = self:GetFrame()
    if not f:IsShown() then return end

    local db = ReWind.db.profile
    local history = ReWind.state.history
    local count = db.historyCount
    local baseSize = db.iconSize

    self:LayoutFrame()

    -- Most recent is on the right
    local xOffset = BORDER_SIZE + 4
    for i = count, 1, -1 do
        local container = self:GetIcon(i)
        local entry = history[i]

        if entry then
            local age = i - 1
            local scale = math.max(0.6, 1.0 - (age * 0.06))
            local alpha = db.iconAlpha * math.max(db.minOpacity, 1.0 - (age * db.opacityStep))
            local iconPixels = math.floor(baseSize * scale)

            container:SetSize(iconPixels, iconPixels)
            container.glow:SetSize(iconPixels * 1.7, iconPixels * 1.7)
            container:ClearAllPoints()
            container:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", xOffset, 4 + BORDER_SIZE)
            container:SetAlpha(alpha)

            local spellInfo = C_Spell.GetSpellInfo(entry.spellId)
            local texture = spellInfo and spellInfo.iconID
            if texture then
                container.icon:SetTexture(texture)
            else
                container.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end

            if entry.broke then
                container.border:SetColorTexture(0.9, 0.1, 0.1, 1.0)
                container.glow:SetVertexColor(1, 0, 0)
                container.glow:SetAlpha(0.6)
            else
                container.border:SetColorTexture(0.3, 0.3, 0.3, 0.8)
                container.glow:SetAlpha(0)
            end

            container:Show()
            xOffset = xOffset + iconPixels + PADDING
        else
            container:Hide()
        end
    end

    -- Hide extras if history count was reduced
    for i = count + 1, #f.icons do
        f.icons[i]:Hide()
    end

    self:RefreshAssisted()
end

function Display:Toggle()
    local f = self:GetFrame()
    local db = ReWind.db.profile
    if db.shown then
        db.shown = false
        f:SetAlpha(0)
    else
        db.shown = true
        if db.panelCombatOnly and not UnitAffectingCombat("player") then
            f:Show()
            f:SetAlpha(0)
        else
            f:Show()
            f:SetAlpha(1)
        end
        self:Refresh()
    end
end

function Display:PLAYER_ENTERING_WORLD()
    local db = ReWind.db.profile
    if db.shown then
        local f = self:GetFrame()
        f:Show()
        if db.panelCombatOnly then
            f:SetAlpha(0)
        else
            f:SetAlpha(1)
        end
        self:Refresh()
    end
end

function Display:PLAYER_REGEN_DISABLED()
    local db = ReWind.db.profile
    if db.shown and db.panelCombatOnly then
        self:GetFrame():SetAlpha(1)
    end
    if db.zenithCombatOnly and self.zenithIcon and self.zenithIcon:IsShown() then
        self:SetZenithIconAlpha(db.zenithIconAlpha)
    end
end

function Display:PLAYER_REGEN_ENABLED()
    local db = ReWind.db.profile
    if db.panelCombatOnly then
        self:GetFrame():SetAlpha(0)
    end
    if db.zenithCombatOnly then
        self:SetZenithIconAlpha(0)
    end
end

-- Assisted Combat (12.0+ Blizzard next-spell suggestion)

function Display:GetAssistedFrame()
    if self.assistedFrame then return self.assistedFrame end

    local f = self:GetFrame()
    local db = ReWind.db.profile
    local size = db.iconSize

    local af = CreateFrame("Frame", nil, f)
    af:SetSize(size, size)

    local border = af:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.1, 0.5, 0.8, 0.8)
    af.border = border

    local icon = af:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
    icon:SetPoint("BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    af.icon = icon

    local label = af:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    label:SetPoint("BOTTOM", af, "TOP", 0, 1)
    label:SetText("NEXT")
    label:SetTextColor(0.4, 0.7, 1.0)
    af.label = label

    -- Throttled OnUpdate to poll C_AssistedCombat
    af.elapsed = 0
    af:SetScript("OnUpdate", function(self, dt)
        self.elapsed = self.elapsed + dt
        if self.elapsed < ASSISTED_COMBAT_POLL then return end
        self.elapsed = 0
        Display:UpdateAssisted()
    end)

    af:Hide()
    self.assistedFrame = af
    return af
end

function Display:RefreshAssisted()
    if not self:ShouldShowAssisted() then
        if self.assistedFrame then self.assistedFrame:Hide() end
        return
    end

    local af = self:GetAssistedFrame()
    local f = self:GetFrame()
    local db = ReWind.db.profile
    local size = db.iconSize

    af:SetSize(size, size)
    af:ClearAllPoints()
    af:SetPoint("RIGHT", f, "RIGHT", -(BORDER_SIZE + 4), 0)
    af:Show()
    self:UpdateAssisted()
end

function Display:UpdateAssisted()
    local af = self.assistedFrame
    if not af or not af:IsShown() then return end
    if not C_AssistedCombat then return end

    local spellId = C_AssistedCombat.GetNextCastSpell()
    if not spellId then
        af.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        af.icon:SetDesaturated(true)
        return
    end

    local spellInfo = C_Spell.GetSpellInfo(spellId)
    local texture = spellInfo and spellInfo.iconID
    af.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    af.icon:SetDesaturated(false)
end

-- Zenith ready flash

function Display:GetZenithFrame()
    if self.zenithFrame then return self.zenithFrame end

    local f = self:GetFrame()
    local zf = CreateFrame("Frame", nil, f)
    zf:SetAllPoints(f)
    zf:SetFrameLevel(f:GetFrameLevel() + 10)

    local flash = zf:CreateTexture(nil, "OVERLAY")
    flash:SetAllPoints()
    flash:SetColorTexture(0.0, 0.8, 0.4, 0.4)
    flash:SetBlendMode("ADD")
    zf.flash = flash

    local label = zf:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    label:SetPoint("CENTER")
    label:SetTextColor(0.2, 1.0, 0.4)
    zf.label = label

    zf.ag = zf:CreateAnimationGroup()
    local fadeOut = zf.ag:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(ZENITH_FLASH_DURATION)
    fadeOut:SetSmoothing("OUT")
    zf.ag:SetScript("OnFinished", function() zf:Hide() end)

    zf:Hide()
    self.zenithFrame = zf
    return zf
end

function Display:OnZenithReady(_, label)
    local zf = self:GetZenithFrame()
    zf.label:SetText(label .. " READY")
    zf:SetAlpha(1)
    zf:Show()
    zf.ag:Stop()
    zf.ag:Play()

    self:ShowZenithIcon(label)
end

function Display:OnZenithCooldown()
    self:HideZenithIcon()
end

-- Standalone movable Zenith ready icon

local ZENITH_ID = 1249625
local ZENITH_STOMP_ID = 1272696

function Display:GetZenithIcon()
    if self.zenithIcon then return self.zenithIcon end

    local db = ReWind.db.profile
    local size = db.zenithIconSize

    local f = CreateFrame("Frame", "ReWindZenithIcon", UIParent, "BackdropTemplate")
    f:SetSize(size, size)
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    local gr, gg, gb = GetGlowColor()
    f:SetBackdropBorderColor(gr, gg, gb, 0.9)
    f:SetFrameStrata("MEDIUM")
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
        ReWind.db.profile.zenithIconPosition = { point = point, relPoint = relPoint, x = x, y = y }
    end)

    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.icon = icon

    local glow = CreateFrame("Frame", nil, f)
    glow:SetPoint("CENTER")
    glow:SetFrameLevel(f:GetFrameLevel() + 1)
    local glowTex = glow:CreateTexture(nil, "OVERLAY")
    glowTex:SetAllPoints()
    glowTex:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glowTex:SetBlendMode("ADD")
    f.glowFrame = glow
    f.glowTex = glowTex

    local ag = glow:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local pulse = ag:CreateAnimation("Alpha")
    pulse:SetFromAlpha(0.3)
    pulse:SetToAlpha(0.9)
    pulse:SetDuration(0.8)
    pulse:SetSmoothing("IN_OUT")
    f.ag = ag

    local pos = db.zenithIconPosition
    if pos then
        f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
    end

    f:Hide()
    self.zenithIcon = f
    return f
end

function Display:UpdateZenithIconAppearance()
    if not self.zenithIcon then return end
    local db = ReWind.db.profile
    local size = db.zenithIconSize
    self.zenithIcon:SetSize(size, size)
    self.zenithIcon:SetAlpha(db.zenithIconAlpha)
    self:ApplyZenithGlow()
end

local function GetGlowColor()
    local c = ReWind.db.profile.zenithGlowColor
    if c then return c.r, c.g, c.b end
    local _, class = UnitClass("player")
    local color = RAID_CLASS_COLORS[class]
    if color then return color.r, color.g, color.b end
    return 0, 1, 0.59
end

function Display:ApplyZenithGlow()
    if not self.zenithIcon then return end
    local f = self.zenithIcon
    local db = ReWind.db.profile
    local style = db.zenithGlowStyle
    local r, g, b = GetGlowColor()
    local intensity = db.zenithGlowIntensity
    local size = db.zenithIconSize

    f:SetBackdropBorderColor(r, g, b, 0.9)
    self:StopZenithGlow()

    if style == "glow" then
        f.glowFrame:SetSize(size * 1.7, size * 1.7)
        f.glowTex:SetVertexColor(r, g, b)
        f.ag:GetAnimations():SetFromAlpha(intensity * 0.3)
        f.ag:GetAnimations():SetToAlpha(intensity)
        f.glowFrame:Show()
        if f:IsShown() and f:GetAlpha() > 0 then
            f.ag:Play()
        end
    else
        f.glowFrame:Hide()
    end
end

function Display:StopZenithGlow()
    if not self.zenithIcon then return end
    self.zenithIcon.ag:Stop()
    self.zenithIcon.glowFrame:Hide()
end

function Display:SetZenithIconAlpha(alpha)
    if not self.zenithIcon then return end
    self.zenithIcon:SetAlpha(alpha)
end

function Display:ShowZenithIcon(label)
    if not ReWind.db.profile.zenithIconEnabled then return end

    local f = self:GetZenithIcon()
    local db = ReWind.db.profile
    f:SetSize(db.zenithIconSize, db.zenithIconSize)
    if db.zenithCombatOnly and not UnitAffectingCombat("player") then
        f:SetAlpha(0)
    else
        f:SetAlpha(db.zenithIconAlpha)
    end
    local spellId = (label == "Zenith") and ZENITH_ID or ZENITH_STOMP_ID
    local spellInfo = C_Spell.GetSpellInfo(spellId)
    local texture = spellInfo and spellInfo.iconID
    f.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    f:Show()
    self:ApplyZenithGlow()
end

function Display:HideZenithIcon()
    if not self.zenithIcon then return end
    self:StopZenithGlow()
    self.zenithIcon:SetAlpha(0)
end

-- Wire stubs
function ReWind:ToggleDisplay()
    self:GetModule("Display"):Toggle()
end

function ReWind:SetLocked(locked)
    self.db.profile.locked = locked
end

function ReWind:ToggleLock()
    self:SetLocked(not self.db.profile.locked)
    self:Print("Panel " .. (self.db.profile.locked and "locked" or "unlocked") .. ".")
end
