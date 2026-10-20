BReST.utils = {}

local utils = BReST.utils

-- Shoot and Auto Shot are spells

-- Two hits closer than this (in seconds) can't be told apart by the swing timers alone
local AMBIGUOUS_GAP = 0.3

-- Armor of the NPC classes at level 60, only used to guess which hand a hit came from
local BASE_ARMOR = {
    WARRIOR = 3791,
    PALADIN = 3075,
    MAGE = 1923,
}

-- Armor removed by the usual debuffs (max rank, approximate), keyed by lowercased icon path
local ARMOR_DEBUFFS = {
    ["interface\\icons\\ability_warrior_sunder"] = 450, -- per stack
    ["interface\\icons\\spell_nature_faeriefire"] = 505,
    ["interface\\icons\\spell_shadow_unholystrength"] = 640,
    ["interface\\icons\\ability_warrior_riposte"] = 2050,
}

function utils.GetWeaponSpeed(off)
    -- off = true for offhand
	local speedMH, speedOH = UnitAttackSpeed("player")
	if (off) then
		return speedOH;
	else
		return speedMH;
	end
end

function utils.GetRangedSpeed()
    return UnitRangedDamage("player")
end

function utils.isDualWield()
	local speed = utils.GetWeaponSpeed(true)
	return (speed ~= nil and speed > 0);
end

-- Relics also sit in the ranged slot but have no attack speed
function utils.hasRanged()
	local speed = utils.GetRangedSpeed()
	return (speed ~= nil and speed > 0);
end

-- Guesses the hand from the damage of a hit. Returns "MAIN", "OFF" or "UNKNOWN"
function utils.CheckDamageSource(dmg, dmgType)
	if (not UnitExists("target")) then return "UNKNOWN" end
	if (dmg == nil) then return "UNKNOWN" end
	if (not utils.isDualWield()) then return "MAIN" end
	-- Only work for NPC as they have standard armor values
	if (UnitIsPlayer("target")) then return "UNKNOWN" end

	-- we will do armor check on the target here
	local _, unitClass = UnitClass("target");
	local armor = BASE_ARMOR[unitClass];
	if (armor == nil) then return "UNKNOWN" end

	for i=1,16 do
		local debuffTexture, debuffApplications = UnitDebuff("target", i);
		if (debuffTexture == nil) then break end
		local reduction = ARMOR_DEBUFFS[string.lower(debuffTexture)];
		if (reduction) then
			if (debuffApplications == nil or debuffApplications < 1) then debuffApplications = 1 end
			armor = armor - (reduction*debuffApplications);
		end
	end
	if (armor < 0) then armor = 0 end

	local tarLVL = UnitLevel("target");
	if (tarLVL == -1) then
		tarLVL = 63;
	end

	-- The mitigation depends on the level of the attacker, which is us
	local myLVL = UnitLevel("player");
	local dmgRed;
	if (myLVL > 59) then
		dmgRed = 1 - (armor/(armor+((467.5*myLVL)-22167.5)));
	else
		dmgRed = 1 - (armor/(armor+(85*myLVL+400)));
	end
	if (dmgRed < 0) then
		dmgRed = 0
	end

	local wpDmg = {};
	wpDmg["mainMin"], wpDmg["mainMax"], wpDmg["offMin"], wpDmg["offMax"] = UnitDamage("player");
	if (wpDmg["offMin"] == nil or wpDmg["offMax"] == nil) then return "UNKNOWN" end

	if (dmgType == "crit") then
		wpDmg["mainMin"] = wpDmg["mainMin"] * 2;
		wpDmg["mainMax"] = wpDmg["mainMax"] * 2;
		wpDmg["offMin"] = wpDmg["offMin"] * 2;
		wpDmg["offMax"] = wpDmg["offMax"] * 2;

	elseif (dmgType == "glancing")then
		local mobDef = tarLVL * 5;
		local mComp, mCompMod, oComp, oCompMod = UnitAttackBothHands("player");
		local pCompMain = mComp + mCompMod;
		local pCompOff = oComp + oCompMod;

		--Glancing values for mainhand
		local mainLOW = 1.3-(0.05*(mobDef - pCompMain));
		if (mainLOW < 0.1) then mainLOW = 0.1 end;
		if (mainLOW > 0.91) then mainLOW = 0.91 end;
		local mainHIGH = 1.2-(0.03*(mobDef - pCompMain));
		if (mainHIGH < 0.2) then mainHIGH = 0.2 end;
		if (mainHIGH > 0.99) then mainHIGH = 0.99 end;
		wpDmg["mainMin"] = wpDmg["mainMin"] * mainLOW;
		wpDmg["mainMax"] = wpDmg["mainMax"] * mainHIGH;

		--Glancing values for offhand
		local offLOW = 1.3-(0.05*(mobDef - pCompOff));
		if (offLOW < 0.1) then offLOW = 0.1 end;
		if (offLOW > 0.91) then offLOW = 0.91 end;
		local offHIGH = 1.2-(0.03*(mobDef - pCompOff));
		if (offHIGH < 0.2) then offHIGH = 0.2 end;
		if (offHIGH > 0.99) then offHIGH = 0.99 end;
		wpDmg["offMin"] = wpDmg["offMin"] * offLOW;
		wpDmg["offMax"] = wpDmg["offMax"] * offHIGH;
	end

	-- We could be a bit off, so we'll consider a 15% error margin
	local inMain = (dmg > ((wpDmg['mainMin'] * dmgRed)*0.85) and dmg < ((wpDmg['mainMax'] * dmgRed)*1.15));
	local inOff = (dmg > ((wpDmg['offMin'] * dmgRed)*0.85) and dmg < ((wpDmg['offMax'] * dmgRed)*1.15));

	if (inMain and not inOff) then
		return "MAIN";
	elseif (inOff and not inMain) then
		return "OFF";
	end

	return "UNKNOWN"
end

-- Which hand just swung, from the timers of both hands: the one whose swing was due.
-- dmg and dmgType are only used when the timers can't decide (they may be nil for a miss).
function utils.PickHand(dmg, dmgType)
	if (not utils.isDualWield()) then return "MAIN" end

	local main, off = BReST.mainhandTimer, BReST.offhandTimer
	if (main <= 0 and off <= 0) then return "MAIN" end  -- combat start, the main hand swings first
	if (main <= 0) then return "MAIN" end
	if (off <= 0) then return "OFF" end

	if (math.abs(main - off) > AMBIGUOUS_GAP) then
		if (main < off) then return "MAIN" end
		return "OFF"
	end

	local byDamage = utils.CheckDamageSource(dmg, dmgType)
	if (byDamage == "MAIN" or byDamage == "OFF") then return byDamage end
	if (main <= off) then return "MAIN" end
	return "OFF"
end
