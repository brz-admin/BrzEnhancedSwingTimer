

BReST.parser = {}
local parser = BReST.parser

function parser.selfSpellDamage(msg)
    -- This function parses a combat log message and extracts information from it
    -- The information that is extracted is:
    -- target: the target of the spell
    -- damage: the amount of damage the spell caused
    -- damageSchool: the school of the spell
    -- source: the unit that cast the spell
    -- spellName: the name of the spell
    -- damageType: the type of damage the spell caused (hit or crit)

    local target, damage, damageSchool, source, spellName, damageType

    -- These regular expressions are used to parse the message
    -- They are based on the format of the combat log messages
    local crit = string.gsub(SPELLLOGCRITSCHOOLSELFOTHER, "%(", function() return "%(" end)
    crit = string.gsub(crit, "%)", function() return "%)" end)
    crit = string.gsub(crit, "%%s", function() return "(.+)" end)
    crit = string.gsub(crit, "%%d", function() return "(%d+)" end)

    local hit = string.gsub(SPELLLOGSCHOOLSELFOTHER, "%%s", function() return "(.+)" end)
    hit = string.gsub(hit, "%%d", function() return "(%d+)" end)

    -- Check if the message matches the crit regular expression
    if (string.find(msg, crit)) then
        -- If it does, set the damage type to "crit"
        damageType = "crit"
        -- Extract the information from the message
        _, _, spellName, target, damage, damageSchool = string.find(msg, crit)
    elseif (string.find(msg, hit)) then
        -- If it doesn't match the crit regular expression, check if it matches the hit regular expression
        damageType = "hit"
        -- Extract the information from the message
        _, _, spellName, target, damage, damageSchool = string.find(msg, hit)
    end

    -- The source of the spell is the player
    source = UnitName("player")
    -- Make sure the damage is a number
    damage = tonumber(damage)

    -- Return the extracted information
    return target, damage, damageSchool, source, spellName, damageType
end

function parser.selfMeleeDamage(msg)
	-- This function parses a combat log message and extracts information from it
	-- The information that is extracted is:
	-- target: the target of the spell
	-- damage: the amount of damage the spell caused
	-- source: the unit that cast the spell
	-- damageType: the type of damage the spell caused (hit or crit)	
	local target, damage, source, damageType

	local crit = string.gsub(COMBATHITCRITSELFOTHER, "%%s", function() return "(.+)" end)
    crit = string.gsub(crit, "%%d", function() return "(%d+)" end)

    local hit = string.gsub(COMBATHITSELFOTHER, "%%s", function() return "(.+)" end)
    hit = string.gsub(hit, "%%d", function() return "(%d+)" end)

	local blocked = string.gsub(BLOCK_TRAILER, "%%d", function() return "(%d+)" end)
	blocked = hit..blocked

	local glance = hit..GLANCING_TRAILER;

	-- Check if the message matches the crit regular expression
	if (string.find(msg, crit)) then
		-- If it does, set the damage type to "crit"
		damageType = "crit"
		-- Extract the information from the message
		_, _, target, damage = string.find(msg, crit)
	elseif (string.find(msg, blocked)) then
		damageType = "block"
		-- Extract the information from the message
		local _, _, target, damage, blockedDamage = string.find(msg, blocked)
		damage = damage + blockedDamage;
	elseif (string.find(msg, glance)) then
		damageType = "glancing"
		-- Extract the information from the message
		_, _, target, damage = string.find(msg, glance)
	else
		damageType = "hit"
		-- Extract the information from the message
		_, _, target, damage = string.find(msg, hit)
	end
	-- The source of the spell is the player
	source = UnitName("player")
	-- Make sure the damage is a number
	damage = tonumber(damage)

	-- Return the extracted information
	return target, damage, source, damageType
end
