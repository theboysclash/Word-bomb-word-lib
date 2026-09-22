--[[
    loader.lua — Word Bomb Auto-Typer
    ──────────────────────────────────
    Paste this ONE file into your executor.
    It fetches all modules from GitHub and runs them.

    GitHub repo: https://github.com/theboysclash/Word-bomb-word-lib
    (Push the .lua files to the repo root for this to work)
--]]

local BASE_URL = "https://raw.githubusercontent.com/theboysclash/Word-bomb-word-lib/main/"

-- ─── Module Loader ────────────────────────────────────────────────────────────
-- Simulates a require() system using loadstring + HTTP

local _modules = {}

local function fetch(name)
    if _modules[name] then return _modules[name] end
    local url = BASE_URL .. name .. ".lua"
    local ok, src = pcall(function()
        return game:HttpGet(url, true)
    end)
    assert(ok, "[Loader] Failed to fetch " .. name .. ": " .. tostring(src))
    local fn, err = loadstring(src, name)
    assert(fn, "[Loader] Compile error in " .. name .. ": " .. tostring(err))
    local result = fn()
    _modules[name] = result
    return result
end

-- ─── Load Order ───────────────────────────────────────────────────────────────

print("[Loader] Fetching Word Bomb Typer modules...")

local Config      = fetch("config")
local WordDB      = fetch("word-database")
local TyperEngine = fetch("typer-engine")
local UI          = fetch("ui")

print("[Loader] All modules loaded. Starting...")

-- ─── Inline Main (word-bomb-typer.lua logic) ─────────────────────────────────

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player           = Players.LocalPlayer

Config.Load()
TyperEngine.RegisterKillKey(Config.Settings.killKey)

local running       = false
local loopCoroutine = nil
local dbLoaded      = false

-- ── DB Load ──
local function loadDB()
    -- Try local readfile first (executor workspace)
    local ok, raw = pcall(function() return readfile("wordlist-286594-words.txt") end)
    if ok and raw and #raw > 100 then
        print("[WBTyper] Loading word list from local file...")
        WordDB.LoadFromString(raw)
        dbLoaded = true
        UI.UpdateStatus("IDLE")
        return
    end
    -- Fallback: download from GitHub (the file is large — ~3MB, give it time)
    print("[WBTyper] Downloading word list from GitHub (~3 MB)...")
    UI.UpdateStatus("WAITING")
    WordDB.LoadFromHTTP(
        function(p) print(string.format("[WBTyper] %.0f%%", p * 100)) end,
        function(success)
            dbLoaded = success
            UI.UpdateStatus(success and "IDLE" or "STOPPED")
            if not success then
                warn("[WBTyper] Word list load failed. Check game HttpService settings.")
            end
        end
    )
end

-- ── Round loop ──
local lastRoundActive = false

local function onRoundStart()
    if not running or not dbLoaded then return end
    task.wait(Config.Settings.startDelay)
    if not running then return end
    local prompt = Config.Settings.smartFilter and TyperEngine.GetCurrentPrompt() or nil
    local minLen, maxLen = Config.GetActiveLengthRange()
    local word = WordDB.FindLongest(minLen, maxLen, prompt)
    if not word and Config.Settings.fallbackToShorter then
        for _, mode in ipairs({"LONG","MEDIUM","SHORT","TINY"}) do
            local r = Config.LengthRanges[mode]
            word = WordDB.FindLongest(r.min, r.max, prompt)
            if word then break end
        end
    end
    if word then
        print(string.format("[WBTyper] → %s (%d chars)", word, #word))
        TyperEngine.TypeWord(word, Config)
    else
        warn("[WBTyper] No word found for prompt: " .. tostring(prompt))
    end
end

local function watchForRounds()
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

local function startAutoTyper()
    if running or not dbLoaded then return end
    running = true
    lastRoundActive = false
    loopCoroutine = task.spawn(watchForRounds)
    print("[WBTyper] Started.")
end

local function stopAutoTyper()
    running = false
    if loopCoroutine then task.cancel(loopCoroutine) end
    TyperEngine.Stop()
    lastRoundActive = false
    print("[WBTyper] Stopped.")
end

-- ── Build UI ──
UI.Build(Config, TyperEngine, WordDB, function(enabled)
    if enabled then startAutoTyper() else stopAutoTyper() end
end)

UI.UpdateStatus("WAITING")
task.spawn(loadDB)

print("[WBTyper] Ready — F6 toggle UI | F8 emergency stop")
