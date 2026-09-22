--[[
    typer-engine.lua — Word Bomb Auto-Typer
    Handles keystroke simulation, round detection, and all timing logic.
    Designed to run inside Roblox via a LocalScript or executor.
--]]

local TyperEngine = {}

-- ─── Services ─────────────────────────────────────────────────────────────────

local Players            = game:GetService("Players")
local UserInputService   = game:GetService("UserInputService")
local RunService         = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player             = Players.LocalPlayer
local gui                = player:WaitForChild("PlayerGui")

-- ─── State ────────────────────────────────────────────────────────────────────

local State = {
    IDLE    = "IDLE",
    WAITING = "WAITING",   -- Round starting, waiting for startDelay
    TYPING  = "TYPING",
    PAUSED  = "PAUSED",    -- User manually took over
    STOPPED = "STOPPED",
}

local currentState    = State.IDLE
local activeCoroutine = nil
local stopRequested   = false
local onStateChange   = nil   -- Callback: fn(newState)
local onWordChosen    = nil   -- Callback: fn(word) — for UI preview
local inputBox        = nil   -- The detected TextBox in Word Bomb
local lastWord        = ""

-- ─── Keymaps ──────────────────────────────────────────────────────────────────

-- Map ASCII characters to Roblox KeyCode enums
-- Only printable ASCII needed; upper/lowercase handled via Shift
local KEY_MAP = {}
do
    -- A–Z
    for i = 0, 25 do
        local ch = string.char(65 + i)   -- 'A' = 65
        KEY_MAP[ch] = Enum.KeyCode[ch]
    end
    -- 0–9
    for i = 0, 9 do
        local ch = tostring(i)
        KEY_MAP[ch] = Enum.KeyCode["Zero"]:EnumItems()[i + 1]
            or Enum.KeyCode["Keypad" .. i]
    end
    -- Overrides for digits (the enum names in Roblox)
    local digitNames = {"Zero","One","Two","Three","Four","Five","Six","Seven","Eight","Nine"}
    for i, name in ipairs(digitNames) do
        KEY_MAP[tostring(i - 1)] = Enum.KeyCode[name]
    end
    -- Common punctuation — Word Bomb words are typically alphabetic,
    -- but include hyphen just in case
    KEY_MAP["-"] = Enum.KeyCode.Minus
    KEY_MAP["'"] = Enum.KeyCode.Quote
end

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function setState(newState)
    currentState = newState
    if onStateChange then
        onStateChange(newState)
    end
end

local function randomDelay(minSec, maxSec)
    return minSec + math.random() * (maxSec - minSec)
end

--- Adds subtle human-like rhythm variation (±10% of base delay).
local function humanVariance(delay)
    return delay * (0.9 + math.random() * 0.2)
end

-- ─── Keystroke Simulation ─────────────────────────────────────────────────────

--- Sends a single character to the game via VirtualInputManager.
--- Falls back to direct TextBox manipulation when VIM is unavailable.
local function sendChar(char, textBox)
    local upper = char:upper()
    local keyCode = KEY_MAP[upper]

    -- Primary method: VirtualInputManager (works in exploits / Roblox open API)
    local ok = pcall(function()
        if keyCode then
            -- Shift for uppercase / symbols
            local needsShift = (char == upper and char:match("%a"))
            if needsShift then
                VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.LeftShift, false, game)
            end
            VirtualInputManager:SendKeyEvent(true,  keyCode, false, game)
            VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
            if needsShift then
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
            end
        end
    end)

    -- Fallback: inject directly into the TextBox text property
    if not ok and textBox then
        textBox.Text = textBox.Text .. char
    end
end

--- Presses Enter to submit the typed word.
local function sendEnter()
    pcall(function()
        VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.Return, false, game)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
    end)
end

-- ─── TextBox Detection ────────────────────────────────────────────────────────

-- Word Bomb's input field has a recognisable placeholder text.
local INPUT_PLACEHOLDERS = {
    "type here",
    "enter word",
    "type a word",
    "word",
}

local function matchesWordBombInput(tb)
    if not tb:IsA("TextBox") then return false end
    local ph = tb.PlaceholderText:lower()
    for _, hint in ipairs(INPUT_PLACEHOLDERS) do
        if ph:find(hint, 1, true) then return true end
    end
    return tb.Name:lower():find("input") ~= nil
       or tb.Name:lower():find("word")  ~= nil
end

--- Recursively searches a GUI tree for the Word Bomb input TextBox.
local function findInputBox(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if matchesWordBombInput(child) then
            return child
        end
        local found = findInputBox(child)
        if found then return found end
    end
    return nil
end

--- Scans all ScreenGuis in PlayerGui for the Word Bomb input field.
local function detectInputBox()
    for _, screenGui in ipairs(gui:GetChildren()) do
        if screenGui:IsA("ScreenGui") or screenGui:IsA("LayerCollector") then
            local found = findInputBox(screenGui)
            if found then return found end
        end
    end
    return nil
end

-- ─── Prompt Detection ─────────────────────────────────────────────────────────

-- Word Bomb shows the required letter pattern in a TextLabel.
-- We look for a label whose text looks like "AB" or "ABC" (2-4 uppercase chars).
local PROMPT_PATTERNS = {
    "prompt", "letters", "syllable", "contains", "mustcontain",
}

local function looksLikePromptLabel(label)
    if not label:IsA("TextLabel") then return false end
    local name = label.Name:lower()
    for _, hint in ipairs(PROMPT_PATTERNS) do
        if name:find(hint, 1, true) then return true end
    end
    -- Also match labels whose text is 2-4 uppercase letters only
    return label.Text:match("^%u%u+$") ~= nil
end

local function findPromptLabel(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if looksLikePromptLabel(child) then return child end
        local found = findPromptLabel(child)
        if found then return found end
    end
    return nil
end

function TyperEngine.GetCurrentPrompt()
    for _, screenGui in ipairs(gui:GetChildren()) do
        local label = findPromptLabel(screenGui)
        if label then
            local text = label.Text:upper():match("^%s*([%u]+)%s*$")
            if text and #text >= 2 then
                return text
            end
        end
    end
    return nil
end

-- ─── Core Typing Coroutine ────────────────────────────────────────────────────

--- Types `word` into `textBox` character by character with configured delays.
local function typeWordRoutine(word, textBox, config)
    local delay      = config.typingDelay       -- nil if HUMAN_LIKE
    local humanLike  = config.humanLike
    local humanMin   = config.humanLikeMin
    local humanMax   = config.humanLikeMax
    local autoSubmit = config.autoSubmit

    setState(State.TYPING)
    lastWord = word

    -- Focus the TextBox first
    pcall(function()
        textBox:CaptureFocus()
    end)

    task.wait(0.05)  -- Tiny stabilisation pause

    for i = 1, #word do
        if stopRequested then break end

        -- Detect if user started typing manually (text was modified)
        -- If so, yield to PAUSED until they're done
        if textBox.Text ~= "" and textBox.Text ~= word:sub(1, i - 1) then
            setState(State.PAUSED)
            -- Wait until the box is cleared (new round) or we're stopped
            repeat task.wait(0.1) until textBox.Text == "" or stopRequested
            if stopRequested then break end
            setState(State.TYPING)
        end

        local ch = word:sub(i, i)
        sendChar(ch, textBox)

        if i < #word then
            local waitTime
            if humanLike then
                waitTime = randomDelay(humanMin, humanMax)
                -- Occasionally add a longer pause (simulates hesitation)
                if math.random() < 0.08 then
                    waitTime = waitTime + randomDelay(0.05, 0.15)
                end
            elseif delay and delay > 0 then
                waitTime = humanVariance(delay)
            else
                waitTime = 0
            end
            if waitTime > 0 then
                task.wait(waitTime)
            end
        end
    end

    if not stopRequested and autoSubmit then
        task.wait(0.05)
        sendEnter()
    end

    setState(State.IDLE)
end

-- ─── Public API ───────────────────────────────────────────────────────────────

--- Type a given word. Config is pulled from the Config module passed in.
--- @param word    string  The word to type (will be uppercased automatically)
--- @param config  table   Config.Settings snapshot
function TyperEngine.TypeWord(word, config)
    if currentState == State.TYPING then
        warn("[Typer] Already typing — ignoring request.")
        return
    end

    local box = inputBox or detectInputBox()
    if not box then
        warn("[Typer] No input box detected. Cannot type.")
        return
    end
    inputBox = box

    stopRequested = false

    local typeConfig = {
        typingDelay  = config.SpeedDelays and config.SpeedDelays[config.typingSpeed] or 0.1,
        humanLike    = config.typingSpeed == "HUMAN_LIKE",
        humanLikeMin = config.HumanLikeMin or 0.08,
        humanLikeMax = config.HumanLikeMax or 0.25,
        autoSubmit   = config.autoSubmit,
    }

    if onWordChosen then onWordChosen(word:upper()) end

    activeCoroutine = task.spawn(function()
        typeWordRoutine(word:upper(), box, typeConfig)
    end)
end

--- Immediately halt all typing activity.
function TyperEngine.Stop()
    stopRequested = true
    if activeCoroutine then
        task.cancel(activeCoroutine)
        activeCoroutine = nil
    end
    setState(State.STOPPED)
    task.wait(0.1)
    setState(State.IDLE)
end

--- Force a fresh scan for the Word Bomb input box.
function TyperEngine.RefreshInputBox()
    inputBox = detectInputBox()
    return inputBox ~= nil
end

function TyperEngine.GetState()
    return currentState
end

function TyperEngine.GetLastWord()
    return lastWord
end

function TyperEngine.GetStateEnum()
    return State
end

--- Register callbacks
function TyperEngine.OnStateChange(fn)  onStateChange = fn  end
function TyperEngine.OnWordChosen(fn)   onWordChosen  = fn  end

-- ─── Kill-Switch Hotkey ───────────────────────────────────────────────────────

--- Registers the F8 emergency stop hotkey (and F6 toggle, handled by main).
--- @param killKey   Enum.KeyCode
function TyperEngine.RegisterKillKey(killKey)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == killKey then
            TyperEngine.Stop()
            print("[Typer] Kill-switch activated.")
        end
    end)
end

return TyperEngine
