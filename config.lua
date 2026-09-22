--[[
    config.lua — Word Bomb Auto-Typer
    Settings management module.
    All user-configurable options live here.
--]]

local Config = {}

-- ─── Enumerations ────────────────────────────────────────────────────────────

Config.WordMode = {
    SUPER_LONG = "SUPER_LONG",   -- 20+ characters
    LONG       = "LONG",         -- 15-19 characters
    MEDIUM     = "MEDIUM",       -- 10-14 characters
    SHORT      = "SHORT",        -- 5-9 characters
    TINY       = "TINY",         -- 1-4 characters
    CUSTOM     = "CUSTOM",       -- User-defined range
}

Config.TypingSpeed = {
    INSTANT    = "INSTANT",      -- Immediate (no delay)
    FAST       = "FAST",         -- 50ms per key
    NORMAL     = "NORMAL",       -- 100ms per key
    SLOW       = "SLOW",         -- 200ms per key
    HUMAN_LIKE = "HUMAN_LIKE",   -- Random 80-250ms per key
}

-- ─── Speed Delay Lookup (in seconds) ─────────────────────────────────────────

Config.SpeedDelays = {
    INSTANT    = 0,
    FAST       = 0.05,
    NORMAL     = 0.10,
    SLOW       = 0.20,
    HUMAN_LIKE = nil,   -- Handled dynamically in typer engine
}

Config.HumanLikeMin = 0.08   -- seconds
Config.HumanLikeMax = 0.25   -- seconds

-- ─── Word Length Ranges ───────────────────────────────────────────────────────

Config.LengthRanges = {
    SUPER_LONG = { min = 20,  max = math.huge },
    LONG       = { min = 15,  max = 19        },
    MEDIUM     = { min = 10,  max = 14        },
    SHORT      = { min = 5,   max = 9         },
    TINY       = { min = 1,   max = 4         },
    CUSTOM     = { min = 5,   max = 15        },  -- defaults, overridden by user
}

-- ─── Default Settings ─────────────────────────────────────────────────────────

Config.Defaults = {
    wordMode       = Config.WordMode.MEDIUM,
    typingSpeed    = Config.TypingSpeed.NORMAL,
    customMinLen   = 5,
    customMaxLen   = 15,
    autoSubmit     = true,
    smartFilter    = true,
    enabled        = false,
    uiPosition     = { X = 0.78, Y = 0.05 },  -- Fraction of screen size
    killKey        = Enum.KeyCode.F8,
    toggleKey      = Enum.KeyCode.F6,
    startDelay     = 0.4,   -- Seconds to wait after round start before typing
    fallbackToShorter = true, -- If no word found in current mode, try shorter
}

-- ─── Runtime Settings (mutable copy of Defaults) ─────────────────────────────

Config.Settings = {}

function Config.Reset()
    for k, v in pairs(Config.Defaults) do
        if type(v) == "table" then
            Config.Settings[k] = {}
            for kk, vv in pairs(v) do
                Config.Settings[k][kk] = vv
            end
        else
            Config.Settings[k] = v
        end
    end
end

-- ─── Accessors ────────────────────────────────────────────────────────────────

function Config.Get(key)
    return Config.Settings[key]
end

function Config.Set(key, value)
    Config.Settings[key] = value
end

--- Returns the active min/max word length based on current mode.
function Config.GetActiveLengthRange()
    local mode = Config.Settings.wordMode
    if mode == Config.WordMode.CUSTOM then
        return Config.Settings.customMinLen, Config.Settings.customMaxLen
    else
        local range = Config.LengthRanges[mode]
        return range.min, (range.max == math.huge and 999 or range.max)
    end
end

--- Returns the per-keystroke delay in seconds.
--- For HUMAN_LIKE returns nil (engine handles random itself).
function Config.GetTypingDelay()
    local speed = Config.Settings.typingSpeed
    return Config.SpeedDelays[speed]
end

-- ─── Serialisation (save/restore via a folder in PlayerGui) ──────────────────
-- Roblox LocalScripts can't write to files, so we persist to a hidden
-- StringValue tree under PlayerGui between sessions.

local SAVE_PARENT_NAME = "WBTyperConfig"

function Config.Save()
    local ok, err = pcall(function()
        local Players = game:GetService("Players")
        local gui = Players.LocalPlayer:WaitForChild("PlayerGui", 5)
        if not gui then return end

        local folder = gui:FindFirstChild(SAVE_PARENT_NAME)
            or Instance.new("Folder", gui)
        folder.Name = SAVE_PARENT_NAME

        local function saveVal(name, val)
            local t = type(val)
            local inst = folder:FindFirstChild(name)
            if t == "boolean" then
                if not inst or inst.ClassName ~= "BoolValue" then
                    if inst then inst:Destroy() end
                    inst = Instance.new("BoolValue", folder)
                    inst.Name = name
                end
                inst.Value = val
            elseif t == "number" then
                if not inst or inst.ClassName ~= "NumberValue" then
                    if inst then inst:Destroy() end
                    inst = Instance.new("NumberValue", folder)
                    inst.Name = name
                end
                inst.Value = val
            elseif t == "string" then
                if not inst or inst.ClassName ~= "StringValue" then
                    if inst then inst:Destroy() end
                    inst = Instance.new("StringValue", folder)
                    inst.Name = name
                end
                inst.Value = val
            end
        end

        saveVal("wordMode",     Config.Settings.wordMode)
        saveVal("typingSpeed",  Config.Settings.typingSpeed)
        saveVal("customMinLen", Config.Settings.customMinLen)
        saveVal("customMaxLen", Config.Settings.customMaxLen)
        saveVal("autoSubmit",   Config.Settings.autoSubmit)
        saveVal("smartFilter",  Config.Settings.smartFilter)
        saveVal("uiX",          Config.Settings.uiPosition.X)
        saveVal("uiY",          Config.Settings.uiPosition.Y)
    end)
    if not ok then
        warn("[Config] Save failed: " .. tostring(err))
    end
end

function Config.Load()
    Config.Reset()  -- Always start from defaults

    local ok, err = pcall(function()
        local Players = game:GetService("Players")
        local gui = Players.LocalPlayer:WaitForChild("PlayerGui", 5)
        if not gui then return end

        local folder = gui:FindFirstChild(SAVE_PARENT_NAME)
        if not folder then return end

        local function loadVal(name)
            local inst = folder:FindFirstChild(name)
            return inst and inst.Value or nil
        end

        Config.Settings.wordMode     = loadVal("wordMode")     or Config.Settings.wordMode
        Config.Settings.typingSpeed  = loadVal("typingSpeed")  or Config.Settings.typingSpeed
        Config.Settings.customMinLen = loadVal("customMinLen") or Config.Settings.customMinLen
        Config.Settings.customMaxLen = loadVal("customMaxLen") or Config.Settings.customMaxLen
        Config.Settings.autoSubmit   = loadVal("autoSubmit")
        Config.Settings.smartFilter  = loadVal("smartFilter")

        local uiX = loadVal("uiX")
        local uiY = loadVal("uiY")
        if uiX and uiY then
            Config.Settings.uiPosition = { X = uiX, Y = uiY }
        end

        -- Validate enums (prevent corrupt saves)
        if not Config.WordMode[Config.Settings.wordMode] then
            Config.Settings.wordMode = Config.Defaults.wordMode
        end
        if not Config.TypingSpeed[Config.Settings.typingSpeed] then
            Config.Settings.typingSpeed = Config.Defaults.typingSpeed
        end
    end)

    if not ok then
        warn("[Config] Load failed: " .. tostring(err) .. " — using defaults.")
        Config.Reset()
    end
end

-- Initialise with defaults on require
Config.Reset()

return Config
