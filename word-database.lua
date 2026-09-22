--[[
    word-database.lua — Word Bomb Auto-Typer
    Loads and indexes the 286,594-word list.
    Pre-buckets words by length for O(1) category lookup.
    Supports pattern filtering for the Word Bomb prompt system.
--]]

local WordDatabase = {}

-- ─── Internal State ───────────────────────────────────────────────────────────

--- Buckets: buckets[n] = array of words whose #word == n
local buckets = {}

--- Flat sorted array of all available lengths for binary search
local availableLengths = {}

local totalWords   = 0
local isLoaded     = false
local loadProgress = 0   -- 0.0 → 1.0

-- ─── Constants ────────────────────────────────────────────────────────────────

-- Word Bomb word list URL (raw GitHub content via HttpService)
-- In a real executor context this would be a file path, but Roblox
-- LocalScripts can also load from a bundled ModuleScript string.
-- We provide both paths; the executor wrapper picks the right one.
local WORDLIST_URL =
    "https://raw.githubusercontent.com/theboysclash/Word-bomb-word-lib/main/wordlist-286594-words.txt"

-- ─── Loading ──────────────────────────────────────────────────────────────────

--- Splits a multi-line string into individual words, normalised to uppercase.
local function parseWordList(raw)
    local words = {}
    for line in raw:gmatch("[^\r\n]+") do
        local word = line:match("^%s*(.-)%s*$")  -- trim whitespace
        if #word > 0 then
            words[#words + 1] = word:upper()
        end
    end
    return words
end

--- Inserts a single word into the bucketed index.
local function indexWord(word)
    local len = #word
    if not buckets[len] then
        buckets[len] = {}
        -- Keep availableLengths in sorted order
        local inserted = false
        for i, v in ipairs(availableLengths) do
            if v > len then
                table.insert(availableLengths, i, len)
                inserted = true
                break
            end
        end
        if not inserted then
            availableLengths[#availableLengths + 1] = len
        end
    end
    local bucket = buckets[len]
    bucket[#bucket + 1] = word
end

--- Loads words from a plain-text string (used when pre-bundled).
function WordDatabase.LoadFromString(rawText)
    buckets         = {}
    availableLengths = {}
    totalWords      = 0
    isLoaded        = false
    loadProgress    = 0

    local words = parseWordList(rawText)
    local n     = #words
    for i, word in ipairs(words) do
        indexWord(word)
        totalWords    = totalWords + 1
        loadProgress  = i / n
    end
    isLoaded = true
    print(string.format("[WordDB] Loaded %d words across %d length buckets.",
        totalWords, #availableLengths))
end

--- Loads words over HTTP (requires HttpService to be enabled).
--- Calls onProgress(fraction) periodically and onComplete() when done.
function WordDatabase.LoadFromHTTP(onProgress, onComplete)
    local HttpService = game:GetService("HttpService")
    local ok, result = pcall(function()
        return HttpService:GetAsync(WORDLIST_URL, true)
    end)

    if not ok then
        warn("[WordDB] HTTP load failed: " .. tostring(result))
        if onComplete then onComplete(false) end
        return
    end

    if onProgress then onProgress(0.5) end  -- Download done, now parsing

    local words = parseWordList(result)
    local n     = #words
    buckets          = {}
    availableLengths = {}
    totalWords       = 0

    for i, word in ipairs(words) do
        indexWord(word)
        totalWords = totalWords + 1
        -- Report progress every 10k words to avoid lag spikes
        if i % 10000 == 0 and onProgress then
            onProgress(0.5 + (i / n) * 0.5)
            task.wait()  -- Yield to prevent frame drops
        end
    end

    isLoaded     = true
    loadProgress = 1

    print(string.format("[WordDB] HTTP load complete. %d words, %d lengths.",
        totalWords, #availableLengths))

    if onProgress  then onProgress(1)     end
    if onComplete  then onComplete(true)  end
end

-- ─── Query API ────────────────────────────────────────────────────────────────

--- Returns true if the database has been fully loaded.
function WordDatabase.IsLoaded()
    return isLoaded
end

function WordDatabase.GetLoadProgress()
    return loadProgress
end

function WordDatabase.GetTotalWords()
    return totalWords
end

--- Returns a random word whose length falls within [minLen, maxLen]
--- and (optionally) whose uppercase form contains `pattern` as a substring.
---
--- @param minLen   number   Minimum word length (inclusive)
--- @param maxLen   number   Maximum word length (inclusive)
--- @param pattern  string?  Uppercase substring the word must contain (e.g. "TH")
--- @param tries    number?  How many random samples to attempt (default 200)
--- @return string? The selected word, or nil if none found.
function WordDatabase.FindWord(minLen, maxLen, pattern, tries)
    if not isLoaded then
        warn("[WordDB] Database not loaded yet.")
        return nil
    end

    tries = tries or 200

    -- Collect eligible length keys
    local eligible = {}
    for _, len in ipairs(availableLengths) do
        if len >= minLen and len <= maxLen then
            eligible[#eligible + 1] = len
        end
    end

    if #eligible == 0 then
        return nil
    end

    -- Weighted random selection: prefer longer words
    -- Build cumulative weight table (weight = len^2)
    local weights   = {}
    local cumWeight = 0
    for _, len in ipairs(eligible) do
        local w = len * len
        cumWeight       = cumWeight + w
        weights[#weights + 1] = { len = len, cum = cumWeight }
    end

    -- Fast path: no pattern filter → single weighted random pick
    if not pattern or pattern == "" then
        local r = math.random() * cumWeight
        for _, entry in ipairs(weights) do
            if r <= entry.cum then
                local bucket = buckets[entry.len]
                return bucket[math.random(1, #bucket)]
            end
        end
        -- Fallback
        local len    = eligible[math.random(1, #eligible)]
        local bucket = buckets[len]
        return bucket[math.random(1, #bucket)]
    end

    -- Slow path: must scan for pattern match
    -- Strategy: try random samples across eligible buckets up to `tries` times.
    local upPattern = pattern:upper()

    for _ = 1, tries do
        local r = math.random() * cumWeight
        local chosenLen = eligible[#eligible]  -- fallback
        for _, entry in ipairs(weights) do
            if r <= entry.cum then
                chosenLen = entry.len
                break
            end
        end
        local bucket = buckets[chosenLen]
        local word   = bucket[math.random(1, #bucket)]
        if word:find(upPattern, 1, true) then
            return word
        end
    end

    return nil  -- No match found within tries
end

--- Returns ALL words matching [minLen, maxLen] that contain `pattern`.
--- Expensive — use sparingly (prefer FindWord for gameplay).
function WordDatabase.FilterWords(minLen, maxLen, pattern)
    if not isLoaded then return {} end

    local upPattern = pattern and pattern:upper() or nil
    local results   = {}

    for _, len in ipairs(availableLengths) do
        if len >= minLen and len <= maxLen then
            for _, word in ipairs(buckets[len]) do
                if not upPattern or word:find(upPattern, 1, true) then
                    results[#results + 1] = word
                end
            end
        end
    end

    return results
end

--- Returns the longest word in the database containing `pattern`
--- within the given length range.
function WordDatabase.FindLongest(minLen, maxLen, pattern)
    if not isLoaded then return nil end

    local upPattern = pattern and pattern:upper() or nil

    -- Walk from longest to shortest
    for i = #availableLengths, 1, -1 do
        local len = availableLengths[i]
        if len <= maxLen and len >= minLen then
            if not upPattern then
                local bucket = buckets[len]
                return bucket[math.random(1, #bucket)]
            else
                -- Linear scan within this bucket (buckets are already small)
                local bucket   = buckets[len]
                local matching = {}
                for _, word in ipairs(bucket) do
                    if word:find(upPattern, 1, true) then
                        matching[#matching + 1] = word
                    end
                end
                if #matching > 0 then
                    return matching[math.random(1, #matching)]
                end
            end
        end
    end

    return nil
end

--- Returns a list of all distinct word lengths available.
function WordDatabase.GetAvailableLengths()
    return availableLengths
end

--- Returns how many words exist in a given length bucket.
function WordDatabase.GetBucketSize(len)
    return buckets[len] and #buckets[len] or 0
end

return WordDatabase
