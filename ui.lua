--[[
    ui.lua — Word Bomb Auto-Typer
    In-game settings panel built with Roblox GUI instances.
    Dark professional theme. Fully draggable. Collapsible.
    No external assets required — all drawn with Roblox primitives.
--]]

local UI = {}

-- ─── Services ─────────────────────────────────────────────────────────────────

local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local gui    = player:WaitForChild("PlayerGui")

-- ─── Colour Palette ───────────────────────────────────────────────────────────

local C = {
    bg         = Color3.fromHex("1a1a1a"),
    surface    = Color3.fromHex("252525"),
    surfaceAlt = Color3.fromHex("2c2c2c"),
    border     = Color3.fromHex("2f2f2f"),
    accent     = Color3.fromHex("5865F2"),
    accentHov  = Color3.fromHex("4752c4"),
    danger     = Color3.fromHex("ed4245"),
    dangerHov  = Color3.fromHex("c03537"),
    success    = Color3.fromHex("3ba55d"),
    textPri    = Color3.fromHex("ffffff"),
    textSec    = Color3.fromHex("b9bbbe"),
    textMuted  = Color3.fromHex("72767d"),
    inputBg    = Color3.fromHex("1e1e1e"),
    checkOn    = Color3.fromHex("5865F2"),
    checkOff   = Color3.fromHex("3a3a3a"),
    separator  = Color3.fromHex("3a3a3a"),
}

-- ─── Font ─────────────────────────────────────────────────────────────────────

-- Roblox 2022+ font system
local FONT_BODY   = Enum.Font.GothamMedium
local FONT_BOLD   = Enum.Font.GothamBold
local FONT_MONO   = Enum.Font.Code

-- ─── Animation Helpers ────────────────────────────────────────────────────────

local TWEEN_SHORT = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_MED   = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function tween(obj, props, info)
    TweenService:Create(obj, info or TWEEN_SHORT, props):Play()
end

local function hoverButton(btn, normalBg, hoverBg, normalScale, hoverScale)
    normalScale = normalScale or 1
    hoverScale  = hoverScale  or 1  -- Roblox UI scale tweening via UIScale
    btn.MouseEnter:Connect(function()
        tween(btn, { BackgroundColor3 = hoverBg })
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, { BackgroundColor3 = normalBg })
    end)
end

-- ─── Factory Helpers ──────────────────────────────────────────────────────────

local function newInst(className, props)
    local inst = Instance.new(className)
    for k, v in pairs(props or {}) do
        inst[k] = v
    end
    return inst
end

local function corner(r, parent)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = parent
    return c
end

local function stroke(color, thickness, parent)
    local s = Instance.new("UIStroke")
    s.Color     = color or C.border
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function padding(h, v, parent)
    local p = Instance.new("UIPadding")
    p.PaddingLeft   = UDim.new(0, h)
    p.PaddingRight  = UDim.new(0, h)
    p.PaddingTop    = UDim.new(0, v or h)
    p.PaddingBottom = UDim.new(0, v or h)
    p.Parent = parent
    return p
end

local function listLayout(spacing, dir, parent)
    local l = Instance.new("UIListLayout")
    l.Padding           = UDim.new(0, spacing or 6)
    l.FillDirection     = dir or Enum.FillDirection.Vertical
    l.SortOrder         = Enum.SortOrder.LayoutOrder
    l.HorizontalAlignment = Enum.HorizontalAlignment.Center
    l.Parent = parent
    return l
end

-- ─── Widget Builders ─────────────────────────────────────────────────────────

local function makeSectionHeader(text, parent, layoutOrder)
    local row = newInst("Frame", {
        Size            = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        LayoutOrder     = layoutOrder or 0,
        Parent          = parent,
    })
    -- Left line
    newInst("Frame", {
        Size             = UDim2.new(0, 18, 0, 1),
        Position         = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint      = Vector2.new(0, 0.5),
        BackgroundColor3 = C.separator,
        BorderSizePixel  = 0,
        Parent           = row,
    })
    -- Label
    local lbl = newInst("TextLabel", {
        Size             = UDim2.new(1, -44, 1, 0),
        Position         = UDim2.new(0, 22, 0, 0),
        BackgroundTransparency = 1,
        Text             = text:upper(),
        TextColor3       = C.textSec,
        Font             = FONT_BOLD,
        TextSize         = 10,
        TextXAlignment   = Enum.TextXAlignment.Left,
        LetterSpacing    = 2,
        Parent           = row,
    })
    -- Right line
    newInst("Frame", {
        Size             = UDim2.new(1, -22 - lbl.TextBounds.X - 8, 0, 1),
        Position         = UDim2.new(0, 22 + lbl.TextBounds.X + 8, 0.5, 0),
        AnchorPoint      = Vector2.new(0, 0.5),
        BackgroundColor3 = C.separator,
        BorderSizePixel  = 0,
        Parent           = row,
    })
    return row
end

local function makeLabel(text, parent, layoutOrder, color, size)
    return newInst("TextLabel", {
        Size             = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text             = text,
        TextColor3       = color or C.textSec,
        Font             = FONT_BODY,
        TextSize         = size or 13,
        TextXAlignment   = Enum.TextXAlignment.Left,
        LayoutOrder      = layoutOrder or 0,
        Parent           = parent,
    })
end

--- Primary / danger button
local function makeButton(text, parent, layoutOrder, isDanger)
    local bg = isDanger and C.danger or C.accent
    local hv = isDanger and C.dangerHov or C.accentHov

    local btn = newInst("TextButton", {
        Size             = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = bg,
        Text             = text,
        TextColor3       = C.textPri,
        Font             = FONT_BOLD,
        TextSize         = 13,
        AutoButtonColor  = false,
        LayoutOrder      = layoutOrder or 0,
        Parent           = parent,
    })
    corner(6, btn)
    hoverButton(btn, bg, hv)

    -- Press scale feedback via UIScale
    local scale = newInst("UIScale", { Scale = 1, Parent = btn })
    btn.MouseButton1Down:Connect(function()
        tween(scale, { Scale = 0.97 })
    end)
    btn.MouseButton1Up:Connect(function()
        tween(scale, { Scale = 1 })
    end)

    return btn
end

--- Dropdown component returns the frame and a getter/setter API
local function makeDropdown(label, options, default, parent, layoutOrder, onChange)
    local container = newInst("Frame", {
        Size            = UDim2.new(1, 0, 0, 56),
        BackgroundTransparency = 1,
        LayoutOrder     = layoutOrder or 0,
        Parent          = parent,
    })
    listLayout(4, Enum.FillDirection.Vertical, container)

    makeLabel(label, container, 0, C.textSec, 12)

    local selected = default or options[1]

    local ddFrame = newInst("Frame", {
        Size             = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = C.surfaceAlt,
        LayoutOrder      = 1,
        Parent           = container,
    })
    corner(6, ddFrame)
    stroke(C.border, 1, ddFrame)

    local ddLabel = newInst("TextLabel", {
        Size             = UDim2.new(1, -32, 1, 0),
        Position         = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text             = selected,
        TextColor3       = C.textPri,
        Font             = FONT_BODY,
        TextSize         = 13,
        TextXAlignment   = Enum.TextXAlignment.Left,
        Parent           = ddFrame,
    })

    -- Chevron ▼
    newInst("TextLabel", {
        Size             = UDim2.new(0, 24, 1, 0),
        Position         = UDim2.new(1, -28, 0, 0),
        BackgroundTransparency = 1,
        Text             = "▾",
        TextColor3       = C.textSec,
        Font             = FONT_BODY,
        TextSize         = 16,
        TextXAlignment   = Enum.TextXAlignment.Center,
        Parent           = ddFrame,
    })

    -- Clickable overlay
    local ddBtn = newInst("TextButton", {
        Size             = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text             = "",
        Parent           = ddFrame,
    })

    -- Dropdown menu (hidden by default)
    local menu = newInst("Frame", {
        Size             = UDim2.new(1, 0, 0, #options * 30 + 8),
        Position         = UDim2.new(0, 0, 1, 4),
        BackgroundColor3 = C.surface,
        ZIndex           = 20,
        Visible          = false,
        Parent           = ddFrame,
    })
    corner(6, menu)
    stroke(C.border, 1, menu)
    local menuList = listLayout(0, Enum.FillDirection.Vertical, menu)
    menuList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    padding(4, 4, menu)

    for _, option in ipairs(options) do
        local optBtn = newInst("TextButton", {
            Size             = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = C.surface,
            Text             = option,
            TextColor3       = option == selected and C.accent or C.textPri,
            Font             = FONT_BODY,
            TextSize         = 13,
            AutoButtonColor  = false,
            ZIndex           = 21,
            Parent           = menu,
        })
        corner(4, optBtn)
        hoverButton(optBtn, C.surface, C.surfaceAlt)
        optBtn.MouseButton1Click:Connect(function()
            selected         = option
            ddLabel.Text     = option
            ddLabel.TextColor3 = C.textPri
            menu.Visible     = false
            if onChange then onChange(option) end
        end)
    end

    local isOpen = false
    ddBtn.MouseButton1Click:Connect(function()
        isOpen       = not isOpen
        menu.Visible = isOpen
        tween(ddFrame, {
            BackgroundColor3 = isOpen and C.surface or C.surfaceAlt
        })
    end)

    -- Close when clicking outside
    UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if isOpen and not ddFrame:IsAncestorOf(UserInputService:GetFocusedTextBox()) then
                isOpen       = false
                menu.Visible = false
                tween(ddFrame, { BackgroundColor3 = C.surfaceAlt })
            end
        end
    end)

    local api = {
        Get = function() return selected end,
        Set = function(v)
            selected     = v
            ddLabel.Text = v
        end,
    }
    return container, api
end

--- Toggle checkbox
local function makeCheckbox(label, default, parent, layoutOrder, onChange)
    local row = newInst("Frame", {
        Size            = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        LayoutOrder     = layoutOrder or 0,
        Parent          = parent,
    })

    local state = default == nil and true or default

    local box = newInst("Frame", {
        Size             = UDim2.new(0, 18, 0, 18),
        Position         = UDim2.new(0, 0, 0.5, -9),
        BackgroundColor3 = state and C.checkOn or C.checkOff,
        Parent           = row,
    })
    corner(4, box)

    local checkMark = newInst("TextLabel", {
        Size             = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text             = state and "✓" or "",
        TextColor3       = C.textPri,
        Font             = FONT_BOLD,
        TextSize         = 12,
        TextXAlignment   = Enum.TextXAlignment.Center,
        Parent           = box,
    })

    newInst("TextLabel", {
        Size             = UDim2.new(1, -26, 1, 0),
        Position         = UDim2.new(0, 26, 0, 0),
        BackgroundTransparency = 1,
        Text             = label,
        TextColor3       = C.textPri,
        Font             = FONT_BODY,
        TextSize         = 13,
        TextXAlignment   = Enum.TextXAlignment.Left,
        Parent           = row,
    })

    -- Invisible button over full row
    local btn = newInst("TextButton", {
        Size             = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text             = "",
        Parent           = row,
    })
    btn.MouseButton1Click:Connect(function()
        state = not state
        tween(box, { BackgroundColor3 = state and C.checkOn or C.checkOff })
        checkMark.Text = state and "✓" or ""
        if onChange then onChange(state) end
    end)

    local api = {
        Get = function() return state end,
        Set = function(v)
            state = v
            box.BackgroundColor3 = v and C.checkOn or C.checkOff
            checkMark.Text = v and "✓" or ""
        end,
    }
    return row, api
end

--- Number input field
local function makeNumberInput(label, default, minVal, maxVal, parent, layoutOrder, onChange)
    local container = newInst("Frame", {
        Size            = UDim2.new(0.48, 0, 0, 52),
        BackgroundTransparency = 1,
        LayoutOrder     = layoutOrder or 0,
        Parent          = parent,
    })
    listLayout(4, Enum.FillDirection.Vertical, container)
    makeLabel(label, container, 0, C.textSec, 11)

    local box = newInst("TextBox", {
        Size             = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = C.inputBg,
        Text             = tostring(default or 5),
        TextColor3       = C.textPri,
        Font             = FONT_MONO,
        TextSize         = 13,
        ClearTextOnFocus = false,
        LayoutOrder      = 1,
        Parent           = container,
    })
    corner(6, box)
    stroke(C.border, 1, box)
    padding(8, 0, box)

    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if not n then
            box.Text = tostring(default)
            return
        end
        n = math.clamp(math.floor(n), minVal or 1, maxVal or 999)
        box.Text = tostring(n)
        if onChange then onChange(n) end
    end)

    local api = {
        Get = function() return tonumber(box.Text) or default end,
        Set = function(v) box.Text = tostring(v) end,
    }
    return container, api
end

-- ─── Status Indicator ─────────────────────────────────────────────────────────

local statusDot, statusLabel

local STATUS_COLORS = {
    IDLE    = Color3.fromHex("3ba55d"),
    WAITING = Color3.fromHex("faa61a"),
    TYPING  = Color3.fromHex("5865F2"),
    PAUSED  = Color3.fromHex("faa61a"),
    STOPPED = Color3.fromHex("ed4245"),
}

local STATUS_TEXT = {
    IDLE    = "Ready",
    WAITING = "Waiting...",
    TYPING  = "Typing",
    PAUSED  = "Paused",
    STOPPED = "Stopped",
}

local dotPulse  -- coroutine for pulsing dot
local dotActive = false

local function startDotPulse(dotFrame)
    if dotActive then return end
    dotActive = true
    dotPulse = task.spawn(function()
        while dotActive do
            tween(dotFrame, { BackgroundTransparency = 0.5 }, TweenInfo.new(0.5))
            task.wait(0.5)
            tween(dotFrame, { BackgroundTransparency = 0   }, TweenInfo.new(0.5))
            task.wait(0.5)
        end
    end)
end

local function stopDotPulse(dotFrame)
    dotActive = false
    if dotPulse then task.cancel(dotPulse) end
    dotFrame.BackgroundTransparency = 0
end

function UI.UpdateStatus(state)
    if not statusDot or not statusLabel then return end
    local col  = STATUS_COLORS[state] or C.textMuted
    local text = STATUS_TEXT[state]   or state
    tween(statusDot, { BackgroundColor3 = col })
    statusLabel.Text = text

    if state == "TYPING" then
        startDotPulse(statusDot)
    else
        stopDotPulse(statusDot)
    end
end

function UI.UpdateNextWord(word)
    -- Handled by nextWordLabel reference set during build
end

-- ─── Main Build ───────────────────────────────────────────────────────────────

local screenGui
local mainFrame
local isCollapsed = false

function UI.Build(config, typerEngine, wordDatabase, onEnabledChange)
    -- ScreenGui
    screenGui = newInst("ScreenGui", {
        Name            = "WBTyperUI",
        ResetOnSpawn    = false,
        ZIndexBehavior  = Enum.ZIndexBehavior.Sibling,
        Parent          = gui,
    })

    -- ── Main window ──
    local initPos = UDim2.new(
        config.Settings.uiPosition.X,
        0,
        config.Settings.uiPosition.Y,
        0
    )

    mainFrame = newInst("Frame", {
        Name             = "MainWindow",
        Size             = UDim2.new(0, 240, 0, 0),  -- height auto
        Position         = initPos,
        AnchorPoint      = Vector2.new(0, 0),
        BackgroundColor3 = C.bg,
        AutomaticSize    = Enum.AutomaticSize.Y,
        Parent           = screenGui,
    })
    corner(8, mainFrame)
    stroke(C.border, 1, mainFrame)

    -- Drop shadow (fake with a slightly larger darker frame behind)
    local shadow = newInst("Frame", {
        Size             = UDim2.new(1, 8, 1, 8),
        Position         = UDim2.new(0, -4, 0, 4),
        BackgroundColor3 = Color3.fromHex("000000"),
        BackgroundTransparency = 0.6,
        ZIndex           = mainFrame.ZIndex - 1,
        Parent           = mainFrame,
    })
    corner(10, shadow)

    local contentList = listLayout(0, Enum.FillDirection.Vertical, mainFrame)
    contentList.HorizontalAlignment = Enum.HorizontalAlignment.Left

    -- ── Title bar ──
    local titleBar = newInst("Frame", {
        Size             = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = C.surface,
        LayoutOrder      = 0,
        Parent           = mainFrame,
    })
    -- Top corners match main window, bottom stays flat
    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0, 8)
    tc.Parent = titleBar

    newInst("TextLabel", {
        Size             = UDim2.new(1, -80, 1, 0),
        Position         = UDim2.new(0, 14, 0, 0),
        BackgroundTransparency = 1,
        Text             = "Word Bomb Typer",
        TextColor3       = C.textPri,
        Font             = FONT_BOLD,
        TextSize         = 14,
        TextXAlignment   = Enum.TextXAlignment.Left,
        Parent           = titleBar,
    })

    -- Collapse button
    local collapseBtn = newInst("TextButton", {
        Size             = UDim2.new(0, 28, 0, 28),
        Position         = UDim2.new(1, -60, 0.5, -14),
        BackgroundColor3 = C.surfaceAlt,
        Text             = "—",
        TextColor3       = C.textSec,
        Font             = FONT_BOLD,
        TextSize         = 14,
        AutoButtonColor  = false,
        Parent           = titleBar,
    })
    corner(5, collapseBtn)
    hoverButton(collapseBtn, C.surfaceAlt, C.border)

    -- ── Body (scroll wrapper) ──
    local body = newInst("Frame", {
        Size            = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize   = Enum.AutomaticSize.Y,
        LayoutOrder     = 1,
        Parent          = mainFrame,
    })
    local bodyList = listLayout(8, Enum.FillDirection.Vertical, body)
    bodyList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    padding(12, 10, body)

    -- ── Status row ──
    local statusRow = newInst("Frame", {
        Size             = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = C.surface,
        LayoutOrder      = 0,
        Parent           = body,
    })
    corner(6, statusRow)
    padding(10, 0, statusRow)

    statusDot = newInst("Frame", {
        Size             = UDim2.new(0, 8, 0, 8),
        Position         = UDim2.new(0, 0, 0.5, -4),
        BackgroundColor3 = STATUS_COLORS.IDLE,
        Parent           = statusRow,
    })
    corner(4, statusDot)

    statusLabel = newInst("TextLabel", {
        Size             = UDim2.new(1, -18, 1, 0),
        Position         = UDim2.new(0, 16, 0, 0),
        BackgroundTransparency = 1,
        Text             = "Ready",
        TextColor3       = C.textPri,
        Font             = FONT_BODY,
        TextSize         = 13,
        TextXAlignment   = Enum.TextXAlignment.Left,
        Parent           = statusRow,
    })

    -- Next word preview
    local nextWordLabel = newInst("TextLabel", {
        Size             = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text             = "",
        TextColor3       = Color3.fromHex("5865F2"),
        BackgroundTransparency = 1,
        Font             = FONT_MONO,
        TextSize         = 11,
        TextTransparency = 0.4,
        TextXAlignment   = Enum.TextXAlignment.Left,
        LayoutOrder      = 1,
        Parent           = body,
    })

    -- Override UpdateNextWord to update this label
    UI.UpdateNextWord = function(word)
        nextWordLabel.Text = word and ("Next: " .. word) or ""
    end

    typerEngine.OnWordChosen(function(word)
        UI.UpdateNextWord(word)
    end)

    -- ── Settings section ──
    makeSectionHeader("Settings", body, 2)

    -- Word Mode dropdown
    local wordModes = {"SUPER LONG", "LONG", "MEDIUM", "SHORT", "TINY", "CUSTOM"}
    local wordModeMap = {
        ["SUPER LONG"] = "SUPER_LONG",
        ["LONG"]       = "LONG",
        ["MEDIUM"]     = "MEDIUM",
        ["SHORT"]      = "SHORT",
        ["TINY"]       = "TINY",
        ["CUSTOM"]     = "CUSTOM",
    }
    local wordModeRevMap = {}
    for display, internal in pairs(wordModeMap) do
        wordModeRevMap[internal] = display
    end

    local currentModeDisplay = wordModeRevMap[config.Settings.wordMode] or "MEDIUM"
    local _, wordModeApi = makeDropdown("Word Mode", wordModes, currentModeDisplay, body, 3, function(val)
        config.Set("wordMode", wordModeMap[val])
        config.Save()
    end)

    -- Typing Speed dropdown
    local speedOptions = {"INSTANT", "FAST", "NORMAL", "SLOW", "HUMAN LIKE"}
    local speedMap = {
        ["INSTANT"]    = "INSTANT",
        ["FAST"]       = "FAST",
        ["NORMAL"]     = "NORMAL",
        ["SLOW"]       = "SLOW",
        ["HUMAN LIKE"] = "HUMAN_LIKE",
    }
    local speedRevMap = {}
    for display, internal in pairs(speedMap) do
        speedRevMap[internal] = display
    end

    local currentSpeedDisplay = speedRevMap[config.Settings.typingSpeed] or "NORMAL"
    local _, speedApi = makeDropdown("Typing Speed", speedOptions, currentSpeedDisplay, body, 4, function(val)
        config.Set("typingSpeed", speedMap[val])
        config.Save()
    end)

    -- Custom range (shown only when CUSTOM mode selected)
    local customRow = newInst("Frame", {
        Size            = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize   = Enum.AutomaticSize.Y,
        LayoutOrder     = 5,
        Visible         = config.Settings.wordMode == "CUSTOM",
        Parent          = body,
    })
    listLayout(6, Enum.FillDirection.Horizontal, customRow)

    local _, minApi = makeNumberInput("Min Length", config.Settings.customMinLen, 1, 50, customRow, 0, function(n)
        config.Set("customMinLen", n)
        config.Save()
    end)
    local _, maxApi = makeNumberInput("Max Length", config.Settings.customMaxLen, 1, 100, customRow, 1, function(n)
        config.Set("customMaxLen", n)
        config.Save()
    end)

    -- Show/hide custom row based on mode selection
    wordModeApi.Set(currentModeDisplay)
    local origWordModeChange = nil  -- already wired via closure

    -- Checkboxes
    local _, autoSubmitApi = makeCheckbox("Auto-submit", config.Settings.autoSubmit, body, 6, function(v)
        config.Set("autoSubmit", v)
        config.Save()
    end)
    local _, smartFilterApi = makeCheckbox("Smart pattern match", config.Settings.smartFilter, body, 7, function(v)
        config.Set("smartFilter", v)
        config.Save()
    end)

    -- ── Quick Actions section ──
    makeSectionHeader("Actions", body, 8)

    local enableBtn = makeButton(config.Settings.enabled and "■  Stop" or "▶  Start", body, 9, false)
    enableBtn.BackgroundColor3 = config.Settings.enabled and C.danger or C.accent
    enableBtn.MouseButton1Click:Connect(function()
        local newEnabled = not config.Settings.enabled
        config.Set("enabled", newEnabled)
        if newEnabled then
            enableBtn.Text = "■  Stop"
            tween(enableBtn, { BackgroundColor3 = C.danger })
            hoverButton(enableBtn, C.danger, C.dangerHov)
        else
            enableBtn.Text = "▶  Start"
            tween(enableBtn, { BackgroundColor3 = C.accent })
            hoverButton(enableBtn, C.accent, C.accentHov)
        end
        if onEnabledChange then onEnabledChange(newEnabled) end
    end)

    local testBtn = makeButton("Test Word", body, 10, false)
    testBtn.BackgroundColor3 = C.surfaceAlt
    hoverButton(testBtn, C.surfaceAlt, C.surface)
    testBtn.MouseButton1Click:Connect(function()
        local minLen, maxLen = config.GetActiveLengthRange()
        local pattern = config.Settings.smartFilter and typerEngine.GetCurrentPrompt() or nil
        local word    = wordDatabase.FindWord(minLen, maxLen, pattern)
        if word then
            typerEngine.TypeWord(word, config)
        else
            statusLabel.Text = "No word found!"
            task.delay(2, function() statusLabel.Text = STATUS_TEXT[typerEngine.GetState()] end)
        end
    end)

    local stopBtn = makeButton("Stop (F8)", body, 11, true)
    stopBtn.MouseButton1Click:Connect(function()
        typerEngine.Stop()
    end)

    -- Spacer at bottom
    newInst("Frame", {
        Size            = UDim2.new(1, 0, 0, 4),
        BackgroundTransparency = 1,
        LayoutOrder     = 99,
        Parent          = body,
    })

    -- ── Collapse logic ──
    collapseBtn.MouseButton1Click:Connect(function()
        isCollapsed = not isCollapsed
        body.Visible   = not isCollapsed
        collapseBtn.Text = isCollapsed and "▶" or "—"
    end)

    -- ── Drag logic ──
    local dragging     = false
    local dragStart    = Vector2.new(0, 0)
    local frameStart   = Vector2.new(0, 0)

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = input.Position
            frameStart = Vector2.new(
                mainFrame.Position.X.Offset,
                mainFrame.Position.Y.Offset
            )
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            local vp    = workspace.CurrentCamera.ViewportSize
            local newX  = math.clamp(frameStart.X + delta.X, 0, vp.X - mainFrame.AbsoluteSize.X)
            local newY  = math.clamp(frameStart.Y + delta.Y, 0, vp.Y - mainFrame.AbsoluteSize.Y)
            mainFrame.Position = UDim2.new(0, newX, 0, newY)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if dragging then
                dragging = false
                -- Save position as fraction
                local vp = workspace.CurrentCamera.ViewportSize
                config.Set("uiPosition", {
                    X = mainFrame.AbsolutePosition.X / vp.X,
                    Y = mainFrame.AbsolutePosition.Y / vp.Y,
                })
                config.Save()
            end
        end
    end)

    -- ── F6 toggle visibility ──
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == config.Settings.toggleKey then
            screenGui.Enabled = not screenGui.Enabled
        end
    end)

    -- Wire engine state to status indicator
    typerEngine.OnStateChange(function(state)
        UI.UpdateStatus(state)
    end)

    return screenGui
end

function UI.Destroy()
    if screenGui then
        screenGui:Destroy()
        screenGui = nil
    end
end

return UI
