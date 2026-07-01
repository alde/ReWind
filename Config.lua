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
            opacityStep = 0.12,
            minOpacity = 0.3,
            soundEnabled = true,
            combatReport = true,
            zenithAlert = true,
            assistedCombat = false,
            timelineAutoShow = false,
            clearOnCombatEnd = false,
            zenithIconEnabled = true,
            zenithIconPosition = nil,
            bgAlpha = 0.8,
            borderTexture = "Blizzard Tooltip",
            timelinePosition = nil,
            timelineWidth = nil,
            position = nil,
        },
    }
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
            display = {
                type = "group",
                name = "Display",
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
                            if val then f:Show(); display:Refresh() else f:Hide() end
                        end,
                    },
                    locked = {
                        type = "toggle",
                        name = "Lock Panel",
                        desc = "Prevent the panel from being dragged.",
                        order = 2,
                        get = function() return ReWind.db.profile.locked end,
                        set = function(_, val) ReWind:SetLocked(val) end,
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
                    opacityStep = {
                        type = "range",
                        name = "Opacity Fade",
                        desc = "How much each older icon fades (0 = no fade).",
                        order = 5,
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
                        order = 6,
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
                        order = 7,
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
                        order = 8,
                        values = LSM:HashTable("border"),
                        get = function() return ReWind.db.profile.borderTexture end,
                        set = function(_, val)
                            ReWind.db.profile.borderTexture = val
                            ReWind:ApplyAppearance()
                        end,
                    },
                },
            },
            behaviour = {
                type = "group",
                name = "Behaviour",
                order = 2,
                inline = true,
                args = {
                    soundEnabled = {
                        type = "toggle",
                        name = "Mastery Break Sound",
                        desc = "Play an alert sound when you repeat the same ability and break Combo Strikes.",
                        order = 1,
                        get = function() return ReWind.db.profile.soundEnabled end,
                        set = function(_, val) ReWind.db.profile.soundEnabled = val end,
                    },
                    combatReport = {
                        type = "toggle",
                        name = "Combat Report",
                        desc = "Print a mastery uptime summary to chat at the end of each fight and M+ run.",
                        order = 2,
                        get = function() return ReWind.db.profile.combatReport end,
                        set = function(_, val) ReWind.db.profile.combatReport = val end,
                    },
                    zenithAlert = {
                        type = "toggle",
                        name = "Zenith Ready Alert",
                        desc = "Play a sound and flash when Zenith or Zenith Stomp comes off cooldown.",
                        order = 3,
                        get = function() return ReWind.db.profile.zenithAlert end,
                        set = function(_, val) ReWind.db.profile.zenithAlert = val end,
                    },
                    zenithIconEnabled = {
                        type = "toggle",
                        name = "Zenith Ready Icon",
                        desc = "Show a standalone spell icon while Zenith or Zenith Stomp is off cooldown. Drag to reposition.",
                        order = 4,
                        get = function() return ReWind.db.profile.zenithIconEnabled end,
                        set = function(_, val) ReWind.db.profile.zenithIconEnabled = val end,
                    },
                    assistedCombat = {
                        type = "toggle",
                        name = "Next Spell (Blizzard)",
                        desc = "Show Blizzard's recommended next ability. Take with a grain of salt.",
                        order = 5,
                        hidden = function() return C_AssistedCombat == nil end,
                        get = function() return ReWind.db.profile.assistedCombat end,
                        set = function(_, val)
                            ReWind.db.profile.assistedCombat = val
                            ReWind:SendMessage("REWIND_HISTORY_UPDATED")
                        end,
                    },
                    timelineAutoShow = {
                        type = "toggle",
                        name = "Auto-show Timeline",
                        desc = "Automatically show the ability timeline after each fight.",
                        order = 6,
                        get = function() return ReWind.db.profile.timelineAutoShow end,
                        set = function(_, val) ReWind.db.profile.timelineAutoShow = val end,
                    },
                    clearOnCombatEnd = {
                        type = "toggle",
                        name = "Clear on Combat End",
                        desc = "Wipe the ability history when you leave combat.",
                        order = 7,
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
