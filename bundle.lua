-- ╔═══════════════════════════════════════════════════════╗
-- ║           WORD BOMB AUTO-TYPER  v2.0                 ║
-- ║  Paste into executor  •  No setup needed             ║
-- ║  F6 = Toggle UI  •  F8 = Emergency Stop             ║
-- ╚═══════════════════════════════════════════════════════╝

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UIS              = game:GetService("UserInputService")
local VIM              = game:GetService("VirtualInputManager")

local lp  = Players.LocalPlayer
local pg  = lp:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════════════════════
--  SETTINGS
-- ═══════════════════════════════════════════════════════

local S = {
    mode        = "MEDIUM",   -- SUPER_LONG LONG MEDIUM SHORT TINY CUSTOM
    speed       = "NORMAL",   -- INSTANT FAST NORMAL SLOW HUMAN
    customMin   = 5,
    customMax   = 15,
    submit      = true,
    smartFilter = true,
    startDelay  = 0.35,
    fallback    = true,
}

local RANGES = {
    SUPER_LONG={min=20,max=999}, LONG={min=15,max=19},
    MEDIUM={min=10,max=14},      SHORT={min=5,max=9},
    TINY={min=1,max=4},
}
local DELAYS = {INSTANT=0, FAST=0.04, NORMAL=0.09, SLOW=0.18, HUMAN=nil}

local function getRange()
    if S.mode=="CUSTOM" then return S.customMin, S.customMax end
    local r=RANGES[S.mode] or RANGES.MEDIUM; return r.min, r.max
end

-- ═══════════════════════════════════════════════════════
--  WORD DATABASE
-- ═══════════════════════════════════════════════════════

local DB    = {}   -- DB[length] = {word,...}
local LENS  = {}   -- sorted lengths
local READY = false
local TOTAL = 0

local WURL = "https://raw.githubusercontent.com/theboysclash/Word-bomb-word-lib/main/wordlist-286594-words.txt"

local function addWord(w)
    local n=#w
    if not DB[n] then
        DB[n]={}
        local ins=false
        for i,v in ipairs(LENS) do if v>n then table.insert(LENS,i,n);ins=true;break end end
        if not ins then LENS[#LENS+1]=n end
    end
    local b=DB[n]; b[#b+1]=w
end

local function loadWords(raw)
    DB={}; LENS={}; TOTAL=0
    local i=0
    for line in raw:gmatch("[^\r\n]+") do
        local w=line:match("^%s*(.-)%s*$")
        if #w>0 then addWord(w:upper()); TOTAL=TOTAL+1; i=i+1
            if i%20000==0 then task.wait() end
        end
    end
    READY=true
    print(("[WB] %d words indexed"):format(TOTAL))
end

local function findBest(minL,maxL,pat)
    if not READY then return nil end
    local up=pat and pat:upper()
    for i=#LENS,1,-1 do
        local n=LENS[i]
        if n<=maxL and n>=minL then
            local b=DB[n]
            if not up then return b[math.random(1,#b)] end
            local hits={}
            for _,w in ipairs(b) do if w:find(up,1,true) then hits[#hits+1]=w end end
            if #hits>0 then return hits[math.random(1,#hits)] end
        end
    end
end

-- ═══════════════════════════════════════════════════════
--  GAME DETECTION
-- ═══════════════════════════════════════════════════════

local cachedBox = nil

local function isInputBox(o)
    if not o:IsA("TextBox") then return false end
    local ph=o.PlaceholderText:lower()
    return ph:find("type")~=nil or ph:find("word")~=nil
        or o.Name:lower():find("input")~=nil
        or o.Name:lower():find("word")~=nil
end

local function scanFor(cls, check, root)
    root = root or pg
    for _,c in ipairs(root:GetDescendants()) do
        if c:IsA(cls) and check(c) then return c end
    end
end

local function getBox()
    if cachedBox and cachedBox.Parent and cachedBox.Visible then return cachedBox end
    cachedBox = scanFor("TextBox", isInputBox)
    return cachedBox
end

local function getPrompt()
    -- Look for 2-5 uppercase letter prompt labels
    for _,lbl in ipairs(pg:GetDescendants()) do
        if lbl:IsA("TextLabel") then
            local t = lbl.Text:upper():match("^%s*([A-Z][A-Z]+)%s*$")
            if t and #t>=2 and #t<=5 then return t end
        end
    end
end

-- ═══════════════════════════════════════════════════════
--  TYPER  (direct text injection — works in all executors)
-- ═══════════════════════════════════════════════════════

local TYPING   = false
local STOP_REQ = false

local onState, onWord  -- callbacks

local function setState(s) TYPING=(s=="TYPING"); if onState then pcall(onState,s) end end

local function pressEnter(box)
    -- Method 1: ReleaseFocus with enterPressed=true  (most reliable)
    local ok = pcall(function() box:ReleaseFocus(true) end)
    if ok then return end
    -- Method 2: VirtualInputManager
    pcall(function()
        VIM:SendKeyEvent(true,  Enum.KeyCode.Return, false, game)
        task.wait(0.03)
        VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
    end)
end

local function doType(word, box)
    setState("TYPING")
    STOP_REQ = false
    if onWord then pcall(onWord, word) end

    local spd    = S.speed
    local human  = spd=="HUMAN"
    local delay  = DELAYS[spd] or 0.09

    -- Focus the box
    pcall(function() box:CaptureFocus() end)
    task.wait(0.08)

    if spd == "INSTANT" then
        -- Inject all at once
        box.Text = word
    else
        -- Character by character via direct text assignment
        -- This is more compatible than VirtualInputManager key events
        box.Text = ""
        for i=1,#word do
            if STOP_REQ then break end
            box.Text = word:sub(1,i)
            local d
            if human then
                d = 0.07 + math.random()*0.18
                if math.random()<0.07 then d=d+0.08+math.random()*0.1 end
            else
                d = delay*(0.88+math.random()*0.24)
            end
            task.wait(d)
        end
    end

    if not STOP_REQ and S.submit then
        task.wait(0.06)
        pressEnter(box)
    end

    task.wait(0.1)
    setState("IDLE")
end

local function stopAll()
    STOP_REQ = true
    setState("STOPPED")
    task.delay(0.2, function() setState("IDLE") end)
end

-- ═══════════════════════════════════════════════════════
--  MAIN LOOP
-- ═══════════════════════════════════════════════════════

local RUNNING  = false
local LC       = nil
local lastSeen = false

local function onRound()
    if not RUNNING or not READY then return end
    task.wait(S.startDelay)
    if not RUNNING then return end

    local box  = getBox()
    if not box then return end

    local pat  = S.smartFilter and getPrompt() or nil
    local mi,ma = getRange()
    local word = findBest(mi,ma,pat)

    if not word and S.fallback then
        for _,m in ipairs({"LONG","MEDIUM","SHORT","TINY"}) do
            local r=RANGES[m]; word=findBest(r.min,r.max,pat)
            if word then break end
        end
    end

    if word then
        print(("[WB] %s  (%d chars)"):format(word,#word))
        doType(word, box)
    else
        warn("[WB] No word found" .. (pat and (" for '"..pat.."'") or ""))
    end
end

local function watchLoop()
    while RUNNING do
        local box = getBox()
        local vis = box ~= nil and (not pcall(function() return not box.Visible end) and box.Visible)
        if box and not lastSeen then lastSeen=true; task.spawn(onRound)
        elseif not box then lastSeen=false end
        task.wait(0.25)
    end
end

local startBtn_ref  -- forward ref
local function startTyper()
    if RUNNING then return end
    if not READY then warn("[WB] Wordlist not loaded yet") return end
    RUNNING=true; lastSeen=false
    LC=task.spawn(watchLoop)
    if startBtn_ref then startBtn_ref.Text="■  Stop" end
end
local function stopTyper()
    RUNNING=false
    if LC then pcall(task.cancel,LC) end
    stopAll()
    if startBtn_ref then startBtn_ref.Text="▶  Start" end
end

-- ═══════════════════════════════════════════════════════
--  UI  ─  clean dark panel
-- ═══════════════════════════════════════════════════════

local COL = {
    bg      = Color3.fromHex("111214"),
    panel   = Color3.fromHex("1e1f22"),
    elevated= Color3.fromHex("2b2d31"),
    border  = Color3.fromHex("3a3c42"),
    accent  = Color3.fromHex("5865f2"),
    accHov  = Color3.fromHex("4752c4"),
    red     = Color3.fromHex("ed4245"),
    redHov  = Color3.fromHex("b83134"),
    green   = Color3.fromHex("23a55a"),
    yellow  = Color3.fromHex("f0b232"),
    white   = Color3.fromHex("f2f3f5"),
    sub     = Color3.fromHex("949ba4"),
    muted   = Color3.fromHex("4e5058"),
}

local TF = TweenInfo.new(0.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
local TM = TweenInfo.new(0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)

local function tw(o,p,t) TweenService:Create(o,t or TF,p):Play() end

local function new(cls,props,par)
    local o=Instance.new(cls)
    for k,v in pairs(props or {}) do o[k]=v end
    if par then o.Parent=par end
    return o
end

local function corner(r,p) return new("UICorner",{CornerRadius=UDim.new(0,r)},p) end
local function stroke(c,t,p) return new("UIStroke",{Color=c,Thickness=t,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},p) end
local function pad(h,v,p) new("UIPadding",{PaddingLeft=UDim.new(0,h),PaddingRight=UDim.new(0,h),PaddingTop=UDim.new(0,v or h),PaddingBottom=UDim.new(0,v or h)},p) end
local function vlist(sp,p) local l=new("UIListLayout",{Padding=UDim.new(0,sp),SortOrder=Enum.SortOrder.LayoutOrder,FillDirection=Enum.FillDirection.Vertical,HorizontalAlignment=Enum.HorizontalAlignment.Center},p); return l end
local function hlist(sp,p) local l=new("UIListLayout",{Padding=UDim.new(0,sp),SortOrder=Enum.SortOrder.LayoutOrder,FillDirection=Enum.FillDirection.Horizontal,VerticalAlignment=Enum.VerticalAlignment.Center},p); return l end

-- Button factory
local function btn(text,par,lo,bg,bghov)
    bg=bg or COL.elevated; bghov=bghov or COL.border
    local b=new("TextButton",{
        Size=UDim2.new(1,0,0,36),BackgroundColor3=bg,Text=text,
        TextColor3=COL.white,Font=Enum.Font.GothamBold,TextSize=13,
        AutoButtonColor=false,LayoutOrder=lo or 0,Parent=par
    })
    corner(7,b)
    b.MouseEnter:Connect(function() tw(b,{BackgroundColor3=bghov}) end)
    b.MouseLeave:Connect(function() tw(b,{BackgroundColor3=bg}) end)
    local sc=new("UIScale",{Scale=1},b)
    b.MouseButton1Down:Connect(function() tw(sc,{Scale=0.96}) end)
    b.MouseButton1Up:Connect(function()   tw(sc,{Scale=1   }) end)
    return b
end

-- Divider
local function divider(par,lo)
    new("Frame",{Size=UDim2.new(1,0,0,1),BackgroundColor3=COL.border,
        BorderSizePixel=0,LayoutOrder=lo,Parent=par})
end

-- Label
local function lbl(text,par,lo,col,sz,font)
    return new("TextLabel",{
        Size=UDim2.new(1,0,0,sz and sz+2 or 16),BackgroundTransparency=1,
        Text=text,TextColor3=col or COL.sub,Font=font or Enum.Font.GothamMedium,
        TextSize=sz or 12,TextXAlignment=Enum.TextXAlignment.Left,
        LayoutOrder=lo or 0,Parent=par
    })
end

-- Dropdown
local openDD = nil
local function dropdown(title,opts,cur,par,lo,cb)
    local wrap=new("Frame",{Size=UDim2.new(1,0,0,58),BackgroundTransparency=1,LayoutOrder=lo,Parent=par})
    vlist(5,wrap)
    lbl(title,wrap,0,COL.sub,11)

    local row=new("Frame",{Size=UDim2.new(1,0,0,34),BackgroundColor3=COL.elevated,LayoutOrder=1,Parent=wrap})
    corner(7,row); stroke(COL.border,1,row)
    pad(12,0,row)

    local txt=new("TextLabel",{Size=UDim2.new(1,-20,1,0),BackgroundTransparency=1,
        Text=cur,TextColor3=COL.white,Font=Enum.Font.GothamMedium,TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left,Parent=row})
    new("TextLabel",{Size=UDim2.new(0,18,1,0),Position=UDim2.new(1,-18,0,0),BackgroundTransparency=1,
        Text="▾",TextColor3=COL.sub,Font=Enum.Font.GothamMedium,TextSize=14,
        TextXAlignment=Enum.TextXAlignment.Center,Parent=row})

    -- Menu
    local menu=new("Frame",{
        Size=UDim2.new(1,0,0,#opts*32+8),Position=UDim2.new(0,0,1,3),
        BackgroundColor3=COL.panel,ZIndex=50,Visible=false,Parent=row
    })
    corner(7,menu); stroke(COL.border,1,menu); pad(5,4,menu)
    vlist(2,menu)

    for _,opt in ipairs(opts) do
        local ob=new("TextButton",{
            Size=UDim2.new(1,0,0,28),BackgroundColor3=COL.panel,
            Text=opt,TextColor3=(opt==cur and COL.accent or COL.white),
            Font=Enum.Font.GothamMedium,TextSize=13,AutoButtonColor=false,
            ZIndex=51,Parent=menu
        })
        corner(5,ob)
        ob.MouseEnter:Connect(function() tw(ob,{BackgroundColor3=COL.elevated}) end)
        ob.MouseLeave:Connect(function() tw(ob,{BackgroundColor3=COL.panel}) end)
        ob.MouseButton1Click:Connect(function()
            txt.Text=opt; menu.Visible=false; openDD=nil
            if cb then cb(opt) end
        end)
    end

    local isOpen=false
    local clk=new("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",ZIndex=49,Parent=row})
    clk.MouseButton1Click:Connect(function()
        if openDD and openDD~=menu then openDD.Visible=false end
        isOpen=not isOpen; menu.Visible=isOpen
        openDD=isOpen and menu or nil
        tw(row,{BackgroundColor3=isOpen and COL.panel or COL.elevated})
    end)

    local api={Get=function() return txt.Text end, Set=function(v) txt.Text=v end}
    return wrap,api
end

-- Checkbox
local function checkbox(label,default,par,lo,cb)
    local row=new("Frame",{Size=UDim2.new(1,0,0,30),BackgroundTransparency=1,LayoutOrder=lo,Parent=par})
    local state=default
    local box=new("Frame",{Size=UDim2.new(0,20,0,20),Position=UDim2.new(0,0,0.5,-10),
        BackgroundColor3=state and COL.accent or COL.elevated,Parent=row})
    corner(5,box); stroke(COL.border,1,box)
    local chk=new("TextLabel",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,
        Text=state and "✓" or "",TextColor3=COL.white,Font=Enum.Font.GothamBold,
        TextSize=13,TextXAlignment=Enum.TextXAlignment.Center,Parent=box})
    new("TextLabel",{Size=UDim2.new(1,-30,1,0),Position=UDim2.new(0,30,0,0),
        BackgroundTransparency=1,Text=label,TextColor3=COL.white,
        Font=Enum.Font.GothamMedium,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,Parent=row})
    local ob=new("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",Parent=row})
    ob.MouseButton1Click:Connect(function()
        state=not state
        tw(box,{BackgroundColor3=state and COL.accent or COL.elevated})
        chk.Text=state and "✓" or ""
        if cb then cb(state) end
    end)
    return row,{Get=function() return state end}
end

-- Number input pair
local function numInput(label,default,minV,maxV,par,lo,cb)
    local wrap=new("Frame",{Size=UDim2.new(0.46,0,0,56),BackgroundTransparency=1,LayoutOrder=lo,Parent=par})
    vlist(5,wrap)
    lbl(label,wrap,0,COL.sub,11)
    local tb=new("TextBox",{Size=UDim2.new(1,0,0,32),BackgroundColor3=COL.elevated,
        Text=tostring(default),TextColor3=COL.white,Font=Enum.Font.Code,TextSize=13,
        ClearTextOnFocus=false,LayoutOrder=1,Parent=wrap})
    corner(7,tb); stroke(COL.border,1,tb); pad(10,0,tb)
    tb.FocusLost:Connect(function()
        local n=tonumber(tb.Text)
        if not n then tb.Text=tostring(default); return end
        n=math.clamp(math.floor(n),minV,maxV); tb.Text=tostring(n)
        if cb then cb(n) end
    end)
    return wrap,{Get=function() return tonumber(tb.Text) or default end}
end

-- ─── Build window ─────────────────────────────────────

local sg=new("ScreenGui",{Name="WBT2",ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,Parent=pg})

-- Outer glow / shadow
local shadow=new("Frame",{Size=UDim2.new(0,266,0,0),Position=UDim2.new(0,0,0,0),
    AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=Color3.new(0,0,0),
    BackgroundTransparency=0.5,ZIndex=1,Parent=sg})
corner(12,shadow)

-- Window
local win=new("Frame",{Size=UDim2.new(0,258,0,0),Position=UDim2.new(0.74,0,0.03,0),
    AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=COL.bg,ZIndex=5,Parent=sg})
corner(10,win); stroke(COL.border,1,win)
vlist(0,win)

-- ─ Title bar
local tbar=new("Frame",{Size=UDim2.new(1,0,0,44),BackgroundColor3=COL.panel,
    LayoutOrder=0,ZIndex=6,Parent=win})
corner(10,tbar)
-- Mask bottom corners of title bar
new("Frame",{Size=UDim2.new(1,0,0,10),Position=UDim2.new(0,0,1,-10),
    BackgroundColor3=COL.panel,BorderSizePixel=0,ZIndex=6,Parent=tbar})

pad(16,0,tbar)

-- Logo dot
new("Frame",{Size=UDim2.new(0,8,0,8),Position=UDim2.new(0,0,0.5,-4),
    BackgroundColor3=COL.accent,ZIndex=7,Parent=tbar})
new("UICorner",{CornerRadius=UDim.new(1,0),Parent=tbar:GetChildren()[#tbar:GetChildren()]})

new("TextLabel",{Size=UDim2.new(1,-60,1,0),Position=UDim2.new(0,16,0,0),
    BackgroundTransparency=1,Text="Word Bomb Typer",TextColor3=COL.white,
    Font=Enum.Font.GothamBold,TextSize=14,TextXAlignment=Enum.TextXAlignment.Left,
    ZIndex=7,Parent=tbar})

local minBtn=new("TextButton",{Size=UDim2.new(0,24,0,24),Position=UDim2.new(1,-28,0.5,-12),
    BackgroundColor3=COL.elevated,Text="−",TextColor3=COL.sub,Font=Enum.Font.GothamBold,
    TextSize=16,AutoButtonColor=false,ZIndex=8,Parent=tbar})
corner(6,minBtn)
minBtn.MouseEnter:Connect(function() tw(minBtn,{BackgroundColor3=COL.border,TextColor3=COL.white}) end)
minBtn.MouseLeave:Connect(function() tw(minBtn,{BackgroundColor3=COL.elevated,TextColor3=COL.sub}) end)

-- ─ Body
local body=new("Frame",{Size=UDim2.new(1,0,0,0),BackgroundTransparency=1,
    AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=1,ZIndex=6,Parent=win})
vlist(0,body)
pad(14,12,body)

-- Status card
local sCard=new("Frame",{Size=UDim2.new(1,0,0,44),BackgroundColor3=COL.panel,
    LayoutOrder=0,ZIndex=7,Parent=body})
corner(8,sCard); stroke(COL.border,1,sCard); pad(14,0,sCard)

local dot=new("Frame",{Size=UDim2.new(0,9,0,9),Position=UDim2.new(0,0,0.5,-4.5),
    BackgroundColor3=COL.green,ZIndex=8,Parent=sCard})
corner(5,dot)

local sLbl=new("TextLabel",{Size=UDim2.new(0.6,0,1,0),Position=UDim2.new(0,18,0,0),
    BackgroundTransparency=1,Text="Loading...",TextColor3=COL.white,
    Font=Enum.Font.GothamMedium,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,
    ZIndex=8,Parent=sCard})

local nextLbl=new("TextLabel",{Size=UDim2.new(0.5,0,1,0),Position=UDim2.new(0.5,-4,0,0),
    BackgroundTransparency=1,Text="",TextColor3=COL.accent,TextTransparency=0.35,
    Font=Enum.Font.Code,TextSize=11,TextXAlignment=Enum.TextXAlignment.Right,
    ZIndex=8,Parent=sCard})

-- Spacer
new("Frame",{Size=UDim2.new(1,0,0,6),BackgroundTransparency=1,LayoutOrder=1,Parent=body})
divider(body,2)
new("Frame",{Size=UDim2.new(1,0,0,6),BackgroundTransparency=1,LayoutOrder=3,Parent=body})

-- Word mode
local WMODE_OPTS={"SUPER LONG","LONG","MEDIUM","SHORT","TINY","CUSTOM"}
local WMODE_MAP={["SUPER LONG"]="SUPER_LONG",LONG="LONG",MEDIUM="MEDIUM",SHORT="SHORT",TINY="TINY",CUSTOM="CUSTOM"}
local WMODE_REV={}; for d,i in pairs(WMODE_MAP) do WMODE_REV[i]=d end

local _,wAPI=dropdown("WORD MODE",WMODE_OPTS,WMODE_REV[S.mode] or "MEDIUM",body,4,function(v)
    S.mode=WMODE_MAP[v] or "MEDIUM"
    -- show/hide custom row
end)

-- Speed
local SPD_OPTS={"INSTANT","FAST","NORMAL","SLOW","HUMAN"}
local _,sAPI=dropdown("TYPING SPEED",SPD_OPTS,S.speed,body,5,function(v) S.speed=v end)

-- Custom range row (hidden unless CUSTOM)
local customRow=new("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
    BackgroundTransparency=1,LayoutOrder=6,Visible=false,Parent=body})
hlist(8,customRow)
local _,minA=numInput("Min Len",S.customMin,1,50,customRow,0,function(n) S.customMin=n end)
local _,maxA=numInput("Max Len",S.customMax,1,100,customRow,1,function(n) S.customMax=n end)

-- Rewire dropdown to show/hide custom row
local origWcb
do
    local raw=wAPI
    -- patch the callback
    local function wcb(v)
        S.mode=WMODE_MAP[v] or "MEDIUM"
        customRow.Visible=(S.mode=="CUSTOM")
    end
    -- re-attach by overriding the internal cb; already wired above — just use WMODE_MAP
end
-- We already set S.mode in the dropdown cb above; toggling customRow:
-- Patch: re-create dropdown with updated cb
local ddFrame = body:FindFirstChild("Frame") -- we'll just do it inline with a state check:
-- Simple fix: re-wire via the existing api's parent button
task.spawn(function()
    -- watch S.mode and toggle customRow
    while task.wait(0.1) do
        customRow.Visible = (S.mode=="CUSTOM")
    end
end)

new("Frame",{Size=UDim2.new(1,0,0,8),BackgroundTransparency=1,LayoutOrder=7,Parent=body})
divider(body,8)
new("Frame",{Size=UDim2.new(1,0,0,8),BackgroundTransparency=1,LayoutOrder=9,Parent=body})

local _,asAPI=checkbox("Auto-submit",S.submit,body,10,function(v) S.submit=v end)
local _,sfAPI=checkbox("Smart pattern match",S.smartFilter,body,11,function(v) S.smartFilter=v end)

new("Frame",{Size=UDim2.new(1,0,0,8),BackgroundTransparency=1,LayoutOrder=12,Parent=body})
divider(body,13)
new("Frame",{Size=UDim2.new(1,0,0,8),BackgroundTransparency=1,LayoutOrder=14,Parent=body})

-- Start/stop button (full width, accent)
local startBtn=btn("▶  Start",body,15,COL.accent,COL.accHov)
startBtn.Size=UDim2.new(1,0,0,38)

new("Frame",{Size=UDim2.new(1,0,0,6),BackgroundTransparency=1,LayoutOrder=16,Parent=body})

-- Action row: Test | Stop
local actRow=new("Frame",{Size=UDim2.new(1,0,0,36),BackgroundTransparency=1,LayoutOrder=17,Parent=body})
hlist(6,actRow)

local testBtn2=new("TextButton",{Size=UDim2.new(0.5,-3,1,0),BackgroundColor3=COL.elevated,
    Text="Test Word",TextColor3=COL.white,Font=Enum.Font.GothamMedium,TextSize=13,
    AutoButtonColor=false,LayoutOrder=0,Parent=actRow})
corner(7,testBtn2)
testBtn2.MouseEnter:Connect(function() tw(testBtn2,{BackgroundColor3=COL.border}) end)
testBtn2.MouseLeave:Connect(function() tw(testBtn2,{BackgroundColor3=COL.elevated}) end)

local stopBtn2=new("TextButton",{Size=UDim2.new(0.5,-3,1,0),BackgroundColor3=COL.elevated,
    Text="Stop  F8",TextColor3=COL.sub,Font=Enum.Font.GothamMedium,TextSize=13,
    AutoButtonColor=false,LayoutOrder=1,Parent=actRow})
corner(7,stopBtn2)
stopBtn2.MouseEnter:Connect(function() tw(stopBtn2,{BackgroundColor3=COL.red,TextColor3=COL.white}) end)
stopBtn2.MouseLeave:Connect(function() tw(stopBtn2,{BackgroundColor3=COL.elevated,TextColor3=COL.sub}) end)

new("Frame",{Size=UDim2.new(1,0,0,12),BackgroundTransparency=1,LayoutOrder=18,Parent=body})

startBtn_ref = startBtn

-- Status update
local SCOL2={IDLE=COL.green,WAITING=COL.yellow,TYPING=COL.accent,STOPPED=COL.red}
local STXT2={IDLE="Ready",WAITING="Loading wordlist...",TYPING="Typing...",STOPPED="Stopped"}
local pulsing=false
local function setStatus(state)
    tw(dot,{BackgroundColor3=SCOL2[state] or COL.green})
    sLbl.Text=STXT2[state] or state
    if state=="TYPING" then
        if not pulsing then pulsing=true
            task.spawn(function()
                while pulsing do
                    tw(dot,{BackgroundTransparency=0.6},TweenInfo.new(0.5))
                    task.wait(0.5)
                    tw(dot,{BackgroundTransparency=0},TweenInfo.new(0.5))
                    task.wait(0.5)
                end
            end)
        end
    else pulsing=false; dot.BackgroundTransparency=0 end
end

onState = setStatus
onWord  = function(w) nextLbl.Text = w and w or "" end

-- Button wiring
startBtn.MouseButton1Click:Connect(function()
    if RUNNING then
        stopTyper()
        tw(startBtn,{BackgroundColor3=COL.accent})
        startBtn.MouseEnter:Connect(function() tw(startBtn,{BackgroundColor3=COL.accHov}) end)
        startBtn.MouseLeave:Connect(function() tw(startBtn,{BackgroundColor3=COL.accent}) end)
    else
        startTyper()
        tw(startBtn,{BackgroundColor3=COL.red})
    end
end)

testBtn2.MouseButton1Click:Connect(function()
    if not READY then return end
    local mi,ma=getRange()
    local pat=S.smartFilter and getPrompt() or nil
    local word=findBest(mi,ma,pat)
    if not word then
        sLbl.Text="No word found!"; task.delay(2,function() setStatus(TYPING and "TYPING" or "IDLE") end); return
    end
    local box=getBox()
    if box then task.spawn(doType, word, box) end
end)

stopBtn2.MouseButton1Click:Connect(stopTyper)

-- Collapse
local collapsed=false
minBtn.MouseButton1Click:Connect(function()
    collapsed=not collapsed
    body.Visible=not collapsed
    minBtn.Text=collapsed and "+" or "−"
    tw(win,{BackgroundColor3=collapsed and COL.panel or COL.bg},TM)
end)

-- Drag from title bar
local drag,ds,ws=false,Vector2.new(),Vector2.new()
tbar.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then
        drag=true; ds=i.Position
        ws=Vector2.new(win.Position.X.Offset,win.Position.Y.Offset)
    end
end)
UIS.InputChanged:Connect(function(i)
    if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
        local d=i.Position-ds
        local vp=workspace.CurrentCamera.ViewportSize
        local nx=math.clamp(ws.X+d.X,0,vp.X-win.AbsoluteSize.X)
        local ny=math.clamp(ws.Y+d.Y,0,vp.Y-win.AbsoluteSize.Y)
        win.Position=UDim2.new(0,nx,0,ny)
        shadow.Position=win.Position
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
end)

-- F6/F8 hotkeys
UIS.InputBegan:Connect(function(i,gp)
    if gp then return end
    if i.KeyCode==Enum.KeyCode.F6 then sg.Enabled=not sg.Enabled end
    if i.KeyCode==Enum.KeyCode.F8 then stopTyper() end
end)

-- ═══════════════════════════════════════════════════════
--  LOAD WORDLIST
-- ═══════════════════════════════════════════════════════

setStatus("WAITING")

task.spawn(function()
    local ok,raw=pcall(function() return readfile("wordlist-286594-words.txt") end)
    if ok and raw and #raw>500 then
        print("[WB] Loading local wordlist...")
        loadWords(raw)
        setStatus("IDLE")
        return
    end
    print("[WB] Downloading wordlist (~3 MB)...")
    local hok,hres=pcall(function() return game:HttpGet(WURL,true) end)
    if hok and hres and #hres>500 then
        print("[WB] Download done, indexing...")
        loadWords(hres)
        setStatus("IDLE")
    else
        setStatus("STOPPED")
        sLbl.Text="Wordlist FAILED — place .txt in executor folder"
        warn("[WB] Wordlist load failed. Place 'wordlist-286594-words.txt' in executor workspace.")
    end
end)

print("[WB] v2.0 ready  •  F6 toggle  •  F8 stop")
