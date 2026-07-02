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
            growDirection = "right",
            iconAlpha = 1.0,
            opacityStep = 0.12,
            minOpacity = 0.3,
            soundEnabled = true,
            breakSound = "raid_warning",
            breakSoundCustomId = "",
            zenithSound = "talent_ready",
            zenithSoundCustomId = "",
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
            zenithGlowStyle = "glow",
            zenithGlowColor = nil,
            zenithGlowIntensity = 0.9,
            zenithIconPosition = nil,
            assistedPosition = nil,
            bgAlpha = 0.8,
            borderTexture = "Blizzard Tooltip",
            timelinePosition = nil,
            timelineWidth = nil,
            position = nil,
        },
    }
end

local SOUND_LIST = {
    { key = "wood_break",     name = "Wood Break (Default Break)",    id = 173248 },
    { key = "talent_ready",   name = "Talent Ready (Default Zenith)", id = 73280 },
    { key = "raid_warning",   name = "Raid Warning",                  id = 8959 },
    { key = "ready_check",    name = "Ready Check",                   id = 8960 },
    { key = "alarm1",         name = "Alarm Clock 1",                 id = 12867 },
    { key = "alarm2",         name = "Alarm Clock 2",                 id = 12889 },
    { key = "alarm3",         name = "Alarm Clock 3",                 id = 12890 },
    { key = "pvp_flag",       name = "PvP Flag Taken",                id = 8174 },
    { key = "levelup",        name = "Level Up",                      id = 888 },
    { key = "map_ping",       name = "Map Ping",                      id = 3175 },
    { key = "loot_coin",      name = "Loot Coin",                     id = 120 },
    { key = "quest_complete", name = "Quest Complete",                id = 878 },
    { key = "none",           name = "None",                          id = nil },
    { key = "custom",         name = "Custom SoundKit ID",             id = nil },
}

local SOUND_BY_KEY = {}
local SOUND_VALUES = {}
for _, entry in ipairs(SOUND_LIST) do
    SOUND_BY_KEY[entry.key] = entry
    SOUND_VALUES[entry.key] = entry.name
end

function ReWind:PlayConfigSound(settingKey)
    local key = self.db.profile[settingKey]
    if key == "custom" then
        local id = tonumber(self.db.profile[settingKey .. "CustomId"])
        if id then PlaySound(id, "Master") end
        return
    end
    local entry = SOUND_BY_KEY[key]
    if entry and entry.id then
        PlaySound(entry.id, "Master")
    end
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
        tile = true,
        tileSize = 16,
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
                            display:UpdatePanelVisibility()
                            if val then display:Refresh() end
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
                            ReWind:GetModule("Display"):UpdatePanelVisibility()
                        end,
                    },
                    iconsHeader = {
                        type = "header",
                        name = "Icons",
                        order = 10,
                    },
                    historyCount = {
                        type = "range",
                        name = "History Length",
                        desc = "How many recent abilities to display.",
                        order = 11,

                        min = 2,
                        max = 12,
                        step = 1,
                        get = function() return ReWind.db.profile.historyCount end,
                        set = function(_, val)
                            ReWind.db.profile.historyCount = val
                            ReWind:SendMessage("REWIND_HISTORY_UPDATED")
                        end,
                    },
                    growDirection = {
                        type = "select",
                        name = "Growth Direction",
                        desc = "Direction the history strip grows from newest to oldest.",
                        order = 12,
                        values = {
                            right = "Right",
                            left = "Left",
                            up = "Up",
                            down = "Down",
                        },
                        get = function() return ReWind.db.profile.growDirection end,
                        set = function(_, val)
                            ReWind.db.profile.growDirection = val
                            ReWind:SendMessage("REWIND_HISTORY_UPDATED")
                        end,
                    },
                    iconSize = {
                        type = "range",
                        name = "Icon Size",
                        desc = "Base size of the most recent ability icon (px).",
                        order = 13,

                        min = 20,
                        max = 64,
                        step = 2,
                        get = function() return ReWind.db.profile.iconSize end,
                        set = function(_, val)
                            ReWind.db.profile.iconSize = val
                            ReWind:SendMessage("REWIND_HISTORY_UPDATED")
                        end,
                    },
                    fadingHeader = {
                        type = "header",
                        name = "Icon Fading",
                        order = 20,
                    },
                    iconAlpha = {
                        type = "range",
                        name = "Base Opacity",
                        desc = "Opacity of the most recent (newest) icon.",
                        order = 21,

                        min = 0.2,
                        max = 1.0,
                        step = 0.05,
                        isPercent = true,
                        get = function() return ReWind.db.profile.iconAlpha end,
                        set = function(_, val)
                            ReWind.db.profile.iconAlpha = val
                            ReWind:SendMessage("REWIND_HISTORY_UPDATED")
                        end,
                    },
                    opacityStep = {
                        type = "range",
                        name = "Fade Per Icon",
                        desc = "How much each older icon fades compared to the one before it (0 = no fade).",
                        order = 22,

                        min = 0,
                        max = 0.3,
                        step = 0.02,
                        isPercent = true,
                        get = function() return ReWind.db.profile.opacityStep end,
                        set = function(_, val)
                            ReWind.db.profile.opacityStep = val
                            ReWind:SendMessage("REWIND_HISTORY_UPDATED")
                        end,
                    },
                    minOpacity = {
                        type = "range",
                        name = "Fade Floor",
                        desc = "Oldest icons won't fade below this opacity.",
                        order = 23,

                        min = 0.1,
                        max = 1.0,
                        step = 0.05,
                        isPercent = true,
                        get = function() return ReWind.db.profile.minOpacity end,
                        set = function(_, val)
                            ReWind.db.profile.minOpacity = val
                            ReWind:SendMessage("REWIND_HISTORY_UPDATED")
                        end,
                    },
                    appearanceHeader = {
                        type = "header",
                        name = "Panel Appearance",
                        order = 30,
                    },
                    bgAlpha = {
                        type = "range",
                        name = "Background Opacity",
                        desc = "Transparency of the panel background.",
                        order = 31,

                        min = 0,
                        max = 1.0,
                        step = 0.05,
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
                        order = 32,

                        values = LSM:HashTable("border"),
                        get = function() return ReWind.db.profile.borderTexture end,
                        set = function(_, val)
                            ReWind.db.profile.borderTexture = val
                            ReWind:ApplyAppearance()
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
                        desc = "Play a sound and flash when Zenith comes off cooldown.",
                        order = 1,

                        get = function() return ReWind.db.profile.zenithAlert end,
                        set = function(_, val) ReWind.db.profile.zenithAlert = val end,
                    },
                    zenithSound = {
                        type = "select",
                        name = "Sound",
                        desc = "Sound to play when Zenith comes off cooldown.",
                        order = 2,
                        values = SOUND_VALUES,
                        get = function() return ReWind.db.profile.zenithSound end,
                        set = function(_, val) ReWind.db.profile.zenithSound = val end,
                    },
                    zenithSoundCustom = {
                        type = "input",
                        name = "SoundKit ID",
                        desc = "Enter a WoW soundKitID number.",
                        order = 5,
                        hidden = function() return ReWind.db.profile.zenithSound ~= "custom" end,
                        get = function() return ReWind.db.profile.zenithSoundCustomId end,
                        set = function(_, val) ReWind.db.profile.zenithSoundCustomId = val end,
                    },
                    zenithSoundTest = {
                        type = "execute",
                        name = "Test",
                        desc = "Preview the selected zenith sound.",
                        order = 4,
                        func = function() ReWind:PlayConfigSound("zenithSound") end,
                    },
                    iconHeader = {
                        type = "header",
                        name = "Ready Icon",
                        order = 11,
                    },
                    zenithIconEnabled = {
                        type = "toggle",
                        name = "Show Icon",
                        desc = "Show a standalone spell icon while a tracked spell is off cooldown. Drag to reposition.",
                        order = 12,

                        get = function() return ReWind.db.profile.zenithIconEnabled end,
                        set = function(_, val) ReWind.db.profile.zenithIconEnabled = val end,
                    },
                    zenithCombatOnly = {
                        type = "toggle",
                        name = "Only in Combat",
                        desc = "Only show the Zenith ready icon while in combat.",
                        order = 13,

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
                        order = 14,

                        min = 24,
                        max = 80,
                        step = 2,
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
                        order = 15,
                        min = 0.2,
                        max = 1.0,
                        step = 0.05,
                        isPercent = true,
                        get = function() return ReWind.db.profile.zenithIconAlpha end,
                        set = function(_, val)
                            ReWind.db.profile.zenithIconAlpha = val
                            local display = ReWind:GetModule("Display", true)
                            if display then display:UpdateZenithIconAppearance() end
                        end,
                    },
                    glowHeader = {
                        type = "header",
                        name = "Glow Effect",
                        order = 20,
                    },
                    zenithGlowStyle = {
                        type = "select",
                        name = "Style",
                        desc = "Glow effect around the Zenith ready icon.",
                        order = 21,
                        values = {
                            glow = "Pulse",
                            proc = "Proc",
                            ants = "Ants (Classic)",
                            none = "None",
                        },
                        get = function() return ReWind.db.profile.zenithGlowStyle end,
                        set = function(_, val)
                            ReWind.db.profile.zenithGlowStyle = val
                            local display = ReWind:GetModule("Display", true)
                            if display then display:ApplyZenithGlow() end
                        end,
                    },
                    zenithGlowColor = {
                        type = "color",
                        name = "Color",
                        desc = "Color of the glow effect. Defaults to class color.",
                        order = 22,
                        get = function() return ReWind:GetGlowColor() end,
                        set = function(_, r, g, b)
                            ReWind.db.profile.zenithGlowColor = { r = r, g = g, b = b }
                            local display = ReWind:GetModule("Display", true)
                            if display then display:ApplyZenithGlow() end
                        end,
                    },
                    zenithGlowClassColor = {
                        type = "execute",
                        name = "Class Color",
                        desc = "Reset glow color to your class color.",
                        order = 23,
                        func = function()
                            ReWind.db.profile.zenithGlowColor = nil
                            local display = ReWind:GetModule("Display", true)
                            if display then display:ApplyZenithGlow() end
                        end,
                    },
                    zenithGlowIntensity = {
                        type = "range",
                        name = "Intensity",
                        desc = "Peak brightness of the glow pulse.",
                        order = 24,
                        min = 0.2,
                        max = 1.0,
                        step = 0.05,
                        isPercent = true,
                        get = function() return ReWind.db.profile.zenithGlowIntensity end,
                        set = function(_, val)
                            ReWind.db.profile.zenithGlowIntensity = val
                            local display = ReWind:GetModule("Display", true)
                            if display then display:ApplyZenithGlow() end
                        end,
                    },
                },
            },
            nextSpell = {
                type = "group",
                name = "Next Spell",
                order = 3,
                inline = true,
                hidden = function() return C_AssistedCombat == nil end,
                args = {
                    assistedCombat = {
                        type = "toggle",
                        name = "Show Next Spell",
                        desc = "Show Blizzard's recommended next ability. Take with a grain of salt.",
                        order = 1,
                        get = function() return ReWind.db.profile.assistedCombat end,
                        set = function(_, val)
                            ReWind.db.profile.assistedCombat = val
                            ReWind:SendMessage("REWIND_HISTORY_UPDATED")
                        end,
                    },
                },
            },
            general = {
                type = "group",
                name = "General",
                order = 4,
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
                    soundsHeader = {
                        type = "header",
                        name = "Sounds",
                        order = 10,
                    },
                    soundEnabled = {
                        type = "toggle",
                        name = "Mastery Break Sound",
                        desc = "Play an alert sound when you repeat the same ability and break Combo Strikes.",
                        order = 11,

                        get = function() return ReWind.db.profile.soundEnabled end,
                        set = function(_, val) ReWind.db.profile.soundEnabled = val end,
                    },
                    breakSound = {
                        type = "select",
                        name = "Sound",
                        desc = "Sound to play on mastery break.",
                        order = 12,
                        values = SOUND_VALUES,
                        get = function() return ReWind.db.profile.breakSound end,
                        set = function(_, val) ReWind.db.profile.breakSound = val end,
                    },
                    breakSoundCustom = {
                        type = "input",
                        name = "SoundKit ID",
                        desc = "Enter a WoW soundKitID number.",
                        order = 13,
                        hidden = function() return ReWind.db.profile.breakSound ~= "custom" end,
                        get = function() return ReWind.db.profile.breakSoundCustomId end,
                        set = function(_, val) ReWind.db.profile.breakSoundCustomId = val end,
                    },
                    breakSoundTest = {
                        type = "execute",
                        name = "Test",
                        desc = "Preview the selected break sound.",
                        order = 14,
                        func = function() ReWind:PlayConfigSound("breakSound") end,
                    },
                    behaviourHeader = {
                        type = "header",
                        name = "Behaviour",
                        order = 20,
                    },
                    combatReport = {
                        type = "toggle",
                        name = "Combat Report",
                        desc = "Print a mastery uptime summary to chat at the end of each fight and M+ run.",
                        order = 21,
                        get = function() return ReWind.db.profile.combatReport end,
                        set = function(_, val) ReWind.db.profile.combatReport = val end,
                    },
                    timelineAutoShow = {
                        type = "toggle",
                        name = "Auto-show Timeline",
                        desc = "Automatically show the ability timeline after each fight.",
                        order = 22,
                        get = function() return ReWind.db.profile.timelineAutoShow end,
                        set = function(_, val) ReWind.db.profile.timelineAutoShow = val end,
                    },
                    clearOnCombatEnd = {
                        type = "toggle",
                        name = "Clear on Combat End",
                        desc = "Wipe the ability history when you leave combat.",
                        order = 23,
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
