-- ╔═══════════════════════════════════════════════════════════════════╗
-- ║                  WORD BOMB AUTO-TYPER  v2.5                       ║
-- ║         Paste into any Roblox executor  •  Zero setup             ║
-- ║         F6 = Toggle Window  •  F8 = Emergency Stop                ║
-- ╚═══════════════════════════════════════════════════════════════════╝

local Players             = game:GetService("Players")
local TweenService         = game:GetService("TweenService")
local UserInputService     = game:GetService("UserInputService")
local VirtualInputManager  = game:GetService("VirtualInputManager")
local RunService           = game:GetService("RunService")

-- ─── Robust Player & GUI Parent Detection ───────────────────────────
local lp = Players.LocalPlayer
if not lp then
    pcall(function()
        Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    end)
    lp = Players.LocalPlayer
end

local function getGuiParent()
    -- 1. Modern executor gethui function (Synapse, Fluxus, Delta, Wave, Solara, Codex)
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    -- 2. CoreGui (standard executor environment)
    local ok, core = pcall(function() return game:GetService("CoreGui") end)
    if ok and core then
        local test = Instance.new("Folder")
        local pok = pcall(function() test.Parent = core; test.Parent = nil end)
        if pok then return core end
    end
    -- 3. Fallback to LocalPlayer's PlayerGui
    if lp then
        local pg = lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui", 5)
        if pg then return pg end
    end
    return nil
end

local guiParent = getGuiParent()
if not guiParent then
    warn("[WordBomb] Critical Error: Unable to locate GUI parent!")
    return
end

-- Cleanup old instances if re-executing
for _, old in ipairs(guiParent:GetChildren()) do
    if old.Name == "WordBombAutoTyper" or old.Name == "WBT2" then
        pcall(function() old:Destroy() end)
    end
end

-- ─── Configuration & State ───────────────────────────────────────────
local Config = {
    running      = false,
    mode         = "MEDIUM",   -- ANY, SHORT, MEDIUM, LONG, SUPER
    speed        = "NORMAL",   -- INSTANT, FAST, NORMAL, SLOW, HUMAN
    autoSubmit   = true,
    smartFilter  = true,
    startDelay   = 0.30,
    fallback     = true,
}

local RANGES = {
    ANY    = { min = 3,  max = 999 },
    SHORT  = { min = 4,  max = 8   },
    MEDIUM = { min = 9,  max = 13  },
    LONG   = { min = 14, max = 18  },
    SUPER  = { min = 19, max = 999 },
}

local DELAYS = {
    INSTANT = 0,
    FAST    = 0.035,
    NORMAL  = 0.080,
    SLOW    = 0.160,
    HUMAN   = nil, -- Dynamic variance
}

local function getRange()
    local r = RANGES[Config.mode] or RANGES.MEDIUM
    return r.min, r.max
end

-- ─── Color Palette (Discord Obsidian Dark) ───────────────────────────
local Theme = {
    bg          = Color3.fromRGB(16, 18, 23),
    header      = Color3.fromRGB(22, 24, 31),
    card        = Color3.fromRGB(24, 27, 36),
    cardBorder  = Color3.fromRGB(38, 43, 56),
    surface     = Color3.fromRGB(30, 34, 46),
    surfaceHov  = Color3.fromRGB(42, 47, 64),
    accent      = Color3.fromRGB(88, 101, 242),
    accentHov   = Color3.fromRGB(71, 82, 196),
    accentSoft  = Color3.fromRGB(35, 42, 75),
    danger      = Color3.fromRGB(237, 66, 69),
    dangerHov   = Color3.fromRGB(195, 52, 55),
    success     = Color3.fromRGB(59, 165, 93),
    warning     = Color3.fromRGB(250, 166, 26),
    text        = Color3.fromRGB(242, 243, 245),
    textSub     = Color3.fromRGB(150, 155, 170),
    textMuted   = Color3.fromRGB(90, 95, 110),
}

-- ─── Word Database Engine ────────────────────────────────────────────
local DB    = {}     -- DB[length] = { word, ... }
local LENS  = {}     -- Sorted lengths descending
local READY = false
local TOTAL = 0
local WURL  = "https://raw.githubusercontent.com/theboysclash/Word-bomb-word-lib/main/wordlist-286594-words.txt"

-- Embedded starter vocabulary so the script works immediately without waiting
local STARTER_WORDS = {
    "ABOUT","ABOVE","ACROSS","ACTION","ACTIVE","ACTUAL","AFTER","AGAIN","AGAINST","AHEAD",
    "ALMOST","ALONE","ALONG","ALREADY","ALWAYS","AMOUNT","ANIMAL","ANOTHER","ANSWER","ANYONE",
    "APPEAR","AROUND","ARRIVE","ATTACK","ATTEMPT","AUTHOR","BALANCE","BATTLE","BEAUTY","BECOME",
    "BEFORE","BEHIND","BELIEVE","BETWEEN","BEYOND","BOMBARD","BOMBING","BOMBSHELL","BOMBER","BORDER",
    "BOTTLE","BOTTOM","BRANCH","BREATH","BRIDGE","BRIGHT","BROTHER","BUDGET","BUILDING","BUSINESS",
    "CAMERA","CAMPAIGN","CANDIDATE","CAPITAL","CAPTAIN","CAPTURE","CARBON","CAREER","CAREFUL","CARRIER",
    "CASTLE","CASUAL","CAUTION","CENTRAL","CENTURY","CERTAIN","CHAIRMAN","CHAMBER","CHAMPION","CHANCE",
    "CHANGE","CHANNEL","CHAPTER","CHARGE","CHARITY","CHARMING","CHARTER","CHEMICAL","CHESTNUT","CHILDREN",
    "CHOICE","CHOOSE","CHRONIC","CIRCUIT","CIRCUS","CITIZEN","CIVILIAN","CLASSIC","CLEANER","CLIMATE",
    "CLOTHING","COALITION","COLLEAGUE","COLLECT","COMBINE","COMMAND","COMMERCE","COMMUNITY","COMPANY","COMPLEX",
    "COMPUTER","CONDITION","CONDUCT","CONFERENCE","CONGRESS","CONNECT","CONSIDER","CONSTANT","CONSUMER","CONTAIN",
    "CONTINUE","CONTROL","CONVERT","COOKING","CORNER","CORRECT","COSTUME","COUNCIL","COUNTER","COUNTRY",
    "COUNTY","COUPLE","COURAGE","COURSE","COURTROOM","CREATIVE","CREATURE","CREDIT","CRITICAL","CRYSTAL",
    "CULTURE","CURRENT","CUSTOM","CUSTOMER","CYLINDER","DAMAGE","DANCER","DANGEROUS","DARLING","DAUGHTER",
    "DEALER","DECADE","DECIDE","DECISION","DECLARE","DECORATE","DEFENSE","DEFICIT","DELICATE","DELIGHT",
    "DELIVER","DEMAND","DEPOSIT","DEPUTY","DESCRIBE","DESERT","DESIGN","DESIRE","DESPITE","DESTROY",
    "DETAIL","DETECT","DEVELOP","DEVICE","DEVOTE","DIAMOND","DICTIONARY","DIFFERENT","DIFFICULT","DIGITAL",
    "DIMENSION","DINNER","DIRECT","DIRECTOR","DIRTY","DISASTER","DISCIPLINE","DISCOVER","DISCUSS","DISEASE",
    "DISPLAY","DISPUTE","DISTANCE","DISTINCT","DISTRICT","DIVERSE","DIVIDE","DOCTOR","DOCUMENT","DOMESTIC",
    "DOMINANT","DOUBLE","DOUBT","DOWNTOWN","DRAGON","DRAMATIC","DRAWER","DRAWING","DREAMER","DRESSING",
    "DRIVER","DYNAMIC","EARTHQUAKE","EASTERN","ECONOMIC","ECONOMY","EDITION","EDITOR","EDUCATION","EFFECTIVE",
    "EFFICIENCY","EFFORT","ELECTION","ELECTRIC","ELEMENT","ELEVATOR","ELIGIBLE","EMERGENCY","EMOTION","EMPHASIS",
    "EMPLOYEE","EMPLOYER","ENABLE","ENCOUNTER","ENCOURAGE","ENERGY","ENGINE","ENGINEER","ENHANCE","ENORMOUS",
    "ENTERPRISE","ENTERTAIN","ENTIRE","ENTITY","ENTRANCE","ENVELOPE","EPISODE","EQUATION","EQUIPMENT","ESPECIALLY",
    "ESSENTIAL","ESTABLISH","ESTATE","ESTIMATE","ETHNIC","EVALUATE","EVENING","EVENTUALLY","EVERYBODY","EVERYONE",
    "EVERYTHING","EVIDENCE","EXACTLY","EXAMINE","EXAMPLE","EXCELLENT","EXCEPT","EXCHANGE","EXCITEMENT","EXECUTIVE",
    "EXERCISE","EXHIBIT","EXISTENCE","EXPAND","EXPENSE","EXPENSIVE","EXPERIENCE","EXPERIMENT","EXPERT","EXPLAIN",
    "EXPLORE","EXPRESS","EXTENSION","EXTENSIVE","EXTREME","FACTORY","FACULTY","FAILURE","FAMILIAR","FANTASY",
    "FARMER","FASCINATING","FASHION","FAVORITE","FEATURE","FEDERAL","FEELING","FESTIVAL","FICTION","FINANCE",
    "FINDING","FINGER","FINISH","FLIGHT","FLOATING","FLOWER","FOCUSED","FOLLOW","FOOTBALL","FOREIGN",
    "FOREVER","FORMULA","FORTUNE","FORWARD","FOUNDATION","FRAGMENT","FRAMEWORK","FREEDOM","FREQUENCY","FRIENDLY",
    "FRIGHTEN","FRONTIER","FUNCTION","FUNDAMENTAL","FUNERAL","FURNITURE","FURTHER","GALLERY","GARBAGE","GARDEN",
    "GATHER","GENERAL","GENERATE","GENEROUS","GENTLEMAN","GENUINE","GESTURE","GLACIER","GLANCE","GLORIOUS",
    "GOVERNMENT","GOVERNOR","GRADUAL","GRADUATE","GRAIN","GRANDFATHER","GRANDMOTHER","GRATITUDE","GRAVITY","GREATEST",
    "GROCERY","GROUND","GROWTH","GUARANTEE","GUARDIAN","GUIDANCE","GUITAR","HABITAT","HALF","HAMMER",
    "HAPPEN","HARBOR","HARMONY","HARVEST","HEADLINE","HEALTHY","HEAVEN","HEIGHT","HELICOPTER","HELPFUL",
    "HERITAGE","HEROIC","HIGHWAY","HISTORIC","HISTORY","HOLIDAY","HORIZON","HORIZONTAL","HOSPITAL","HOSTILE",
    "HOUSEHOLD","HOUSING","HOWEVER","HUMANITY","HUNDRED","HUSBAND","HYPOTHESIS","IDENTITY","IGNORANT","ILLEGAL",
    "ILLNESS","ILLUSTRATE","IMAGINE","IMMEDIATE","IMMIGRANT","IMPACT","IMPLEMENT","IMPORTANCE","IMPORTANT","IMPOSSIBLE",
    "IMPRESS","IMPROVE","INCIDENT","INCLUDE","INCLUDING","INCOME","INCREASE","INCREDIBLE","INDEED","INDEPENDENT",
    "INDEX","INDICATE","INDIVIDUAL","INDUSTRY","INFANT","INFECTION","INFLATION","INFLUENCE","INFORM","INFORMATION",
    "INITIAL","INITIATIVE","INJURY","INNOCENT","INQUIRY","INSIGHT","INSPECT","INSPIRE","INSTALL","INSTANCE",
    "INSTEAD","INSTITUTE","INSTRUCTION","INSTRUMENT","INSURANCE","INTELLECT","INTELLIGENCE","INTENSE","INTERACT","INTEREST",
    "INTERNAL","INTERNATIONAL","INTERNET","INTERPRET","INTERVIEW","INTO","INTRODUCE","INVENT","INVEST","INVESTIGATE",
    "INVESTMENT","INVISIBLE","INVITATION","INVOLVE","ISLAND","ISOLATION","ITEM","JACKET","JOURNAL","JOURNEY",
    "JUDGMENT","JUSTICE","JUSTIFY","KEEPER","KEYBOARD","KINGDOM","KITCHEN","KNOWLEDGE","LABORATORY","LANDSCAPE",
    "LANGUAGE","LANTERN","LARGELY","LATTER","LAUGHTER","LAUNCH","LAWYER","LEADERSHIP","LEAGUE","LEARNING",
    "LEATHER","LECTURE","LEGEND","LEGISLATION","LEGITIMATE","LENGTH","LESSON","LIBERTY","LIBRARY","LICENSE",
    "LIGHTNING","LIMITED","LINGUISTIC","LITERATURE","LITTLE","LIVING","LOCATION","LOGICAL","LONELY","LONGITUDE",
    "LOYALTY","LUGGAGE","LUMBER","MACHINE","MAGAZINE","MAGICIAN","MAGNIFICENT","MAINTAIN","MAJORITY","MANAGEMENT",
    "MANAGER","MANDATE","MANNER","MANUAL","MANUFACTURE","MARATHON","MARGIN","MARKET","MARRIAGE","MATERIAL",
    "MATHEMATICS","MATTER","MAXIMUM","MEANING","MEASURE","MECHANIC","MECHANISM","MEDAL","MEDICAL","MEDICINE",
    "MEDIUM","MEETING","MEMBER","MEMORY","MENTAL","MENTION","MERCHANT","MESSAGE","METAPHOR","METHOD",
    "MILITARY","MILLION","MINERAL","MINIMUM","MINISTER","MINORITY","MINUTE","MIRACLE","MISCHIEF","MISSILE",
    "MISSION","MISTAKE","MIXTURE","MODERN","MOMENT","MONASTERY","MONEY","MONITOR","MONSTER","MONTHLY",
    "MONUMENT","MORNING","MORTGAGE","MOTHER","MOTION","MOTIVATE","MOUNTAIN","MOVEMENT","MULTIPLE","MUNICIPAL",
    "MURDER","MUSEUM","MUSICAL","MUSICIAN","MUTUAL","MYSTERY","NARRATIVE","NATION","NATIONAL","NATIVE",
    "NATURAL","NATURE","NAVIGATE","NECESSARY","NEGATIVE","NEGOTIATE","NEIGHBOR","NEITHER","NERVOUS","NETWORK",
    "NEUTRAL","NEWSPAPER","NIGHTMARE","NOBODY","NORMAL","NORTHERN","NOTHING","NOTICE","NOVELIST","NUCLEAR",
    "NUMBER","NUMEROUS","NUTRIENT","OBVIOUS","OCCASION","OCCUPY","OCCURRENCE","OFFENSE","OFFICER","OFFICIAL",
    "ONGOING","OPERATE","OPERATION","OPERATOR","OPINION","OPPONENT","OPPORTUNITY","OPPOSITE","OPTION","ORANGE",
    "ORCHESTRA","ORDINARY","ORGANIC","ORGANIZE","ORIGIN","ORIGINAL","OUTCOME","OUTDOOR","OUTLINE","OUTLOOK",
    "OUTPUT","OUTSIDE","OVERALL","OVERCOME","OVERLOOK","OVERSEAS","PACIFIC","PACKAGE","PALACE","PANEL",
    "PARADE","PARALLEL","PARAMETER","PARENT","PARKING","PARLIAMENT","PARTIAL","PARTICIPATE","PARTICLE","PARTICULAR",
    "PARTNER","PASSAGE","PASSENGER","PASSION","PATHWAY","PATIENCE","PATIENT","PATROL","PATTERN","PAYMENT",
    "PEACEFUL","PENALTY","PENSION","PERCENT","PERFECT","PERFORM","PERFORMANCE","PERIOD","PERMANENT","PERMISSION",
    "PERSONAL","PERSONNEL","PERSPECTIVE","PHARMACY","PHENOMENON","PHILOSOPHY","PHOENIX","PHOTOGRAPH","PHYSICAL","PHYSICIAN",
    "PICTURE","PIONEER","PIPELINE","PLANET","PLASTIC","PLATFORM","PLEASURE","PLENTY","POETRY","POINT",
    "POLICE","POLICY","POLITICAL","POLITICS","POPULAR","POPULATION","PORTRAIT","POSITION","POSITIVE","POSSESS",
    "POSSIBLE","POSTER","POTENTIAL","POWDER","POWERFUL","PRACTICAL","PRACTICE","PRECIOUS","PRECISE","PREDICT",
    "PREFER","PREGNANT","PREMISE","PREMIUM","PREPARE","PRESENCE","PRESENT","PRESERVE","PRESIDENT","PRESSURE",
    "PREVENT","PREVIOUS","PRIMARY","PRIMITIVE","PRINCIPAL","PRINCIPLE","PRISON","PRIVATE","PROBABLE","PROBLEM",
    "PROCEDURE","PROCEED","PROCESS","PRODUCE","PRODUCT","PRODUCTION","PROFESSION","PROFESSOR","PROFILE","PROFIT",
    "PROGRAM","PROGRESS","PROJECT","PROMISE","PROMOTE","PROMPT","PRONOUNCE","PROPERTY","PROPOSAL","PROSPECT",
    "PROTECT","PROTEIN","PROTEST","PROTOCOL","PROUD","PROVIDE","PROVINCE","PSYCHOLOGY","PUBLIC","PUBLISH",
    "PURCHASE","PURPOSE","PURSUIT","PYRAMID","QUALIFY","QUALITY","QUANTITY","QUARTER","QUESTION","QUICKLY",
    "RADICAL","RADIO","RAILROAD","RAINBOW","RANDOM","RAPIDLY","REACTION","READER","READILY","REALITY",
    "REALIZE","REASON","REASONABLE","RECEIVE","RECENT","RECEPTION","RECIPE","RECOGNIZE","RECOMMEND","RECORD",
    "RECOVER","RECRUIT","REDUCE","REDUCTION","REFERENCE","REFLECT","REFORM","REFUGEE","REFUSAL","REGARD",
    "REGIME","REGION","REGIONAL","REGISTER","REGULAR","REGULATION","REINFORCE","RELATION","RELATIONSHIP","RELATIVE",
    "RELAX","RELEASE","RELEVANT","RELIABLE","RELIEF","RELIGION","RELUCTANT","REMAIN","REMARKABLE","REMEMBER",
    "REMIND","REMOTE","REMOVAL","REPEAT","REPLACE","REPLY","REPORT","REPRESENT","REPUBLIC","REPUTATION",
    "REQUEST","REQUIRE","RESEARCH","RESERVE","RESIDENCE","RESIDENT","RESIGN","RESIST","RESOLUTION","RESOLVE",
    "RESORT","RESOURCE","RESPECT","RESPOND","RESPONSE","RESPONSIBLE","RESTAURANT","RESTORE","RESTRICT","RESULT",
    "RETAIL","RETAIN","RETIRE","RETURN","REVEAL","REVENUE","REVERSE","REVIEW","REVOLUTION","REWARD",
    "RHYTHM","RIBBON","ROBUST","ROCKET","ROMANCE","ROUTINE","ROYALTY","RUBBER","SAFETY","SALARY",
    "SAMPLE","SANCTION","SANDWICH","SATELLITE","SATISFY","SAVING","SCANDAL","SCENARIO","SCHEDULE","SCHEME",
    "SCHOLAR","SCIENCE","SCIENTIFIC","SCIENTIST","SCRATCH","SCREEN","SCULPTURE","SEARCH","SEASON","SECONDARY",
    "SECRET","SECRETARY","SECTION","SECTOR","SECURE","SECURITY","SEGMENT","SELECT","SELECTION","SENATOR",
    "SENIOR","SENSATION","SENTENCE","SEPARATE","SEQUENCE","SERIES","SERIOUS","SERVICE","SESSION","SETTING",
    "SETTLEMENT","SEVERAL","SHADOW","SHAKE","SHIELD","SHOULDER","SICKNESS","SIGNAL","SIGNIFICANT","SILENCE",
    "SILVER","SIMILAR","SIMPLE","SINCERE","SITUATION","SKELETON","SKILLFUL","SLIGHT","SLOGAN","SMOOTH",
    "SOCIAL","SOCIETY","SOLDIER","SOLUTION","SOMEBODY","SOMEHOW","SOMEONE","SOMETHING","SOMETIME","SOMEWHERE",
    "SOPHISTICATED","SOUTHERN","SPECIAL","SPECIFIC","SPECTRUM","SPHERE","SPIRIT","SPLENDID","SPONSOR","STANDARD",
    "STATION","STATUE","STATUS","STATUTE","STEADY","STOMACH","STORAGE","STRATEGY","STRENGTH","STRETCH",
    "STRICT","STRIKE","STRUCTURE","STRUGGLE","STUDENT","STUDIO","SUBJECT","SUBMIT","SUBSTANCE","SUBSTANTIAL",
    "SUCCEED","SUCCESS","SUCCESSFUL","SUDDEN","SUFFER","SUFFICIENT","SUGGEST","SUICIDE","SUITABLE","SUMMARY",
    "SUMMER","SUMMIT","SUNLIGHT","SUPERIOR","SUPPLY","SUPPORT","SUPPOSE","SUPREME","SURFACE","SURGEON",
    "SURGERY","SURPRISE","SURRENDER","SURROUND","SURVEY","SURVIVAL","SURVIVE","SUSPECT","SUSTAIN","SWIMMING",
    "SYMBOL","SYMPATHY","SYMPTOM","SYNDICATE","SYNDROME","SYSTEM","TACTICAL","TALENT","TARGET","TEACHER",
    "TECHNICAL","TECHNIQUE","TECHNOLOGY","TEENAGER","TELEPHONE","TELESCOPE","TELEVISION","TEMPER","TEMPERATURE","TEMPORARY",
    "TENDENCY","TENSION","TERMINAL","TERRITORY","TESTIMONY","THEATER","THERAPY","THINKING","THOROUGH","THOUSAND",
    "THREAT","THREATEN","THROUGH","THROUGHOUT","TIMBER","TOBACCO","TOGETHER","TOLERANCE","TOMORROW","TONIGHT",
    "TOURIST","TOURNAMENT","TOWARDS","TRAFFIC","TRAGEDY","TRAINING","TRANSFER","TRANSFORM","TRANSITION","TRANSLATE",
    "TRANSPORT","TRAVEL","TREASURE","TREATMENT","TREMENDOUS","TRIBUNAL","TRIANGLE","TRIGGER","TRIUMPH","TROUBLE",
    "TRUSTEE","TSUNAMI","TUESDAY","TURBINE","TWILIGHT","TWENTY","TYPICAL","ULTIMATE","UMBRELLA","UNABLE",
    "UNCERTAIN","UNDERGO","UNDERSTAND","UNDERTAKE","UNIFORM","UNIQUE","UNITED","UNIVERSAL","UNIVERSE","UNIVERSITY",
    "UNKNOWN","UNLESS","UNLIKELY","UNUSUAL","UPCOMING","UPRIGHT","URANIUM","URGENCY","UTILITY","VACATION",
    "VACCINE","VACUUM","VALLEY","VALUABLE","VARIABLE","VARIETY","VARIOUS","VEHICLE","VENTURE","VERSION",
    "VERTICAL","VICTIM","VICTORY","VILLAGE","VIOLENCE","VIRTUAL","VISIBLE","VISION","VISITOR","VISUAL",
    "VITALITY","VOLCANO","VOLUNTEER","VOYAGE","VULNERABLE","WARFARE","WARNING","WARRANT","WARRIOR","WEATHER",
    "WEBSITE","WEEKEND","WELCOME","WELFARE","WESTERN","WHATEVER","WHEREVER","WHETHER","WHISPER","WHOEVER",
    "WINDOW","WINNER","WINTER","WISDOM","WITHDRAW","WITHOUT","WITNESS","WONDERFUL","WOODEN","WORKER",
    "WORKFORCE","WORKSHOP","WRITER","WRITING","YELLOW","YESTERDAY","YIELDING","ZEALOUS","ZENITH","ZODIAC"
}

local function addWord(w)
    local n = #w
    if not DB[n] then
        DB[n] = {}
        local inserted = false
        for idx, len in ipairs(LENS) do
            if len < n then
                table.insert(LENS, idx, n)
                inserted = true
                break
            end
        end
        if not inserted then table.insert(LENS, n) end
    end
    table.insert(DB[n], w)
end

local function indexWordlist(raw)
    DB = {}; LENS = {}; TOTAL = 0
    local count = 0
    for line in raw:gmatch("[^\r\n]+") do
        local w = line:match("^%s*(.-)%s*$"):upper()
        if #w >= 2 and w:match("^%a+$") then
            addWord(w)
            TOTAL = TOTAL + 1
            count = count + 1
            if count % 25000 == 0 then task.wait() end
        end
    end
    READY = true
end

-- Preload embedded words immediately
for _, w in ipairs(STARTER_WORDS) do addWord(w); TOTAL = TOTAL + 1 end
READY = true

local function findWord(minL, maxL, pattern)
    if not READY or TOTAL == 0 then return nil end
    local pat = pattern and pattern:upper():match("^%s*(.-)%s*$")
    if pat and #pat == 0 then pat = nil end

    -- Iterate lengths according to mode preference
    for _, len in ipairs(LENS) do
        if len >= minL and len <= maxL then
            local bucket = DB[len]
            if bucket and #bucket > 0 then
                if not pat then
                    return bucket[math.random(1, #bucket)]
                end
                -- Pattern match
                local matches = {}
                for _, w in ipairs(bucket) do
                    if w:find(pat, 1, true) then
                        table.insert(matches, w)
                    end
                end
                if #matches > 0 then
                    return matches[math.random(1, #matches)]
                end
            end
        end
    end
    return nil
end

-- ─── GUI Construction Helpers ────────────────────────────────────────
local function new(className, properties, parent)
    local obj = Instance.new(className)
    for k, v in pairs(properties or {}) do
        obj[k] = v
    end
    if parent then obj.Parent = parent end
    return obj
end

local function tween(obj, props, duration)
    TweenService:Create(obj, TweenInfo.new(duration or 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function applyCorner(radius, parent)
    return new("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function applyStroke(color, thickness, parent)
    return new("UIStroke", {
        Color = color,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function applyPadding(horiz, vert, parent)
    return new("UIPadding", {
        PaddingLeft   = UDim.new(0, horiz),
        PaddingRight  = UDim.new(0, horiz),
        PaddingTop    = UDim.new(0, vert or horiz),
        PaddingBottom = UDim.new(0, vert or horiz),
    }, parent)
end

-- ─── Build ScreenGui & Window ─────────────────────────────────────────
local sg = new("ScreenGui", {
    Name           = "WordBombAutoTyper",
    ResetOnSpawn   = false,
    DisplayOrder   = 999999,
    IgnoreGuiInset = true,
    Parent         = guiParent,
})

-- Main Window (290px x 430px solid dimensions to prevent collapse)
local win = new("Frame", {
    Name             = "MainWindow",
    Size             = UDim2.new(0, 290, 0, 430),
    Position         = UDim2.new(1, -315, 0, 70),
    BackgroundColor3 = Theme.bg,
    BorderSizePixel  = 0,
    Active           = true,
    ClipsDescendants = true,
    Parent           = sg,
})
applyCorner(12, win)
local winStroke = applyStroke(Theme.cardBorder, 1.5, win)

-- ─ Header Bar (Draggable)
local header = new("Frame", {
    Name             = "Header",
    Size             = UDim2.new(1, 0, 0, 46),
    BackgroundColor3 = Theme.header,
    BorderSizePixel  = 0,
    Parent           = win,
})
applyCorner(12, header)
-- Mask bottom corners of header
new("Frame", {
    Size             = UDim2.new(1, 0, 0, 12),
    Position         = UDim2.new(0, 0, 1, -12),
    BackgroundColor3 = Theme.header,
    BorderSizePixel  = 0,
    Parent           = header,
})
new("Frame", {
    Size             = UDim2.new(1, 0, 0, 1),
    Position         = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = Theme.cardBorder,
    BorderSizePixel  = 0,
    Parent           = header,
})
applyPadding(14, 0, header)

-- Status glowing dot in header
local statusDot = new("Frame", {
    Size             = UDim2.new(0, 10, 0, 10),
    Position         = UDim2.new(0, 0, 0.5, -5),
    BackgroundColor3 = Theme.success,
    BorderSizePixel  = 0,
    Parent           = header,
})
applyCorner(5, statusDot)

-- Title
new("TextLabel", {
    Size                   = UDim2.new(1, -95, 1, 0),
    Position               = UDim2.new(0, 18, 0, 0),
    BackgroundTransparency = 1,
    Text                   = "WORD BOMB AUTO-TYPER",
    TextColor3             = Theme.text,
    Font                   = Enum.Font.GothamBold,
    TextSize               = 12,
    TextXAlignment         = Enum.TextXAlignment.Left,
    Parent                 = header,
})

-- Header Buttons (Minimize and Close)
local minBtn = new("TextButton", {
    Size             = UDim2.new(0, 24, 0, 24),
    Position         = UDim2.new(1, -54, 0.5, -12),
    BackgroundColor3 = Theme.surface,
    Text             = "−",
    TextColor3       = Theme.textSub,
    Font             = Enum.Font.GothamBold,
    TextSize         = 15,
    AutoButtonColor  = false,
    Parent           = header,
})
applyCorner(6, minBtn)

local closeBtn = new("TextButton", {
    Size             = UDim2.new(0, 24, 0, 24),
    Position         = UDim2.new(1, -26, 0.5, -12),
    BackgroundColor3 = Theme.surface,
    Text             = "×",
    TextColor3       = Theme.textSub,
    Font             = Enum.Font.GothamBold,
    TextSize         = 16,
    AutoButtonColor  = false,
    Parent           = header,
})
applyCorner(6, closeBtn)

for _, b in ipairs({minBtn, closeBtn}) do
    b.MouseEnter:Connect(function() tween(b, { BackgroundColor3 = Theme.surfaceHov, TextColor3 = Theme.text }) end)
    b.MouseLeave:Connect(function() tween(b, { BackgroundColor3 = Theme.surface, TextColor3 = Theme.textSub }) end)
end

-- ─ Content Container
local content = new("Frame", {
    Name                   = "Content",
    Size                   = UDim2.new(1, 0, 1, -46),
    Position               = UDim2.new(0, 0, 0, 46),
    BackgroundTransparency = 1,
    Parent                 = win,
})
applyPadding(12, 10, content)

local contentLayout = new("UIListLayout", {
    SortOrder            = Enum.SortOrder.LayoutOrder,
    FillDirection        = Enum.FillDirection.Vertical,
    Padding              = UDim.new(0, 8),
    HorizontalAlignment  = Enum.HorizontalAlignment.Center,
    Parent               = content,
})

-- ─ Live Status Card
local statusCard = new("Frame", {
    Size             = UDim2.new(1, 0, 0, 48),
    BackgroundColor3 = Theme.card,
    BorderSizePixel  = 0,
    LayoutOrder      = 1,
    Parent           = content,
})
applyCorner(8, statusCard)
applyStroke(Theme.cardBorder, 1, statusCard)
applyPadding(12, 6, statusCard)

local statusTitle = new("TextLabel", {
    Size                   = UDim2.new(0.6, 0, 0, 16),
    Position               = UDim2.new(0, 0, 0, 2),
    BackgroundTransparency = 1,
    Text                   = "READY",
    TextColor3             = Theme.success,
    Font                   = Enum.Font.GothamBold,
    TextSize               = 12,
    TextXAlignment         = Enum.TextXAlignment.Left,
    Parent                 = statusCard,
})

local promptBadge = new("TextLabel", {
    Size                   = UDim2.new(0.4, 0, 0, 16),
    Position               = UDim2.new(0.6, 0, 0, 2),
    BackgroundTransparency = 1,
    Text                   = "Prompt: --",
    TextColor3             = Theme.accent,
    Font                   = Enum.Font.GothamBold,
    TextSize               = 11,
    TextXAlignment         = Enum.TextXAlignment.Right,
    Parent                 = statusCard,
})

local wordCountLabel = new("TextLabel", {
    Size                   = UDim2.new(1, 0, 0, 14),
    Position               = UDim2.new(0, 0, 1, -14),
    BackgroundTransparency = 1,
    Text                   = TOTAL .. " words indexed",
    TextColor3             = Theme.textMuted,
    Font                   = Enum.Font.GothamMedium,
    TextSize               = 10,
    TextXAlignment         = Enum.TextXAlignment.Left,
    Parent                 = statusCard,
})

-- ─ Helper: Section Label
local function makeSectionLabel(text, order)
    local lbl = new("TextLabel", {
        Size                   = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        Text                   = text:upper(),
        TextColor3             = Theme.textSub,
        Font                   = Enum.Font.GothamBold,
        TextSize               = 10,
        TextXAlignment         = Enum.TextXAlignment.Left,
        LayoutOrder            = order,
        Parent                 = content,
    })
    return lbl
end

-- ─ Mode Selector Pills (1-click, no buggy dropdown menus)
makeSectionLabel("Word Length Mode", 2)

local modeRow = new("Frame", {
    Size                   = UDim2.new(1, 0, 0, 28),
    BackgroundTransparency = 1,
    LayoutOrder            = 3,
    Parent                 = content,
})
local modeLayout = new("UIListLayout", {
    FillDirection        = Enum.FillDirection.Horizontal,
    Padding              = UDim.new(0, 4),
    VerticalAlignment    = Enum.VerticalAlignment.Center,
    Parent               = modeRow,
})

local modePills = {}
local MODES = { "SHORT", "MEDIUM", "LONG", "SUPER", "ANY" }
local MODE_NAMES = { SHORT="Short", MEDIUM="Med", LONG="Long", SUPER="Super", ANY="Any" }

local function updateModePills()
    for m, pill in pairs(modePills) do
        local active = (Config.mode == m)
        tween(pill, {
            BackgroundColor3 = active and Theme.accent or Theme.surface,
            TextColor3       = active and Theme.text or Theme.textSub,
        })
    end
end

for _, m in ipairs(MODES) do
    local pill = new("TextButton", {
        Size             = UDim2.new(0.2, -4, 1, 0),
        BackgroundColor3 = (Config.mode == m) and Theme.accent or Theme.surface,
        Text             = MODE_NAMES[m],
        TextColor3       = (Config.mode == m) and Theme.text or Theme.textSub,
        Font             = Enum.Font.GothamBold,
        TextSize         = 11,
        AutoButtonColor  = false,
        Parent           = modeRow,
    })
    applyCorner(6, pill)
    pill.MouseButton1Click:Connect(function()
        Config.mode = m
        updateModePills()
    end)
    modePills[m] = pill
end

-- ─ Typing Speed Pills
makeSectionLabel("Typing Speed", 4)

local speedRow = new("Frame", {
    Size                   = UDim2.new(1, 0, 0, 28),
    BackgroundTransparency = 1,
    LayoutOrder            = 5,
    Parent                 = content,
})
local speedLayout = new("UIListLayout", {
    FillDirection        = Enum.FillDirection.Horizontal,
    Padding              = UDim.new(0, 4),
    VerticalAlignment    = Enum.VerticalAlignment.Center,
    Parent               = speedRow,
})

local speedPills = {}
local SPEEDS = { "INSTANT", "FAST", "NORMAL", "SLOW", "HUMAN" }
local SPEED_NAMES = { INSTANT="Instant", FAST="Fast", NORMAL="Norm", SLOW="Slow", HUMAN="Human" }

local function updateSpeedPills()
    for s, pill in pairs(speedPills) do
        local active = (Config.speed == s)
        tween(pill, {
            BackgroundColor3 = active and Theme.accent or Theme.surface,
            TextColor3       = active and Theme.text or Theme.textSub,
        })
    end
end

for _, s in ipairs(SPEEDS) do
    local pill = new("TextButton", {
        Size             = UDim2.new(0.2, -4, 1, 0),
        BackgroundColor3 = (Config.speed == s) and Theme.accent or Theme.surface,
        Text             = SPEED_NAMES[s],
        TextColor3       = (Config.speed == s) and Theme.text or Theme.textSub,
        Font             = Enum.Font.GothamBold,
        TextSize         = 11,
        AutoButtonColor  = false,
        Parent           = speedRow,
    })
    applyCorner(6, pill)
    pill.MouseButton1Click:Connect(function()
        Config.speed = s
        updateSpeedPills()
    end)
    speedPills[s] = pill
end

-- ─ Feature Toggles
makeSectionLabel("Options", 6)

local function makeToggle(title, defaultVal, order, onToggle)
    local row = new("Frame", {
        Size                   = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1,
        LayoutOrder            = order,
        Parent                 = content,
    })
    new("TextLabel", {
        Size                   = UDim2.new(0.7, 0, 1, 0),
        BackgroundTransparency = 1,
        Text                   = title,
        TextColor3             = Theme.text,
        Font                   = Enum.Font.GothamMedium,
        TextSize               = 11,
        TextXAlignment         = Enum.TextXAlignment.Left,
        Parent                 = row,
    })
    local toggleBtn = new("TextButton", {
        Size             = UDim2.new(0, 42, 0, 20),
        Position         = UDim2.new(1, -42, 0.5, -10),
        BackgroundColor3 = defaultVal and Theme.accent or Theme.surface,
        Text             = "",
        AutoButtonColor  = false,
        Parent           = row,
    })
    applyCorner(10, toggleBtn)
    local knob = new("Frame", {
        Size             = UDim2.new(0, 16, 0, 16),
        Position         = defaultVal and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
        BackgroundColor3 = Theme.text,
        BorderSizePixel  = 0,
        Parent           = toggleBtn,
    })
    applyCorner(8, knob)

    local state = defaultVal
    toggleBtn.MouseButton1Click:Connect(function()
        state = not state
        tween(toggleBtn, { BackgroundColor3 = state and Theme.accent or Theme.surface })
        tween(knob, { Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8) })
        if onToggle then onToggle(state) end
    end)
    return row
end

makeToggle("Auto-Submit (Enter)", Config.autoSubmit, 7, function(val) Config.autoSubmit = val end)
makeToggle("Smart Prompt Filter", Config.smartFilter, 8, function(val) Config.smartFilter = val end)

-- ─ Primary Start / Stop Button
local startBtn = new("TextButton", {
    Size             = UDim2.new(1, 0, 0, 36),
    BackgroundColor3 = Theme.accent,
    Text             = "▶   START AUTO-TYPER",
    TextColor3       = Theme.text,
    Font             = Enum.Font.GothamBold,
    TextSize         = 13,
    AutoButtonColor  = false,
    LayoutOrder      = 9,
    Parent           = content,
})
applyCorner(8, startBtn)

-- ─ Secondary Action Row: Test Word & Emergency Stop
local actionRow = new("Frame", {
    Size                   = UDim2.new(1, 0, 0, 30),
    BackgroundTransparency = 1,
    LayoutOrder            = 10,
    Parent                 = content,
})
local actionLayout = new("UIListLayout", {
    FillDirection        = Enum.FillDirection.Horizontal,
    Padding              = UDim.new(0, 6),
    VerticalAlignment    = Enum.VerticalAlignment.Center,
    Parent               = actionRow,
})

local testWordBtn = new("TextButton", {
    Size             = UDim2.new(0.5, -3, 1, 0),
    BackgroundColor3 = Theme.surface,
    Text             = "⚡ Test Word",
    TextColor3       = Theme.text,
    Font             = Enum.Font.GothamMedium,
    TextSize         = 11,
    AutoButtonColor  = false,
    Parent           = actionRow,
})
applyCorner(6, testWordBtn)

local stopBtn = new("TextButton", {
    Size             = UDim2.new(0.5, -3, 1, 0),
    BackgroundColor3 = Theme.surface,
    Text             = "⏹ Stop (F8)",
    TextColor3       = Theme.danger,
    Font             = Enum.Font.GothamMedium,
    TextSize         = 11,
    AutoButtonColor  = false,
    Parent           = actionRow,
})
applyCorner(6, stopBtn)

for _, b in ipairs({testWordBtn, stopBtn}) do
    b.MouseEnter:Connect(function() tween(b, { BackgroundColor3 = Theme.surfaceHov }) end)
    b.MouseLeave:Connect(function() tween(b, { BackgroundColor3 = Theme.surface }) end)
end

-- ─── UI State Updating ────────────────────────────────────────────────
local isPulsing = false
local function setUIStatus(state, extraText)
    if state == "TYPING" then
        statusTitle.Text = "TYPING..."
        statusTitle.TextColor3 = Theme.accent
        statusDot.BackgroundColor3 = Theme.accent
        if not isPulsing then
            isPulsing = true
            task.spawn(function()
                while isPulsing do
                    tween(statusDot, { BackgroundTransparency = 0.7 }, 0.3)
                    task.wait(0.3)
                    tween(statusDot, { BackgroundTransparency = 0 }, 0.3)
                    task.wait(0.3)
                end
                statusDot.BackgroundTransparency = 0
            end)
        end
    elseif state == "SEARCHING" then
        isPulsing = false
        statusTitle.Text = "WAITING FOR TURN"
        statusTitle.TextColor3 = Theme.warning
        statusDot.BackgroundColor3 = Theme.warning
        statusDot.BackgroundTransparency = 0
    elseif state == "STOPPED" then
        isPulsing = false
        statusTitle.Text = "STOPPED"
        statusTitle.TextColor3 = Theme.danger
        statusDot.BackgroundColor3 = Theme.danger
        statusDot.BackgroundTransparency = 0
    else -- READY / IDLE
        isPulsing = false
        statusTitle.Text = extraText or "READY"
        statusTitle.TextColor3 = Theme.success
        statusDot.BackgroundColor3 = Theme.success
        statusDot.BackgroundTransparency = 0
    end
end

-- ─── Window Dragging & Viewport Clamping ───────────────────────────────
local dragging, dragStart, startPos = false, Vector2.new(), Vector2.new()

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = Vector2.new(win.Position.X.Offset, win.Position.Y.Offset)
        -- Also handle scale positions by converting to offset
        if win.Position.X.Scale ~= 0 or win.Position.Y.Scale ~= 0 then
            local cam = workspace.CurrentCamera
            local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
            local ox = win.Position.X.Scale * vp.X + win.Position.X.Offset
            local oy = win.Position.Y.Scale * vp.Y + win.Position.Y.Offset
            win.Position = UDim2.new(0, ox, 0, oy)
            startPos = Vector2.new(ox, oy)
        end
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
        local newX = math.clamp(startPos.X + delta.X, 0, math.max(0, vp.X - win.AbsoluteSize.X))
        local newY = math.clamp(startPos.Y + delta.Y, 0, math.max(0, vp.Y - win.AbsoluteSize.Y))
        win.Position = UDim2.new(0, newX, 0, newY)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- Minimize & Close wiring
local isMinimized = false
minBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    content.Visible = not isMinimized
    minBtn.Text = isMinimized and "+" or "−"
    tween(win, { Size = isMinimized and UDim2.new(0, 290, 0, 46) or UDim2.new(0, 290, 0, 430) }, 0.2)
end)

closeBtn.MouseButton1Click:Connect(function()
    sg.Enabled = false
    print("[WordBomb] UI hidden. Press F6 to reopen.")
end)

-- Hotkeys (F6 = Toggle, F8 = Emergency Stop)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F6 then
        sg.Enabled = not sg.Enabled
    elseif input.KeyCode == Enum.KeyCode.F8 then
        Config.running = false
        startBtn.Text = "▶   START AUTO-TYPER"
        startBtn.BackgroundColor3 = Theme.accent
        setUIStatus("STOPPED")
        print("[WordBomb] Emergency Kill-Switch Activated (F8).")
    end
end)

-- ─── Game UI Detection Logic ──────────────────────────────────────────
local function isVisibleOnScreen(obj)
    if not obj or not obj:IsA("GuiObject") then return false end
    if not obj.Visible then return false end
    if obj.AbsoluteSize.X <= 2 or obj.AbsoluteSize.Y <= 2 then return false end
    local cur = obj.Parent
    while cur and cur:IsA("GuiObject") do
        if not cur.Visible then return false end
        cur = cur.Parent
    end
    if cur and cur:IsA("ScreenGui") and not cur.Enabled then return false end
    return true
end

local function isChatElement(obj)
    local cur = obj
    while cur do
        local name = cur.Name:lower()
        if name:find("chat") then return true end
        cur = cur.Parent
    end
    if obj:IsA("TextBox") then
        local ph = obj.PlaceholderText:lower()
        if ph:find("to chat") or ph:find("tap here to chat") or ph:find("press / to chat") then
            return true
        end
    end
    return false
end

local function findWordBombInputBox()
    local pg = lp and (lp:FindFirstChildOfClass("PlayerGui") or lp:FindFirstChild("PlayerGui"))
    if not pg then return nil end

    for _, desc in ipairs(pg:GetDescendants()) do
        if desc:IsA("TextBox") and not desc:IsDescendantOf(sg) and not isChatElement(desc) then
            if isVisibleOnScreen(desc) then
                return desc
            end
        end
    end
    return nil
end

local PROMPT_BLACKLIST = {
    PLAY=true, SHOP=true, EXIT=true, STOP=true, CHAT=true, PASS=true, FREE=true,
    COIN=true, VOTE=true, NEXT=true, MENU=true, HELP=true, MORE=true, LOAD=true,
    BACK=true, MUTE=true, TEAM=true, RANK=true, BOMB=true, TIME=true, WORD=true,
    TYPE=true, FAST=true, SLOW=true, TINY=true, LONG=true, READY=true, WAIT=true,
}

local function findCurrentPrompt()
    local pg = lp and (lp:FindFirstChildOfClass("PlayerGui") or lp:FindFirstChild("PlayerGui"))
    if not pg then return nil end

    -- 1. Scan PlayerGui labels (highest priority)
    local candidates = {}
    for _, desc in ipairs(pg:GetDescendants()) do
        if desc:IsA("TextLabel") and not desc:IsDescendantOf(sg) and not isChatElement(desc) then
            if isVisibleOnScreen(desc) then
                local text = desc.Text:upper():match("^%s*([A-Z]+)%s*$")
                if text and #text >= 2 and #text <= 4 and not PROMPT_BLACKLIST[text] then
                    local nameScore = 0
                    local nm = desc.Name:lower()
                    if nm:find("prompt") or nm:find("letter") or nm:find("syllable") or nm:find("word") or nm:find("target") then
                        nameScore = nameScore + 50
                    end
                    table.insert(candidates, { text = text, score = nameScore })
                end
            end
        end
    end

    -- 2. Scan workspace for BillboardGuis on the bomb
    if #candidates == 0 then
        for _, desc in ipairs(workspace:GetDescendants()) do
            if desc:IsA("TextLabel") and isVisibleOnScreen(desc) then
                local text = desc.Text:upper():match("^%s*([A-Z]+)%s*$")
                if text and #text >= 2 and #text <= 4 and not PROMPT_BLACKLIST[text] then
                    table.insert(candidates, { text = text, score = 10 })
                end
            end
        end
    end

    if #candidates > 0 then
        table.sort(candidates, function(a, b) return a.score > b.score end)
        return candidates[1].text
    end
    return nil
end

-- ─── Typing & Submission Simulation ───────────────────────────────────
local isTypingNow = false

local function submitWord(box)
    -- Method 1: ReleaseFocus with enterPressed = true (Standard Roblox TextBox submission)
    pcall(function() box:ReleaseFocus(true) end)
    task.wait(0.04)
    -- Method 2: VirtualInputManager KeyEvents for Enter/Return
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        task.wait(0.02)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
    end)
end

local function typeWordIntoBox(word, box)
    if isTypingNow or not box then return end
    isTypingNow = true
    setUIStatus("TYPING")

    -- Focus the target TextBox
    pcall(function() box:CaptureFocus() end)
    task.wait(0.06)

    local spd = Config.speed

    if spd == "INSTANT" then
        box.Text = word
    else
        box.Text = ""
        local delay = DELAYS[spd] or 0.08
        for i = 1, #word do
            if not Config.running and spd ~= "TEST" then break end
            box.Text = word:sub(1, i)
            local waitTime
            if spd == "HUMAN" then
                waitTime = 0.05 + math.random() * 0.14
                if math.random() < 0.08 then waitTime = waitTime + 0.1 end
            else
                waitTime = delay * (0.85 + math.random() * 0.3)
            end
            task.wait(waitTime)
        end
    end

    if Config.autoSubmit then
        task.wait(0.06)
        submitWord(box)
    end

    task.wait(0.12)
    isTypingNow = false
    setUIStatus(Config.running and "SEARCHING" or "READY")
end

-- ─── Background Auto-Typer Loop ───────────────────────────────────────
local lastCompletedPrompt = ""
local lastBoxState = false

task.spawn(function()
    while true do
        task.wait(0.20)
        if Config.running then
            local box = findWordBombInputBox()
            local prompt = findCurrentPrompt()

            if prompt then
                promptBadge.Text = "Prompt: " .. prompt
            else
                promptBadge.Text = "Prompt: --"
            end

            local boxVisible = (box ~= nil and isVisibleOnScreen(box))

            if boxVisible and not isTypingNow then
                -- Check if it's a fresh turn: prompt changed or box was just presented
                local isFreshRound = (prompt and prompt ~= lastCompletedPrompt) or (not lastBoxState)

                if isFreshRound then
                    setUIStatus("SEARCHING")
                    task.wait(Config.startDelay)
                    if Config.running and isVisibleOnScreen(box) then
                        local minL, maxL = getRange()
                        local searchPat = Config.smartFilter and prompt or nil
                        local word = findWord(minL, maxL, searchPat)

                        -- Fallback to other lengths if no word found
                        if not word and Config.fallback then
                            for _, fallbackMode in ipairs({ "LONG", "MEDIUM", "SHORT", "ANY" }) do
                                local r = RANGES[fallbackMode]
                                word = findWord(r.min, r.max, searchPat)
                                if word then break end
                            end
                        end

                        if word then
                            print(("[WordBomb] Selected: %s (Prompt: %s)"):format(word, tostring(prompt)))
                            if prompt then lastCompletedPrompt = prompt end
                            typeWordIntoBox(word, box)
                        else
                            warn("[WordBomb] No matching word found for prompt: " .. tostring(prompt))
                        end
                    end
                end
            elseif not boxVisible then
                lastCompletedPrompt = ""
            end
            lastBoxState = boxVisible
        end
    end
end)

-- ─── Button Wiring ────────────────────────────────────────────────────
startBtn.MouseButton1Click:Connect(function()
    Config.running = not Config.running
    if Config.running then
        startBtn.Text = "■   STOP AUTO-TYPER"
        startBtn.BackgroundColor3 = Theme.danger
        setUIStatus("SEARCHING")
        print("[WordBomb] Auto-typer started.")
    else
        startBtn.Text = "▶   START AUTO-TYPER"
        startBtn.BackgroundColor3 = Theme.accent
        setUIStatus("READY")
        print("[WordBomb] Auto-typer stopped.")
    end
end)

stopBtn.MouseButton1Click:Connect(function()
    Config.running = false
    startBtn.Text = "▶   START AUTO-TYPER"
    startBtn.BackgroundColor3 = Theme.accent
    setUIStatus("STOPPED")
end)

testWordBtn.MouseButton1Click:Connect(function()
    local box = findWordBombInputBox()
    local prompt = findCurrentPrompt()
    local minL, maxL = getRange()
    local word = findWord(minL, maxL, Config.smartFilter and prompt or nil) or "TESTING"

    if box then
        print("[WordBomb] Testing word into detected TextBox: " .. word)
        task.spawn(typeWordIntoBox, word, box)
    else
        warn("[WordBomb] Test: No active Word Bomb TextBox visible on screen!")
        statusTitle.Text = "NO TEXTBOX FOUND"
        statusTitle.TextColor3 = Theme.warning
        task.delay(2.5, function()
            setUIStatus(Config.running and "SEARCHING" or "READY")
        end)
    end
end)

-- ─── Background Full Wordlist Download ────────────────────────────────
task.spawn(function()
    -- 1. Try executor local file
    local ok, localData = pcall(function()
        if readfile then return readfile("wordlist-286594-words.txt") end
    end)
    if ok and localData and #localData > 500 then
        print("[WordBomb] Loading wordlist from local executor file...")
        indexWordlist(localData)
        wordCountLabel.Text = TOTAL .. " words indexed (local)"
        return
    end

    -- 2. Try HTTP download via game:HttpGet, request, or syn.request
    print("[WordBomb] Downloading full wordlist (~3 MB)...")
    local httpSuccess, responseData = pcall(function()
        if game and game.HttpGet then
            return game:HttpGet(WURL, true)
        end
        local req = request or (http and http.request) or (syn and syn.request)
        if req then
            local res = req({ Url = WURL, Method = "GET" })
            return res and res.Body
        end
    end)

    if httpSuccess and responseData and #responseData > 500 then
        print("[WordBomb] Wordlist downloaded! Indexing...")
        indexWordlist(responseData)
        wordCountLabel.Text = TOTAL .. " words indexed (cloud)"
        print(("[WordBomb] Ready! %d total words indexed."):format(TOTAL))
    else
        warn("[WordBomb] Cloud download failed. Using embedded starter vocabulary (" .. TOTAL .. " words).")
        wordCountLabel.Text = TOTAL .. " words (embedded fallback)"
    end
end)

print("[WordBomb] v2.5 initialized successfully. F6 to toggle, F8 to emergency stop.")
