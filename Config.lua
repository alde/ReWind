local ReWind = _G.ReWind
local Config = ReWind:NewModule("Config")

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
            clearOnCombatEnd = false,
            position = nil,
        },
    }
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
                    assistedCombat = {
                        type = "toggle",
                        name = "Next Spell (Blizzard)",
                        desc = "Show Blizzard's recommended next ability via C_AssistedCombat (12.0+ only). Take with a grain of salt.",
                        order = 4,
                        hidden = function() return C_AssistedCombat == nil end,
                        get = function() return ReWind.db.profile.assistedCombat end,
                        set = function(_, val)
                            ReWind.db.profile.assistedCombat = val
                            ReWind:SendMessage("REWIND_HISTORY_UPDATED")
                        end,
                    },
                    clearOnCombatEnd = {
                        type = "toggle",
                        name = "Clear on Combat End",
                        desc = "Wipe the ability history when you leave combat.",
                        order = 5,
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
