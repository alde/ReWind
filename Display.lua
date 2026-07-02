local ReWind = _G.ReWind
local Display = ReWind:NewModule("Display", "AceEvent-3.0")

local PADDING = 4
local BORDER_SIZE = 2

local ZENITH_FLASH_DURATION = 3.0
local ASSISTED_COMBAT_POLL = 0.1
local SEPARATOR_WIDTH = 6

local function CreateUnlockOverlay(frame, labelText)
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(frame:GetFrameLevel() + 20)

    local bg = overlay:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.5)

    local label = overlay:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    label:SetPoint("CENTER")
    label:SetText(labelText)
    label:SetTextColor(1, 1, 1)

    overlay:Hide()
    frame.unlockOverlay = overlay
    return overlay
end

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
    CreateUnlockOverlay(f, "Ability Panel")
    ReWind:ApplyAppearance()
    self:ApplyLock()
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

local function IsVertical(dir)
    return dir == "up" or dir == "down"
end

function Display:LayoutFrame()
    local f = self:GetFrame()
    local db = ReWind.db.profile
    local iconSize = db.iconSize
    local visible = math.min(#ReWind.state.history, db.historyCount)
    if visible == 0 then visible = 1 end

    local span = (iconSize * visible) + (PADDING * (visible - 1)) + (BORDER_SIZE * 2) + 8

    if IsVertical(db.growDirection) then
        local w = iconSize + (BORDER_SIZE * 2) + 8
        f:SetSize(w, span)
    else
        local h = iconSize + (BORDER_SIZE * 2) + 8
        f:SetSize(span, h)
    end
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

local GROW_CONFIG = {
    right = { anchor = "BOTTOMLEFT", xMul = 1,  yMul = 0 },
    left  = { anchor = "BOTTOMRIGHT", xMul = -1, yMul = 0 },
    up    = { anchor = "BOTTOMLEFT", xMul = 0,  yMul = 1 },
    down  = { anchor = "TOPLEFT",    xMul = 0,  yMul = -1 },
}

function Display:Refresh()
    local f = self:GetFrame()
    if not f:IsShown() then return end

    local db = ReWind.db.profile
    local history = ReWind.state.history
    local count = db.historyCount
    local baseSize = db.iconSize
    local grow = GROW_CONFIG[db.growDirection] or GROW_CONFIG.right

    self:LayoutFrame()

    local offset = BORDER_SIZE + 4
    for i = 1, count do
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
            container:SetPoint(grow.anchor, f, grow.anchor,
                offset * grow.xMul + (grow.xMul == 0 and (BORDER_SIZE + 4) or 0),
                offset * grow.yMul + (grow.yMul == 0 and (4 + BORDER_SIZE) or 0))
            container:SetAlpha(alpha)

            local spellInfo = C_Spell.GetSpellInfo(entry.spellId)
            local texture = spellInfo and spellInfo.iconID
            container.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")

            if entry.broke then
                container.border:SetColorTexture(0.9, 0.1, 0.1, 1.0)
                container.glow:SetVertexColor(1, 0, 0)
                container.glow:SetAlpha(0.6)
            else
                container.border:SetColorTexture(0.3, 0.3, 0.3, 0.8)
                container.glow:SetAlpha(0)
            end

            container:Show()
            offset = offset + iconPixels + PADDING
        else
            container:Hide()
        end
    end

    for i = count + 1, #f.icons do
        f.icons[i]:Hide()
    end

    self:RefreshAssisted()
end

local function IsCombatVisible(combatOnlySetting)
    return not combatOnlySetting or UnitAffectingCombat("player")
end

function Display:ApplyLock()
    local locked = ReWind.db.profile.locked
    local frames = { self.frame, self.zenithIcon, self.assistedFrame }
    for _, f in ipairs(frames) do
        if f then
            f:EnableMouse(not locked)
            if f.unlockOverlay then
                if locked then
                    f.unlockOverlay:Hide()
                else
                    f.unlockOverlay:Show()
                end
            end
        end
    end
end

function Display:UpdatePanelVisibility()
    local f = self:GetFrame()
    local db = ReWind.db.profile
    if db.shown then
        f:Show()
        f:SetAlpha(IsCombatVisible(db.panelCombatOnly) and 1 or 0)
    else
        f:SetAlpha(0)
    end
end

function Display:Toggle()
    local db = ReWind.db.profile
    db.shown = not db.shown
    self:UpdatePanelVisibility()
    if db.shown then self:Refresh() end
end

function Display:PLAYER_ENTERING_WORLD()
    self:UpdatePanelVisibility()
    if ReWind.db.profile.shown then self:Refresh() end
end

function Display:PLAYER_REGEN_DISABLED()
    self:UpdatePanelVisibility()
    local db = ReWind.db.profile
    if db.zenithCombatOnly and self.zenithIcon and self.zenithIcon:IsShown() then
        self:SetZenithIconAlpha(db.zenithIconAlpha)
    end
end

function Display:PLAYER_REGEN_ENABLED()
    self:UpdatePanelVisibility()
    if ReWind.db.profile.zenithCombatOnly then
        self:SetZenithIconAlpha(0)
    end
end

-- Assisted Combat — standalone movable frame

function Display:GetAssistedFrame()
    if self.assistedFrame then return self.assistedFrame end

    local db = ReWind.db.profile
    local size = db.iconSize

    local af = CreateFrame("Frame", "ReWindAssistedIcon", UIParent, "BackdropTemplate")
    af:SetSize(size, size)
    af:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    af:SetBackdropColor(0.05, 0.05, 0.1, 0.8)
    af:SetBackdropBorderColor(0.1, 0.5, 0.8, 0.8)
    af:SetFrameStrata("MEDIUM")
    af:SetClampedToScreen(true)
    af:SetMovable(true)
    af:EnableMouse(true)
    af:RegisterForDrag("LeftButton")
    af:SetScript("OnDragStart", function(self)
        if not ReWind.db.profile.locked then self:StartMoving() end
    end)
    af:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        ReWind.db.profile.assistedPosition = { point = point, relPoint = relPoint, x = x, y = y }
    end)

    local icon = af:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    af.icon = icon

    af.elapsed = 0
    af:SetScript("OnUpdate", function(self, dt)
        self.elapsed = self.elapsed + dt
        if self.elapsed < ASSISTED_COMBAT_POLL then return end
        self.elapsed = 0
        Display:UpdateAssisted()
    end)

    local pos = db.assistedPosition
    if pos then
        af:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        af:SetPoint("CENTER", UIParent, "CENTER", 60, -200)
    end

    CreateUnlockOverlay(af, "Next Spell")
    af:Hide()
    self.assistedFrame = af
    self:ApplyLock()
    return af
end

function Display:RefreshAssisted()
    if not self:ShouldShowAssisted() then
        if self.assistedFrame then self.assistedFrame:Hide() end
        return
    end

    local af = self:GetAssistedFrame()
    local db = ReWind.db.profile
    af:SetSize(db.iconSize, db.iconSize)
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

local function GetGlowColor()
    return ReWind:GetGlowColor()
end

local FLIPBOOK_STYLES = {
    proc = {
        atlas = "UI-HUD-ActionBar-Proc-Loop-Flipbook",
        rows = 6, columns = 5, frames = 30, duration = 1.0,
        texPadding = 1.4,
    },
    ants = {
        texture = "Interface\\SpellActivationOverlay\\IconAlertAnts",
        rows = 5, columns = 5, frames = 22, duration = 0.3,
        frameW = 48, frameH = 48, texPadding = 1.25,
    },
}

local function StartFlipBookGlow(frame, size, entry, r, g, b)
    local texSize = size * (entry.texPadding or 1)

    if not frame._flipData then
        local tex = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        tex:SetPoint("CENTER")
        local ag = tex:CreateAnimationGroup()
        ag:SetLooping("REPEAT")
        local anim = ag:CreateAnimation("FlipBook")
        frame._flipData = { tex = tex, ag = ag, anim = anim }
    end

    local d = frame._flipData
    d.tex:SetSize(texSize, texSize)
    if entry.atlas then
        d.tex:SetAtlas(entry.atlas)
    elseif entry.texture then
        d.tex:SetTexture(entry.texture)
    end
    d.tex:SetDesaturated(true)
    d.tex:SetVertexColor(r, g, b)
    d.tex:Show()
    d.anim:SetFlipBookRows(entry.rows or 6)
    d.anim:SetFlipBookColumns(entry.columns or 5)
    d.anim:SetFlipBookFrames(entry.frames or 30)
    d.anim:SetDuration(entry.duration or 1.0)
    d.anim:SetFlipBookFrameWidth(entry.frameW or 0)
    d.anim:SetFlipBookFrameHeight(entry.frameH or 0)
    if d.ag:IsPlaying() then d.ag:Stop() end
    d.ag:Play()
end

local function StopFlipBookGlow(frame)
    if not frame._flipData then return end
    frame._flipData.tex:Hide()
    frame._flipData.ag:Stop()
end

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

    CreateUnlockOverlay(f, "Zenith")
    f:Hide()
    self.zenithIcon = f
    self:ApplyLock()
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

    local visible = f:IsShown() and f:GetAlpha() > 0

    if style == "glow" then
        f.glowFrame:SetSize(size * 1.7, size * 1.7)
        f.glowTex:SetVertexColor(r, g, b)
        f.ag:GetAnimations():SetFromAlpha(intensity * 0.3)
        f.ag:GetAnimations():SetToAlpha(intensity)
        f.glowFrame:Show()
        if visible then f.ag:Play() end
    elseif FLIPBOOK_STYLES[style] then
        if visible then
            StartFlipBookGlow(f, size, FLIPBOOK_STYLES[style], r, g, b)
        end
    end
end

function Display:StopZenithGlow()
    if not self.zenithIcon then return end
    self.zenithIcon.ag:Stop()
    self.zenithIcon.glowFrame:Hide()
    StopFlipBookGlow(self.zenithIcon)
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
    local spellInfo = C_Spell.GetSpellInfo(ReWind.ZENITH_ID)
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

