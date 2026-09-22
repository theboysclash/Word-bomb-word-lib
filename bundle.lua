--[[
╔══════════════════════════════════════════╗
║      WORD BOMB AUTO-TYPER  v1.0          ║
║   Paste into executor → runs instantly   ║
╚══════════════════════════════════════════╝
  F6  = Toggle UI
  F8  = Emergency stop
]]

-- ═══════════════════════════════════════════════════════════════════
--  SERVICES
-- ═══════════════════════════════════════════════════════════════════

local Players            = game:GetService("Players")
local TweenService       = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")
local RunService         = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════════════════════════════════
--  CONFIG
-- ═══════════════════════════════════════════════════════════════════

local TOGGLE_KEY = Enum.KeyCode.F6
local KILL_KEY   = Enum.KeyCode.F8

local WORDLIST_URL =
    "https://raw.githubusercontent.com/theboysclash/Word-bomb-word-lib/main/wordlist-286594-words.txt"

local Settings = {
    wordMode       = "MEDIUM",    -- SUPER_LONG / LONG / MEDIUM / SHORT / TINY / CUSTOM
    typingSpeed    = "NORMAL",    -- INSTANT / FAST / NORMAL / SLOW / HUMAN_LIKE
    customMinLen   = 5,
    customMaxLen   = 15,
    autoSubmit     = true,
    smartFilter    = true,
    startDelay     = 0.4,
    fallbackShorter = true,
}

local SPEED_DELAYS = { INSTANT=0, FAST=0.05, NORMAL=0.10, SLOW=0.20, HUMAN_LIKE=nil }
local HUMAN_MIN, HUMAN_MAX = 0.08, 0.25

local LENGTH_RANGES = {
    SUPER_LONG = {min=20,  max=999},
    LONG       = {min=15,  max=19 },
    MEDIUM     = {min=10,  max=14 },
    SHORT      = {min=5,   max=9  },
    TINY       = {min=1,   max=4  },
}

local function getRange()
    if Settings.wordMode == "CUSTOM" then
        return Settings.customMinLen, Settings.customMaxLen
    end
    local r = LENGTH_RANGES[Settings.wordMode] or LENGTH_RANGES.MEDIUM
    return r.min, r.max
end

-- ═══════════════════════════════════════════════════════════════════
--  WORD DATABASE
-- ═══════════════════════════════════════════════════════════════════

local buckets        = {}   -- buckets[len] = {word, word, ...}
local sortedLengths  = {}
local totalWords     = 0
local dbReady        = false

local function indexWord(w)
    local n = #w
    if not buckets[n] then
        buckets[n] = {}
        -- insert n into sortedLengths in order
        local placed = false
        for i, v in ipairs(sortedLengths) do
            if v > n then table.insert(sortedLengths, i, n); placed = true; break end
        end
        if not placed then sortedLengths[#sortedLengths+1] = n end
    end
    local b = buckets[n]; b[#b+1] = w
end

local function parseAndIndex(raw)
    buckets = {}; sortedLengths = {}; totalWords = 0
    local i = 0
    for line in raw:gmatch("[^\r\n]+") do
        local w = line:match("^%s*(.-)%s*$")
        if #w > 0 then
            indexWord(w:upper())
            totalWords = totalWords + 1
            i = i + 1
            if i % 15000 == 0 then task.wait() end  -- yield to prevent timeout
        end
    end
    dbReady = true
    print(("[WBTyper] Database ready — %d words, %d lengths"):format(totalWords, #sortedLengths))
end

local function findLongest(minLen, maxLen, pattern)
    if not dbReady then return nil end
    local up = pattern and pattern:upper() or nil
    for i = #sortedLengths, 1, -1 do
        local n = sortedLengths[i]
        if n <= maxLen and n >= minLen then
            local b = buckets[n]
            if not up then
                return b[math.random(1, #b)]
            else
                local hits = {}
                for _, w in ipairs(b) do
                    if w:find(up, 1, true) then hits[#hits+1] = w end
                end
                if #hits > 0 then return hits[math.random(1, #hits)] end
            end
        end
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════════
--  TYPER ENGINE
-- ═══════════════════════════════════════════════════════════════════

local TYPER_STATE    = "IDLE"   -- IDLE / TYPING / PAUSED / STOPPED
local stopTyping     = false
local onStateChangeCb = nil
local onWordChosenCb  = nil

-- Key map A-Z
local KEYMAP = {}
for i = 0, 25 do
    KEYMAP[string.char(65+i)] = Enum.KeyCode[string.char(65+i)]
end
local DIGIT_NAMES = {"Zero","One","Two","Three","Four","Five","Six","Seven","Eight","Nine"}
for i, name in ipairs(DIGIT_NAMES) do KEYMAP[tostring(i-1)] = Enum.KeyCode[name] end
KEYMAP["-"] = Enum.KeyCode.Minus
KEYMAP["'"] = Enum.KeyCode.Quote

local function setTyperState(s)
    TYPER_STATE = s
    if onStateChangeCb then pcall(onStateChangeCb, s) end
end

local function sendChar(ch, box)
    local up = ch:upper()
    local kc = KEYMAP[up]
    local ok = false
    if kc then
        ok = pcall(function()
            local shift = ch:match("%u") ~= nil and ch:match("%a") ~= nil
            if shift then VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.LeftShift, false, game) end
            VirtualInputManager:SendKeyEvent(true,  kc, false, game)
            VirtualInputManager:SendKeyEvent(false, kc, false, game)
            if shift then VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game) end
        end)
    end
    if not ok and box then
        box.Text = box.Text .. ch
    end
end

local function sendEnter()
    pcall(function()
        VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.Return, false, game)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
    end)
end

-- TextBox detection
local INPUT_HINTS = {"type here","enter word","type a word","word"}

local function isWordBombBox(obj)
    if not obj:IsA("TextBox") then return false end
    local ph = obj.PlaceholderText:lower()
    for _, h in ipairs(INPUT_HINTS) do
        if ph:find(h, 1, true) then return true end
    end
    local nm = obj.Name:lower()
    return nm:find("input") or nm:find("word")
end

local function findBox(parent)
    for _, c in ipairs(parent:GetChildren()) do
        if isWordBombBox(c) then return c end
        local f = findBox(c); if f then return f end
    end
end

local activeInputBox = nil

local function getInputBox()
    if activeInputBox and activeInputBox.Parent then return activeInputBox end
    for _, sg in ipairs(playerGui:GetChildren()) do
        local f = findBox(sg)
        if f then activeInputBox = f; return f end
    end
    return nil
end

-- Prompt detection
local function getPrompt()
    for _, sg in ipairs(playerGui:GetChildren()) do
        local function scan(p)
            for _, c in ipairs(p:GetChildren()) do
                if c:IsA("TextLabel") then
                    local t = c.Text:upper():match("^%s*([%u][%u]+)%s*$")
                    if t and #t >= 2 and #t <= 5 then return t end
                end
                local r = scan(c); if r then return r end
            end
        end
        local r = scan(sg); if r then return r end
    end
    return nil
end

local function typeWord(word, box)
    setTyperState("TYPING")
    stopTyping = false
    if onWordChosenCb then pcall(onWordChosenCb, word) end

    pcall(function() box:CaptureFocus() end)
    task.wait(0.05)

    local speed     = Settings.typingSpeed
    local isHuman   = speed == "HUMAN_LIKE"
    local baseDelay = SPEED_DELAYS[speed] or 0.10

    for i = 1, #word do
        if stopTyping then break end
        sendChar(word:sub(i,i), box)
        if i < #word then
            local d
            if isHuman then
                d = HUMAN_MIN + math.random() * (HUMAN_MAX - HUMAN_MIN)
                if math.random() < 0.08 then d = d + 0.05 + math.random()*0.12 end
            elseif baseDelay > 0 then
                d = baseDelay * (0.9 + math.random()*0.2)
            end
            if d and d > 0 then task.wait(d) end
        end
    end

    if not stopTyping and Settings.autoSubmit then
        task.wait(0.05)
        sendEnter()
    end
    setTyperState("IDLE")
end

local function stopNow()
    stopTyping = true
    setTyperState("STOPPED")
    task.wait(0.05)
    setTyperState("IDLE")
end

-- ═══════════════════════════════════════════════════════════════════
--  UI  (Discord dark theme)
-- ═══════════════════════════════════════════════════════════════════

local C = {
    bg      = Color3.fromHex("1a1a1a"),
    surface = Color3.fromHex("252525"),
    surfAlt = Color3.fromHex("2c2c2c"),
    border  = Color3.fromHex("2f2f2f"),
    accent  = Color3.fromHex("5865F2"),
    accHov  = Color3.fromHex("4752c4"),
    danger  = Color3.fromHex("ed4245"),
    danHov  = Color3.fromHex("c03537"),
    success = Color3.fromHex("3ba55d"),
    warn    = Color3.fromHex("faa61a"),
    txtPri  = Color3.fromHex("ffffff"),
    txtSec  = Color3.fromHex("b9bbbe"),
    txtMute = Color3.fromHex("72767d"),
    inputBg = Color3.fromHex("1e1e1e"),
}

local TI_FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TI_MED  = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function tw(obj, props, ti) TweenService:Create(obj, ti or TI_FAST, props):Play() end

local function ni(cls, props, parent)
    local o = Instance.new(cls)
    for k,v in pairs(props or {}) do o[k]=v end
    if parent then o.Parent = parent end
    return o
end

local function addCorner(r, p) local c=ni("UICorner",{CornerRadius=UDim.new(0,r)},p); return c end
local function addStroke(col,th,p) local s=ni("UIStroke",{Color=col,Thickness=th,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},p); return s end
local function addPad(h,v,p) ni("UIPadding",{PaddingLeft=UDim.new(0,h),PaddingRight=UDim.new(0,h),PaddingTop=UDim.new(0,v or h),PaddingBottom=UDim.new(0,v or h)},p) end
local function addList(sp,dir,p)
    local l=ni("UIListLayout",{Padding=UDim.new(0,sp or 6),FillDirection=dir or Enum.FillDirection.Vertical,SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Center},p)
    return l
end

local function hoverBtn(btn, norm, hov)
    btn.MouseEnter:Connect(function() tw(btn,{BackgroundColor3=hov}) end)
    btn.MouseLeave:Connect(function() tw(btn,{BackgroundColor3=norm}) end)
end

local function makeBtn(text, parent, lo, bgNorm, bgHov, danger)
    bgNorm = bgNorm or C.accent
    bgHov  = bgHov  or C.accHov
    local b = ni("TextButton",{
        Size=UDim2.new(1,0,0,34), BackgroundColor3=bgNorm,
        Text=text, TextColor3=C.txtPri, Font=Enum.Font.GothamBold,
        TextSize=13, AutoButtonColor=false, LayoutOrder=lo or 0, Parent=parent
    })
    addCorner(6,b)
    hoverBtn(b, bgNorm, bgHov)
    local sc = ni("UIScale",{Scale=1},b)
    b.MouseButton1Down:Connect(function() tw(sc,{Scale=0.97}) end)
    b.MouseButton1Up:Connect(function()   tw(sc,{Scale=1  }) end)
    return b
end

-- Dropdown
local openMenus = {}
local function makeDropdown(label, opts, current, parent, lo, onChange)
    local wrap = ni("Frame",{Size=UDim2.new(1,0,0,56),BackgroundTransparency=1,LayoutOrder=lo,Parent=parent})
    addList(4,nil,wrap)

    ni("TextLabel",{Size=UDim2.new(1,0,0,14),BackgroundTransparency=1,Text=label,
        TextColor3=C.txtSec,Font=Enum.Font.GothamMedium,TextSize=11,
        TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=0,Parent=wrap})

    local dd = ni("Frame",{Size=UDim2.new(1,0,0,32),BackgroundColor3=C.surfAlt,LayoutOrder=1,Parent=wrap})
    addCorner(6,dd); addStroke(C.border,1,dd)

    local lbl = ni("TextLabel",{Size=UDim2.new(1,-28,1,0),Position=UDim2.new(0,10,0,0),
        BackgroundTransparency=1,Text=current,TextColor3=C.txtPri,
        Font=Enum.Font.GothamMedium,TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left,Parent=dd})

    ni("TextLabel",{Size=UDim2.new(0,22,1,0),Position=UDim2.new(1,-24,0,0),
        BackgroundTransparency=1,Text="▾",TextColor3=C.txtSec,
        Font=Enum.Font.GothamMedium,TextSize=14,
        TextXAlignment=Enum.TextXAlignment.Center,Parent=dd})

    local menu = ni("Frame",{Size=UDim2.new(1,0,0,#opts*30+8),Position=UDim2.new(0,0,1,4),
        BackgroundColor3=C.surface,ZIndex=30,Visible=false,Parent=dd})
    addCorner(6,menu); addStroke(C.border,1,menu)
    local ml = addList(0,nil,menu)
    ml.HorizontalAlignment = Enum.HorizontalAlignment.Center
    addPad(4,4,menu)

    for _, opt in ipairs(opts) do
        local ob = ni("TextButton",{Size=UDim2.new(1,0,0,30),BackgroundColor3=C.surface,
            Text=opt,TextColor3=(opt==current and C.accent or C.txtPri),
            Font=Enum.Font.GothamMedium,TextSize=13,AutoButtonColor=false,ZIndex=31,Parent=menu})
        addCorner(4,ob)
        hoverBtn(ob,C.surface,C.surfAlt)
        ob.MouseButton1Click:Connect(function()
            lbl.Text=opt; menu.Visible=false
            tw(dd,{BackgroundColor3=C.surfAlt})
            if onChange then onChange(opt) end
        end)
    end

    local open = false
    local overBtn = ni("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",ZIndex=29,Parent=dd})
    overBtn.MouseButton1Click:Connect(function()
        -- close all other menus
        for _, m in pairs(openMenus) do m.Visible = false end
        open = not open
        menu.Visible = open
        tw(dd,{BackgroundColor3=open and C.surface or C.surfAlt})
        openMenus[menu] = open and menu or nil
    end)

    local api = { Get=function() return lbl.Text end, Set=function(v) lbl.Text=v end }
    return wrap, api
end

-- Checkbox
local function makeCheckbox(label, default, parent, lo, onChange)
    local row = ni("Frame",{Size=UDim2.new(1,0,0,28),BackgroundTransparency=1,LayoutOrder=lo,Parent=parent})
    local state = default
    local box = ni("Frame",{Size=UDim2.new(0,18,0,18),Position=UDim2.new(0,0,0.5,-9),
        BackgroundColor3=state and C.accent or C.surfAlt,Parent=row})
    addCorner(4,box)
    local tick = ni("TextLabel",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,
        Text=state and "✓" or "",TextColor3=C.txtPri,
        Font=Enum.Font.GothamBold,TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Center,Parent=box})
    ni("TextLabel",{Size=UDim2.new(1,-26,1,0),Position=UDim2.new(0,26,0,0),
        BackgroundTransparency=1,Text=label,TextColor3=C.txtPri,
        Font=Enum.Font.GothamMedium,TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left,Parent=row})
    local ob = ni("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",Parent=row})
    ob.MouseButton1Click:Connect(function()
        state = not state
        tw(box,{BackgroundColor3=state and C.accent or C.surfAlt})
        tick.Text = state and "✓" or ""
        if onChange then onChange(state) end
    end)
    return row, { Get=function() return state end, Set=function(v) state=v; box.BackgroundColor3=v and C.accent or C.surfAlt; tick.Text=v and "✓" or "" end }
end

-- Number input
local function makeNumInput(label, default, minV, maxV, parent, lo, onChange)
    local wrap = ni("Frame",{Size=UDim2.new(0.48,0,0,52),BackgroundTransparency=1,LayoutOrder=lo,Parent=parent})
    addList(4,nil,wrap)
    ni("TextLabel",{Size=UDim2.new(1,0,0,14),BackgroundTransparency=1,Text=label,
        TextColor3=C.txtSec,Font=Enum.Font.GothamMedium,TextSize=11,
        TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=0,Parent=wrap})
    local tb = ni("TextBox",{Size=UDim2.new(1,0,0,30),BackgroundColor3=C.inputBg,
        Text=tostring(default),TextColor3=C.txtPri,Font=Enum.Font.Code,
        TextSize=13,ClearTextOnFocus=false,LayoutOrder=1,Parent=wrap})
    addCorner(6,tb); addStroke(C.border,1,tb); addPad(8,0,tb)
    tb.FocusLost:Connect(function()
        local n = tonumber(tb.Text)
        if not n then tb.Text=tostring(default); return end
        n = math.clamp(math.floor(n), minV or 1, maxV or 999)
        tb.Text = tostring(n)
        if onChange then onChange(n) end
    end)
    return wrap, {Get=function() return tonumber(tb.Text) or default end}
end

-- Status colours / text
local SCOL = {IDLE=Color3.fromHex("3ba55d"),WAITING=Color3.fromHex("faa61a"),TYPING=Color3.fromHex("5865F2"),STOPPED=Color3.fromHex("ed4245")}
local STXT = {IDLE="Ready",WAITING="Loading...",TYPING="Typing",STOPPED="Stopped"}

-- ─── Build the window ────────────────────────────────────────────────────────

local sg = ni("ScreenGui",{Name="WBTyperUI",ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,Parent=playerGui})

-- Shadow
local shadowHost = ni("Frame",{Size=UDim2.new(0,248,0,0),Position=UDim2.new(0.76,0,0.04,0),
    BackgroundTransparency=1,AutomaticSize=Enum.AutomaticSize.Y,Parent=sg})
local shadow = ni("Frame",{Size=UDim2.new(1,8,1,8),Position=UDim2.new(0,-4,0,4),
    BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0.55,ZIndex=0,Parent=shadowHost})
addCorner(10,shadow)

-- Main frame
local win = ni("Frame",{Name="WBTyper",Size=UDim2.new(0,240,0,0),Position=UDim2.new(0.77,0,0.04,0),
    BackgroundColor3=C.bg,AutomaticSize=Enum.AutomaticSize.Y,ZIndex=5,Parent=sg})
addCorner(8,win); addStroke(C.border,1,win)
addList(0,nil,win)

-- Title bar
local tbar = ni("Frame",{Size=UDim2.new(1,0,0,40),BackgroundColor3=C.surface,LayoutOrder=0,ZIndex=6,Parent=win})
addCorner(8,tbar)
addPad(14,0,tbar)
ni("TextLabel",{Size=UDim2.new(1,-60,1,0),BackgroundTransparency=1,Text="Word Bomb Typer",
    TextColor3=C.txtPri,Font=Enum.Font.GothamBold,TextSize=14,
    TextXAlignment=Enum.TextXAlignment.Left,ZIndex=7,Parent=tbar})

local colBtn = ni("TextButton",{Size=UDim2.new(0,26,0,26),Position=UDim2.new(1,-32,0.5,-13),
    BackgroundColor3=C.surfAlt,Text="—",TextColor3=C.txtSec,Font=Enum.Font.GothamBold,
    TextSize=13,AutoButtonColor=false,ZIndex=8,Parent=tbar})
addCorner(5,colBtn)
hoverBtn(colBtn,C.surfAlt,C.border)

-- Body
local body = ni("Frame",{Size=UDim2.new(1,0,0,0),BackgroundTransparency=1,
    AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=1,ZIndex=6,Parent=win})
addList(8,nil,body)
addPad(12,10,body)

-- Status row
local statusRow = ni("Frame",{Size=UDim2.new(1,0,0,28),BackgroundColor3=C.surface,LayoutOrder=0,ZIndex=7,Parent=body})
addCorner(6,statusRow); addPad(10,0,statusRow)

local dot = ni("Frame",{Size=UDim2.new(0,8,0,8),Position=UDim2.new(0,0,0.5,-4),
    BackgroundColor3=SCOL.IDLE,ZIndex=8,Parent=statusRow})
addCorner(4,dot)

local statusLbl = ni("TextLabel",{Size=UDim2.new(1,-18,1,0),Position=UDim2.new(0,16,0,0),
    BackgroundTransparency=1,Text="Loading wordlist...",TextColor3=C.txtPri,
    Font=Enum.Font.GothamMedium,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=8,Parent=statusRow})

-- Next-word preview
local nextLbl = ni("TextLabel",{Size=UDim2.new(1,0,0,14),BackgroundTransparency=1,
    Text="",TextColor3=Color3.fromHex("5865F2"),TextTransparency=0.4,
    Font=Enum.Font.Code,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left,
    LayoutOrder=1,ZIndex=7,Parent=body})

-- Dot pulse
local dotPulseActive = false
local function startPulse()
    if dotPulseActive then return end
    dotPulseActive = true
    task.spawn(function()
        while dotPulseActive do
            tw(dot,{BackgroundTransparency=0.5},TweenInfo.new(0.5))
            task.wait(0.5)
            tw(dot,{BackgroundTransparency=0},TweenInfo.new(0.5))
            task.wait(0.5)
        end
    end)
end
local function stopPulse() dotPulseActive=false; dot.BackgroundTransparency=0 end

local function setStatus(state)
    local col = SCOL[state] or SCOL.IDLE
    local txt = STXT[state] or state
    tw(dot,{BackgroundColor3=col})
    statusLbl.Text = txt
    if state=="TYPING" then startPulse() else stopPulse() end
end

-- Wire typer state to status
onStateChangeCb = setStatus
onWordChosenCb  = function(w) nextLbl.Text = w and ("Next: "..w) or "" end

-- Section header helper
local function secHeader(text, lo)
    local f = ni("Frame",{Size=UDim2.new(1,0,0,18),BackgroundTransparency=1,LayoutOrder=lo,ZIndex=7,Parent=body})
    ni("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,0.5,0),
        BackgroundColor3=C.border,BorderSizePixel=0,ZIndex=7,Parent=f})
    ni("Frame",{Size=UDim2.new(0,8,1,0),BackgroundColor3=C.bg,BorderSizePixel=0,ZIndex=8,Parent=f})
    local lf = ni("Frame",{Size=UDim2.new(0,0,1,0),Position=UDim2.new(0,0,0,0),
        BackgroundTransparency=1,AutomaticSize=Enum.AutomaticSize.X,ZIndex=8,Parent=f})
    ni("TextLabel",{Size=UDim2.new(0,0,1,0),BackgroundTransparency=1,
        AutomaticSize=Enum.AutomaticSize.X,Text=" "..text:upper().." ",
        TextColor3=C.txtMute,Font=Enum.Font.GothamBold,TextSize=10,ZIndex=9,Parent=lf})
end

-- ── Settings section ──
secHeader("Settings", 2)

local wordModeOpts = {"SUPER LONG","LONG","MEDIUM","SHORT","TINY","CUSTOM"}
local wModeMap     = {["SUPER LONG"]="SUPER_LONG",["LONG"]="LONG",["MEDIUM"]="MEDIUM",["SHORT"]="SHORT",["TINY"]="TINY",["CUSTOM"]="CUSTOM"}
local wModeRev     = {}
for d,i in pairs(wModeMap) do wModeRev[i]=d end

local _, wModeApi = makeDropdown("Word Mode", wordModeOpts, wModeRev[Settings.wordMode] or "MEDIUM", body, 3, function(v)
    Settings.wordMode = wModeMap[v] or "MEDIUM"
end)

local speedOpts    = {"INSTANT","FAST","NORMAL","SLOW","HUMAN LIKE"}
local speedMap     = {["INSTANT"]="INSTANT",["FAST"]="FAST",["NORMAL"]="NORMAL",["SLOW"]="SLOW",["HUMAN LIKE"]="HUMAN_LIKE"}
local speedRev     = {}
for d,i in pairs(speedMap) do speedRev[i]=d end

local _, speedApi = makeDropdown("Typing Speed", speedOpts, speedRev[Settings.typingSpeed] or "NORMAL", body, 4, function(v)
    Settings.typingSpeed = speedMap[v] or "NORMAL"
end)

-- Custom range
local customRow = ni("Frame",{Size=UDim2.new(1,0,0,0),BackgroundTransparency=1,
    AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=5,
    Visible=Settings.wordMode=="CUSTOM",ZIndex=7,Parent=body})
addList(6,Enum.FillDirection.Horizontal,customRow)

local _, minApi = makeNumInput("Min Len", Settings.customMinLen, 1, 50, customRow, 0, function(n) Settings.customMinLen=n end)
local _, maxApi = makeNumInput("Max Len", Settings.customMaxLen, 1, 100, customRow, 1, function(n) Settings.customMaxLen=n end)

-- Checkboxes
local _, autoSApi  = makeCheckbox("Auto-submit",         Settings.autoSubmit,   body, 6,  function(v) Settings.autoSubmit=v end)
local _, smartFApi = makeCheckbox("Smart pattern match", Settings.smartFilter,  body, 7,  function(v) Settings.smartFilter=v end)

-- ── Actions section ──
secHeader("Actions", 8)

local running     = false
local loopCoro    = nil
local lastRound   = false

local startStopBtn = makeBtn("▶  Start", body, 9, C.accent, C.accHov)

local testBtn = makeBtn("Test Word", body, 10, C.surfAlt, C.surface)
local stopBtn = makeBtn("Stop  (F8)", body, 11, C.danger, C.danHov)

ni("Frame",{Size=UDim2.new(1,0,0,4),BackgroundTransparency=1,LayoutOrder=99,Parent=body})

-- ── Collapse ──
local collapsed = false
colBtn.MouseButton1Click:Connect(function()
    collapsed = not collapsed
    body.Visible = not collapsed
    colBtn.Text = collapsed and "▶" or "—"
end)

-- ── Drag ──
local drag, dragStart, winStart = false, Vector2.new(), Vector2.new()
tbar.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        drag = true
        dragStart = inp.Position
        winStart  = Vector2.new(win.Position.X.Offset, win.Position.Y.Offset)
    end
end)
UserInputService.InputChanged:Connect(function(inp)
    if drag and inp.UserInputType == Enum.UserInputType.MouseMovement then
        local d   = inp.Position - dragStart
        local vp  = workspace.CurrentCamera.ViewportSize
        local nx  = math.clamp(winStart.X + d.X, 0, vp.X - win.AbsoluteSize.X)
        local ny  = math.clamp(winStart.Y + d.Y, 0, vp.Y - win.AbsoluteSize.Y)
        win.Position = UDim2.new(0, nx, 0, ny)
    end
end)
UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
end)

-- ═══════════════════════════════════════════════════════════════════
--  GAME LOOP
-- ═══════════════════════════════════════════════════════════════════

local function onRoundStart()
    if not running or not dbReady then return end
    task.wait(Settings.startDelay)
    if not running then return end
    local prompt = Settings.smartFilter and getPrompt() or nil
    local minL, maxL = getRange()
    local word = findLongest(minL, maxL, prompt)
    if not word and Settings.fallbackShorter then
        for _, mode in ipairs({"LONG","MEDIUM","SHORT","TINY"}) do
            local r = LENGTH_RANGES[mode]
            word = findLongest(r.min, r.max, prompt)
            if word then break end
        end
    end
    if word then
        local box = getInputBox()
        if box then
            print(("[WBTyper] → %s (%d)"):format(word, #word))
            typeWord(word, box)
        end
    else
        warn("[WBTyper] No word found" .. (prompt and (" for '"..prompt.."'") or ""))
    end
end

local function watchLoop()
    while running do
        local box = getInputBox()
        if box and not lastRound then
            lastRound = true
            task.spawn(onRoundStart)
        elseif not box then
            lastRound = false
        end
        task.wait(0.3)
    end
end

local function startTyper()
    if running then return end
    if not dbReady then setStatus("WAITING"); return end
    running   = true
    lastRound = false
    loopCoro  = task.spawn(watchLoop)
    tw(startStopBtn,{BackgroundColor3=C.danger})
    startStopBtn.Text = "■  Stop"
end

local function stopTyper()
    running = false
    if loopCoro then task.cancel(loopCoro) end
    stopNow()
    tw(startStopBtn,{BackgroundColor3=C.accent})
    startStopBtn.Text = "▶  Start"
end

startStopBtn.MouseButton1Click:Connect(function()
    if running then stopTyper() else startTyper() end
end)

testBtn.MouseButton1Click:Connect(function()
    if not dbReady then return end
    local minL, maxL = getRange()
    local prompt = Settings.smartFilter and getPrompt() or nil
    local word = findLongest(minL, maxL, prompt)
    if word then
        local box = getInputBox()
        if box then typeWord(word, box) end
    else
        statusLbl.Text = "No word found!"
        task.delay(2, function() setStatus(TYPER_STATE) end)
    end
end)

stopBtn.MouseButton1Click:Connect(stopTyper)

-- Hotkeys
UserInputService.InputBegan:Connect(function(inp, gp)
    if gp then return end
    if inp.KeyCode == KILL_KEY   then stopTyper() end
    if inp.KeyCode == TOGGLE_KEY then sg.Enabled = not sg.Enabled end
end)

-- ═══════════════════════════════════════════════════════════════════
--  WORD LIST LOAD  (local file first, then HTTP)
-- ═══════════════════════════════════════════════════════════════════

task.spawn(function()
    setStatus("WAITING")

    -- Try local readfile (executor workspace)
    local ok, raw = pcall(function() return readfile("wordlist-286594-words.txt") end)
    if ok and raw and #raw > 500 then
        print("[WBTyper] Loading from local file...")
        parseAndIndex(raw)
        setStatus("IDLE")
        return
    end

    -- HTTP fallback
    print("[WBTyper] Downloading wordlist from GitHub (~3 MB)...")
    local hok, hres = pcall(function()
        return game:HttpGet(WORDLIST_URL, true)
    end)

    if hok and hres and #hres > 500 then
        print("[WBTyper] Download done. Indexing...")
        parseAndIndex(hres)
        setStatus("IDLE")
    else
        setStatus("STOPPED")
        statusLbl.Text = "Wordlist load FAILED"
        warn("[WBTyper] Could not load wordlist. Place 'wordlist-286594-words.txt' in your executor folder.")
    end
end)

print("[WBTyper] Loaded — F6 toggle UI  |  F8 stop")
