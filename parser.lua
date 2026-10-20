BReST.parser = {}
local parser = BReST.parser

local find, sub, gsub, len = string.find, string.sub, string.gsub, string.len
local getn = table.getn

-- The combat log lines are built from the client's GlobalStrings, so the patterns are generated
-- from them instead of being written by hand. That keeps every locale working, including the
-- ones that reorder arguments ("%2$s esquive votre %1$s.") or use Lua magic characters.

local compiled = {}

local function escape(text)
    return (gsub(text, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

-- Turns a GlobalStrings format into a Lua pattern.
-- mode "full" anchors both ends, "tail" only the end (used for the "(5 blocked)" style trailers).
-- order[i] is the format argument held by the i-th capture.
local function compile(fmt, mode)
    local key = mode .. fmt
    local c = compiled[key]
    if c then return c end

    -- "|2 " is the French elision marker (de / d'). It is either already expanded or dropped by
    -- the time the line reaches the chat events, so the school is simply what follows.
    local text = gsub(fmt, "|2 ?", "")

    local pattern, order, n, pos = "", {}, 0, 1
    local size = len(text)
    while pos <= size do
        local s, e, index, kind = find(text, "%%(%d*)%$?([sd])", pos)
        if not s then break end
        pattern = pattern .. escape(sub(text, pos, s - 1))
        if kind == "d" then
            pattern = pattern .. "(%d+)"
        else
            pattern = pattern .. "(.+)"
        end
        n = n + 1
        order[n] = tonumber(index) or n
        pos = e + 1
    end
    pattern = pattern .. escape(sub(text, pos))

    if mode == "full" then
        pattern = "^" .. pattern .. "$"
    else
        pattern = pattern .. "$"
    end

    c = { pattern = pattern, order = order, n = n }
    compiled[key] = c
    return c
end

-- Returns the arguments of the format found in msg (indexed by their position in the format)
-- and the position where the match starts.
local function parse(msg, fmt, mode)
    if type(fmt) ~= "string" then return nil end
    local c = compile(fmt, mode or "full")
    local r = { find(msg, c.pattern) }
    if not r[1] then return nil end
    local args = {}
    for i = 1, c.n do
        args[c.order[i]] = r[i + 2]
    end
    return args, r[1]
end

local function firstOf(msg, rows)
    for i = 1, getn(rows) do
        local args = parse(msg, rows[i].fmt)
        if args then return args, rows[i] end
    end
end

local function cleanSchool(school)
    if not school then return nil end
    school = gsub(school, "^|2%s*", "")
    school = gsub(school, "^de%s+", "")
    school = gsub(school, "^d'", "")
    return school
end

-- Appended to a line when part of the damage was blocked, absorbed...
local TRAILERS = {
    { fmt = BLOCK_TRAILER, kind = "block", counts = true },
    { fmt = ABSORB_TRAILER, kind = "absorb", counts = true },
    { fmt = RESIST_TRAILER, kind = "resist", counts = true },
    { fmt = GLANCING_TRAILER, kind = "glancing" },
    { fmt = CRUSHING_TRAILER, kind = "crushing" },
}

-- Returns the line without its trailers, the kinds of trailer found and the damage they removed
local function splitTrailers(msg)
    local found, extra = {}, 0
    local again = true
    while again do
        again = false
        msg = gsub(msg, "%s+$", "")
        for i = 1, getn(TRAILERS) do
            local t = TRAILERS[i]
            local args, from = parse(msg, t.fmt, "tail")
            if args then
                found[t.kind] = true
                if t.counts then extra = extra + (tonumber(args[1]) or 0) end
                msg = sub(msg, 1, from - 1)
                again = true
                break
            end
        end
    end
    return gsub(msg, "%s+$", ""), found, extra
end

-- Auto attacks. Arguments: 1 = target, 2 = damage, 3 = school
local MELEE_DAMAGE = {
    { fmt = COMBATHITCRITSCHOOLSELFOTHER, kind = "crit" },
    { fmt = COMBATHITCRITSELFOTHER, kind = "crit" },
    { fmt = COMBATHITSCHOOLSELFOTHER, kind = "hit" },
    { fmt = COMBATHITSELFOTHER, kind = "hit" },
}

-- Auto attacks that did no damage. Argument: 1 = target
local MELEE_AVOIDS = {
    { fmt = MISSEDSELFOTHER, outcome = "miss" },
    { fmt = VSDODGESELFOTHER, outcome = "dodge" },
    { fmt = VSPARRYSELFOTHER, outcome = "parry" },
    { fmt = VSBLOCKSELFOTHER, outcome = "block" },
    { fmt = VSEVADESELFOTHER, outcome = "evade" },
    { fmt = VSIMMUNESELFOTHER, outcome = "immune" },
    { fmt = VSABSORBSELFOTHER, outcome = "absorb" },
    { fmt = VSRESISTSELFOTHER, outcome = "resist" },
}

-- Spells and shots. Arguments: 1 = spell, 2 = target, 3 = damage, 4 = school
local SPELL_DAMAGE = {
    { fmt = SPELLLOGCRITSCHOOLSELFOTHER, kind = "crit" },
    { fmt = SPELLLOGCRITSELFOTHER, kind = "crit" },
    { fmt = SPELLLOGSCHOOLSELFOTHER, kind = "hit" },
    { fmt = SPELLLOGSELFOTHER, kind = "hit" },
}

-- Spells that did no damage. Arguments: 1 = spell, 2 = target
local SPELL_AVOIDS = {
    { fmt = SPELLMISSSELFOTHER, outcome = "miss" },
    { fmt = SPELLDODGEDSELFOTHER, outcome = "dodge" },
    { fmt = SPELLPARRIEDSELFOTHER, outcome = "parry" },
    { fmt = SPELLEVADEDSELFOTHER, outcome = "evade" },
    { fmt = SPELLBLOCKEDSELFOTHER, outcome = "block" },
    { fmt = SPELLIMMUNESELFOTHER, outcome = "immune" },
    { fmt = SPELLRESISTSELFOTHER, outcome = "resist" },
    { fmt = SPELLDEFLECTEDSELFOTHER, outcome = "deflect" },
    { fmt = SPELLREFLECTSELFOTHER, outcome = "reflect" },
    { fmt = SPELLLOGABSORBSELFOTHER, outcome = "absorb" },
}

-- Parses an auto attack that dealt damage (CHAT_MSG_COMBAT_SELF_HITS).
-- Returns target, damage, source, damageType (hit, crit, block or glancing), school
-- or nothing if the line is not one of those.
function parser.selfMeleeDamage(msg)
    local body, trailers, extra = splitTrailers(msg)
    local args, row = firstOf(body, MELEE_DAMAGE)
    if not args then return end

    local damageType = row.kind
    if trailers.glancing then
        damageType = "glancing"
    elseif trailers.block and damageType == "hit" then
        damageType = "block"
    end

    -- The damage that was blocked / absorbed is added back, it is what the weapon rolled
    local damage = (tonumber(args[2]) or 0) + extra
    return args[1], damage, UnitName("player"), damageType, cleanSchool(args[3])
end

-- Parses an auto attack that did nothing (CHAT_MSG_COMBAT_SELF_MISSES).
-- Returns target, outcome (miss, dodge, parry...) or nothing.
function parser.selfMeleeAvoid(msg)
    local args, row = firstOf(msg, MELEE_AVOIDS)
    if not args then return end
    return args[1], row.outcome
end

-- Parses the result of one of our spells or shots (CHAT_MSG_SPELL_SELF_DAMAGE).
-- Returns spellName, target, outcome (hit, crit, miss, dodge, parry...), damage, school
-- damage and school are only set for hit and crit. Returns nothing if the line is not ours.
function parser.selfSpell(msg)
    local body, trailers, extra = splitTrailers(msg)

    local args, row = firstOf(body, SPELL_DAMAGE)
    if args then
        local damage = (tonumber(args[3]) or 0) + extra
        return args[1], args[2], row.kind, damage, cleanSchool(args[4])
    end

    args, row = firstOf(body, SPELL_AVOIDS)
    if args then
        return args[1], args[2], row.outcome
    end
end

-- Same as selfSpell, for damaging spells only.
-- Returns target, damage, damageSchool, source, spellName, damageType (hit or crit)
function parser.selfSpellDamage(msg)
    local spellName, target, outcome, damage, damageSchool = parser.selfSpell(msg)
    if outcome ~= "hit" and outcome ~= "crit" then return end
    return target, damage, damageSchool, UnitName("player"), spellName, outcome
end
