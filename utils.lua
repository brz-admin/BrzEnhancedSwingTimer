BReST.utils = {}

local utils = BReST.utils

-- Shoot and Auto Shot are spells

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
	return (GetWeaponSpeed(true) ~= nil);
end

function utils.CheckDamageSource(dmg, dmgType)
	if (not UnitExists("target")) then return end
	if (dmg == nil) then return end
	if (not isDualWield()) then return "MAIN" end
	-- Only work for NPC as they have standard armor values
	if (not UnitIsPlayer("target")) then
		-- we will do armor check on the target here
		local basearmor = {
			[L['Warrior']] = 3791,
			['Paladin'] = 3075,
			['Mage']	= 1923,
		};
		local unitClass = UnitClass("target");
		local armor = basearmor[unitClass];
		for i=1,16 do
			local debuffTexture, debuffApplications = UnitDebuff("target", i);
			if (has_value(armorDebuffs,debuffTexture)) then
				armor = armor - (armorDebuffs[debuffTexture]*debuffApplications);
			end
		end

		local tarLVL = UnitLevel("target");
		if (UnitLevel("target") == -1) then
			tarLVL = 63;
		end

		local dmgRed = 1 - (armor/(armor+((467.5*tarLVL)-22167.5)));
		if (dmgRed < 0) then
			dmgRed = 0
		end

		local wpDmg = {};
		wpDmg["mainMin"], wpDmg["mainMax"], wpDmg["offMin"], wpDmg["offMax"], _, _, _ = UnitDamage("player");

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
		if (dmg > ((wpDmg['mainMin'] * dmgRed)*0.85) and dmg < ((wpDmg['mainMax'] * dmgRed)*1.15)) then
			return "MAIN";
		elseif (dmg > ((wpDmg['offMin'] * dmgRed)*0.85) and dmg < ((wpDmg['offMax'] * dmgRed)*1.15)) then
			return "OFF";
		else
			--print("DEBUG : "..dmgType.." "..dmg.."\nMAIN = "..(wpDmg['mainMin'] * dmgRed)*0.9.." - "..(wpDmg['mainMax'] * dmgRed)*1.1.."\nOFF = "..(wpDmg['offMin'] * dmgRed)*0.9.." - "..(wpDmg['offMax'] * dmgRed)*1.1);
			return "UNKNOWN"
		end

	end

	return "UNKNOWN";
end
