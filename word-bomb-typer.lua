--[[
    word-bomb-typer.lua — Word Bomb Auto-Typer  (MAIN ENTRY POINT)
    ─────────────────────────────────────────────────────────────────
    Usage:
      1. Inject this script via your preferred Roblox executor.
      2. The UI will appear in the top-right corner.
      3. Press F6 to toggle UI visibility.
      4. Press F8 (or the Stop button) as an emergency kill-switch.

    Dependencies (must be in the same directory / executor require path):
      • config.lua
      • word-database.lua
      • typer-engine.lua
      • ui.lua
--]]

-- ─── Bootstrap ────────────────────────────────────────────────────────────────

-- Roblox executors typically expose a 'loadfile' or 'loadstring' + 'readfile'.
-- We support both: ModuleScript require() in Studio, and executor loadstring.

local function tryRequire(path)
    -- Studio / ModuleScript environment
    if script and script:FindFirstChild(path) then
        return require(script[path])
    end
    -- Executor environment (loadfile / readfile)
    local ok, result = pcall(function()
        return loadstring(readfile(path .. ".lua"))()
    end)
    if ok then return result end
    -- Fallback: try without extension
    ok, result = pcall(function()
        return loadstring(readfile(path))()
    end)
    if ok then return result end
    error("[WBTyper] Could not load module: " .. path .. "\n" .. tostring(result))
end

local Config      = tryRequire("config")
local WordDB      = tryRequire("word-database")
local TyperEngine = tryRequire("typer-engine")
local UI          = tryRequire("ui")

-- ─── Services ─────────────────────────────────────────────────────────────────

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- ─── Globals ──────────────────────────────────────────────────────────────────

local running         = false  -- Auto-typer loop active
local loopCoroutine   = nil

-- ─── Startup ──────────────────────────────────────────────────────────────────

print("[WBTyper] Initialising...")

-- Load persisted settings
Config.Load()

-- Register kill-switch
TyperEngine.RegisterKillKey(Config.Settings.killKey)

-- ─── Word Database Loading ────────────────────────────────────────────────────

-- Try executor readfile first (local copy)
local dbLoaded = false

local function loadDB()
    -- Method 1: Local file via executor readfile
    local ok, raw = pcall(function()
        return readfile("wordlist-286594-words.txt")
    end)
    if ok and raw and #raw > 100 then
        print("[WBTyper] Loading word list from local file...")
        WordDB.LoadFromString(raw)
        dbLoaded = true
        return
    end

    -- Method 2: HTTP (requires HttpService enabled in game settings)
    print("[WBTyper] Local file not found — attempting HTTP load...")
    UI.UpdateStatus("WAITING")

    WordDB.LoadFromHTTP(
        function(progress)
            -- Could push to a loading bar here if desired
            print(string.format("[WBTyper] Loading: %.0f%%", progress * 100))
        end,
        function(success)
            dbLoaded = success
            if success then
                print("[WBTyper] Word database ready. " .. WordDB.GetTotalWords() .. " words.")
                UI.UpdateStatus("IDLE")
            else
                warn("[WBTyper] Failed to load word database. Check HttpService settings.")
                UI.UpdateStatus("STOPPED")
            end
        end
    )
end

-- ─── Round Detection ──────────────────────────────────────────────────────────

-- We detect rounds by watching for the Word Bomb input TextBox becoming visible.
-- When it appears (or its Visible property flips true), we know a round started.

local lastRoundActive = false
local roundConnections = {}

local function onRoundStart()
    if not running or not dbLoaded then return end

    -- Apply configured start delay (looks more natural)
    task.wait(Config.Settings.startDelay)

    if not running then return end  -- User may have stopped during delay

    local prompt = nil
    if Config.Settings.smartFilter then
        prompt = TyperEngine.GetCurrentPrompt()
        if prompt then
            print("[WBTyper] Detected prompt: " .. prompt)
        end
    end

    local minLen, maxLen = Config.GetActiveLengthRange()

    -- Attempt word selection, with fallback to shorter modes
    local word = WordDB.FindLongest(minLen, maxLen, prompt)

    if not word and Config.Settings.fallbackToShorter then
        -- Walk down through shorter categories
        local fallbackModes = {"LONG","MEDIUM","SHORT","TINY"}
        for _, mode in ipairs(fallbackModes) do
            local range = Config.LengthRanges[mode]
            word = WordDB.FindLongest(range.min, range.max, prompt)
            if word then
                print("[WBTyper] Fell back to mode: " .. mode)
                break
            end
        end
    end

    if not word then
        warn("[WBTyper] No suitable word found for prompt: " .. tostring(prompt))
        return
    end

    print(string.format("[WBTyper] Typing: %s (%d chars)", word, #word))
    TyperEngine.TypeWord(word, Config)
end

--- Monitors the PlayerGui for Word Bomb's input box appearing.
local function watchForRounds()
    -- Poll every 0.3s for the input box (low cost)
    while running do
        local boxVisible = TyperEngine.RefreshInputBox()

        if boxVisible and not lastRoundActive then
            lastRoundActive = true
            task.spawn(onRoundStart)
        elseif not boxVisible then
            lastRoundActive = false
        end

        task.wait(0.3)
    end
end

-- ─── Auto-Typer Loop Control ─────────────────────────────────────────────────

local function startAutoTyper()
    if running then return end
    if not dbLoaded then
        warn("[WBTyper] Cannot start: word database not loaded yet.")
        return
    end
    running         = true
    lastRoundActive = false
    print("[WBTyper] Auto-typer started.")
    loopCoroutine = task.spawn(watchForRounds)
end

local function stopAutoTyper()
    running = false
    if loopCoroutine then
        task.cancel(loopCoroutine)
        loopCoroutine = nil
    end
    TyperEngine.Stop()
    lastRoundActive = false
    print("[WBTyper] Auto-typer stopped.")
end

-- ─── UI Build ─────────────────────────────────────────────────────────────────

-- Build UI (before DB load so user sees loading state)
UI.Build(Config, TyperEngine, WordDB, function(enabled)
    -- Called when user clicks Start / Stop in UI
    if enabled then
        startAutoTyper()
    else
        stopAutoTyper()
    end
end)

UI.UpdateStatus("WAITING")

-- ─── Load Database ────────────────────────────────────────────────────────────

task.spawn(loadDB)

-- ─── F6 Toggle (already wired inside UI.Build) ───────────────────────────────

-- ─── Cleanup on Script Removal ───────────────────────────────────────────────

-- When executor unloads or user leaves, cleanly tear down
if script then
    script.AncestryChanged:Connect(function(_, parent)
        if parent == nil then
            stopAutoTyper()
            UI.Destroy()
            print("[WBTyper] Cleaned up.")
        end
    end)
end

print("[WBTyper] Ready. Press F6 to toggle UI, F8 to emergency-stop.")
