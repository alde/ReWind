local ReWind = _G.ReWind
local Config = ReWind:NewModule("Config")
local LSM = LibStub("LibSharedMedia-3.0")

function ReWind:GetDefaults()
    return {
        profile = {
            shown = true,
            locked = false,
            historyCount = 6,
            iconSize = 40,
            iconAlpha = 1.0,
            opacityStep = 0.12,
            minOpacity = 0.3,
            soundEnabled = true,
            breakSound = "Default",
            zenithSound = "Default",
            combatReport = true,
            zenithAlert = true,
            assistedCombat = false,
            timelineAutoShow = false,
            clearOnCombatEnd = false,
            panelCombatOnly = false,
            zenithCombatOnly = false,
            zenithIconEnabled = true,
            zenithIconSize = 48,
            zenithIconAlpha = 1.0,
            zenithIconPosition = nil,
            bgAlpha = 0.8,
            borderTexture = "Blizzard Tooltip",
            timelinePosition = nil,
            timelineWidth = nil,
            position = nil,
        },
    }
end

function ReWind:PlayConfigSound(settingKey, defaultSoundKit)
    local name = self.db.profile[settingKey]
    if name == "Default" then
        PlaySound(defaultSoundKit, "Master")
    elseif name == "None" then
        return
    else
        local path = LSM:Fetch("sound", name)
        if path then PlaySoundFile(path, "Master") end
    end
end

local function GetSoundValues()
    local values = { Default = "Default" }
    for k, v in pairs(LSM:HashTable("sound")) do
        values[k] = k
    end
    return values
end

function ReWind:GetBorderTexture()
    local name = self.db.profile.borderTexture
    if name == "None" then return nil end
    return LSM:Fetch("border", name)
end

function ReWind:ApplyAppearance()
    local borderPath = self:GetBorderTexture()
    local backdrop = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = true, tileSize = 16,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    }
    if borderPath then
        backdrop.edgeFile = borderPath
        backdrop.edgeSize = 12
    end

    local opacity = self.db.profile.bgAlpha

    local display = self:GetModule("Display", true)
    if display and display.frame then
        display.frame:SetBackdrop(backdrop)
        display.frame:SetBackdropColor(0.05, 0.05, 0.05, opacity)
        display.frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    end
end

local function GetOptions()
    return {
        type = "group",
        name = "ReWind",
        args = {
            abilityPanel = {
                type = "group",
                name = "Ability Panel",
                order = 1,
                inline = true,
                args = {
                    shown = {
                        type = "toggle",
                        name = "Show Panel",
                        desc = "Show the ability history strip.",
                        order = 1,
                        get = function() return ReWind.db.profile.shown end,
                        set = function(_, val)
                            ReWind.db.profile.shown = val
                            local display = ReWind:GetModule("Display")
                            local f = display:GetFrame()
                            if val then
                                f:Show()
                                if ReWind.db.profile.panelCombatOnly and not UnitAffectingCombat("player") then
                                    f:SetAlpha(0)
                                else
                                    f:SetAlpha(1)
                                end
                                display:Refresh()
                            else
                                f:SetAlpha(0)
                            end
                        end,
                    },
                    panelCombatOnly = {
                        type = "toggle",
                        name = "Only in Combat",
                        desc = "Only show the ability panel while in combat.",
                        order = 2,
                        get = function() return ReWind.db.profile.panelCombatOnly end,
                        set = function(_, val)
                            ReWind.db.profile.panelCombatOnly = val
                            local display = ReWind:GetModule("Display")
                            local f = display:GetFrame()
                            if val and not UnitAffectingCombat("player") then
                                f:SetAlpha(0)
                            elseif not val and ReWind.db.profile.shown then
                                f:SetAlpha(1)
                            end
                        end,
                    },
                    historyCount = {
                        type = "range",
                        name = "History Length",
                        desc = "How many recent abilities to display.",
                        order = 3,
                        min = 2, max = 12, step = 1,
                        get = function() return ReWind.db.profile.historyCount end,
                        set = function(_, val)
                            ReWind.db.profile.historyCount = val
                            ReWind:SendMessage("REWIND_HISTORY_UPDATED")
                        end,
                    },
                    iconSize = {
                        type = "range",
                        name = "Icon Size",
                        desc = "Base size of the most recent ability icon (px).",
                        order = 4,
                        min = 20, max = 64, step = 2,
                        get = function() return ReWind.db.profile.iconSize end,
                        set = function(_, val)
                            ReWind.db.profile.iconSize = val
                            ReWind:SendMessage("REWIND_HISTORY_UPDATED")
                        end,
                    },
                    iconAlpha = {
                        type = "range",
                        name = "Icon Opacity",
                        desc = "Base opacity of the most recent ability icon.",
                        order = 5,
                        min = 0.2, max = 1.0, step = 0.05,
                        isPercent = true,
                        get = function() return ReWind.db.profile.iconAlpha end,
                        set = function(_, val)
                            ReWind.db.profile.iconAlpha = val
                            ReWind:SendMessage("REWIND_HISTORY_UPDATED")
                        end,
                    },
                    opacityStep = {
                        type = "range",
                        name = "Opacity Fade",
                        desc = "How much each older icon fades (0 = no fade).",
                        order = 6,
                        min = 0, max = 0.3, step = 0.02,
                        isPercent = true,
                        get = function() return ReWind.db.profile.opacityStep end,
                        set = function(_, val)
                            ReWind.db.profile.opacityStep = val
                            ReWind:SendMessage("REWIND_HISTORY_UPDATED")
                        end,
                    },
                    minOpacity = {
                        type = "range",
                        name = "Min Opacity",
                        desc = "Oldest icons won't fade below this.",
                        order = 7,
                        min = 0.1, max = 1.0, step = 0.05,
                        isPercent = true,
                        get = function() return ReWind.db.profile.minOpacity end,
                        set = function(_, val)
                            ReWind.db.profile.minOpacity = val
                            ReWind:SendMessage("REWIND_HISTORY_UPDATED")
                        end,
                    },
                    bgAlpha = {
                        type = "range",
                        name = "Background Opacity",
                        desc = "Transparency of the panel background.",
                        order = 8,
                        min = 0, max = 1.0, step = 0.05,
                        isPercent = true,
                        get = function() return ReWind.db.profile.bgAlpha end,
                        set = function(_, val)
                            ReWind.db.profile.bgAlpha = val
                            ReWind:ApplyAppearance()
                        end,
                    },
                    borderTexture = {
                        type = "select",
                        dialogControl = "LSM30_Border",
                        name = "Border",
                        order = 9,
                        values = LSM:HashTable("border"),
                        get = function() return ReWind.db.profile.borderTexture end,
                        set = function(_, val)
                            ReWind.db.profile.borderTexture = val
                            ReWind:ApplyAppearance()
                        end,
                    },
                    assistedCombat = {
                        type = "toggle",
                        name = "Next Spell (Blizzard)",
                        desc = "Show Blizzard's recommended next ability. Take with a grain of salt.",
                        order = 10,
                        hidden = function() return C_AssistedCombat == nil end,
                        get = function() return ReWind.db.profile.assistedCombat end,
                        set = function(_, val)
                            ReWind.db.profile.assistedCombat = val
                            ReWind:SendMessage("REWIND_HISTORY_UPDATED")
                        end,
                    },
                },
            },
            zenith = {
                type = "group",
                name = "Zenith",
                order = 2,
                inline = true,
                args = {
                    zenithAlert = {
                        type = "toggle",
                        name = "Ready Sound & Flash",
                        desc = "Play a sound and flash when Zenith or Zenith Stomp comes off cooldown.",
                        order = 1,
                        get = function() return ReWind.db.profile.zenithAlert end,
                        set = function(_, val) ReWind.db.profile.zenithAlert = val end,
                    },
                    zenithSound = {
                        type = "select",
                        name = "Ready Sound",
                        desc = "Sound to play when Zenith comes off cooldown.",
                        order = 2,
                        values = GetSoundValues,
                        get = function() return ReWind.db.profile.zenithSound end,
                        set = function(_, val) ReWind.db.profile.zenithSound = val end,
                    },
                    zenithIconEnabled = {
                        type = "toggle",
                        name = "Ready Icon",
                        desc = "Show a standalone spell icon while Zenith or Zenith Stomp is off cooldown. Drag to reposition.",
                        order = 3,
                        get = function() return ReWind.db.profile.zenithIconEnabled end,
                        set = function(_, val) ReWind.db.profile.zenithIconEnabled = val end,
                    },
                    zenithCombatOnly = {
                        type = "toggle",
                        name = "Only in Combat",
                        desc = "Only show the Zenith ready icon while in combat.",
                        order = 4,
                        get = function() return ReWind.db.profile.zenithCombatOnly end,
                        set = function(_, val)
                            ReWind.db.profile.zenithCombatOnly = val
                            local display = ReWind:GetModule("Display", true)
                            if not display then return end
                            if val and not UnitAffectingCombat("player") then
                                display:SetZenithIconAlpha(0)
                            elseif not val then
                                display:SetZenithIconAlpha(ReWind.db.profile.zenithIconAlpha)
                            end
                        end,
                    },
                    zenithIconSize = {
                        type = "range",
                        name = "Icon Size",
                        desc = "Size of the Zenith ready icon (px).",
                        order = 5,
                        min = 24, max = 80, step = 2,
                        get = function() return ReWind.db.profile.zenithIconSize end,
                        set = function(_, val)
                            ReWind.db.profile.zenithIconSize = val
                            local display = ReWind:GetModule("Display", true)
                            if display then display:UpdateZenithIconAppearance() end
                        end,
                    },
                    zenithIconAlpha = {
                        type = "range",
                        name = "Icon Opacity",
                        desc = "Opacity of the Zenith ready icon.",
                        order = 6,
                        min = 0.2, max = 1.0, step = 0.05,
                        isPercent = true,
                        get = function() return ReWind.db.profile.zenithIconAlpha end,
                        set = function(_, val)
                            ReWind.db.profile.zenithIconAlpha = val
                            local display = ReWind:GetModule("Display", true)
                            if display then display:UpdateZenithIconAppearance() end
                        end,
                    },
                },
            },
            general = {
                type = "group",
                name = "General",
                order = 3,
                inline = true,
                args = {
                    locked = {
                        type = "toggle",
                        name = "Lock Frames",
                        desc = "Prevent all frames from being dragged.",
                        order = 1,
                        get = function() return ReWind.db.profile.locked end,
                        set = function(_, val) ReWind:SetLocked(val) end,
                    },
                    soundEnabled = {
                        type = "toggle",
                        name = "Mastery Break Sound",
                        desc = "Play an alert sound when you repeat the same ability and break Combo Strikes.",
                        order = 2,
                        get = function() return ReWind.db.profile.soundEnabled end,
                        set = function(_, val) ReWind.db.profile.soundEnabled = val end,
                    },
                    breakSound = {
                        type = "select",
                        name = "Break Sound",
                        desc = "Sound to play on mastery break.",
                        order = 3,
                        values = GetSoundValues,
                        get = function() return ReWind.db.profile.breakSound end,
                        set = function(_, val) ReWind.db.profile.breakSound = val end,
                    },
                    combatReport = {
                        type = "toggle",
                        name = "Combat Report",
                        desc = "Print a mastery uptime summary to chat at the end of each fight and M+ run.",
                        order = 4,
                        get = function() return ReWind.db.profile.combatReport end,
                        set = function(_, val) ReWind.db.profile.combatReport = val end,
                    },
                    timelineAutoShow = {
                        type = "toggle",
                        name = "Auto-show Timeline",
                        desc = "Automatically show the ability timeline after each fight.",
                        order = 5,
                        get = function() return ReWind.db.profile.timelineAutoShow end,
                        set = function(_, val) ReWind.db.profile.timelineAutoShow = val end,
                    },
                    clearOnCombatEnd = {
                        type = "toggle",
                        name = "Clear on Combat End",
                        desc = "Wipe the ability history when you leave combat.",
                        order = 6,
                        get = function() return ReWind.db.profile.clearOnCombatEnd end,
                        set = function(_, val) ReWind.db.profile.clearOnCombatEnd = val end,
                    },
                },
            },
        },
    }
end

function Config:OnEnable()
    LibStub("AceConfig-3.0"):RegisterOptionsTable("ReWind", GetOptions)
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ReWind", "ReWind")
end

function ReWind:OpenConfig()
    if InCombatLockdown() then
        self:Print("Cannot open settings during combat.")
        return
    end
    local config = self:GetModule("Config", true)
    if config and config.optionsFrame then
        local id = config.optionsFrame.name or config.optionsFrame
        Settings.OpenToCategory(id)
    end
end
