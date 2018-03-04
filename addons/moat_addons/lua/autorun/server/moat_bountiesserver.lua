util.AddNetworkString "moat_bounty_send"
util.AddNetworkString "moat_bounty_update"
util.AddNetworkString "moat_bounty_chat"
util.AddNetworkString "moat_bounty_reload"

MOAT_BOUNTIES = MOAT_BOUNTIES or {}
MOAT_BOUNTIES.DatabasePrefix = "live1"
MOAT_BOUNTIES.Bounties = {}
MOAT_BOUNTIES.ActiveBounties = {}

function MOAT_BOUNTIES.CreateTable(name, create)
	if (not sql.TableExists(name)) then
		sql.Query(create)
		MsgC(Color(0, 255, 0), "Created SQL Table: " .. name .. "\n")
	end
end

function MOAT_BOUNTIES:BroadcastChat(tier, str)
	net.Start("moat_bounty_chat")
	net.WriteUInt(tier, 4)
	net.WriteString(str)
	net.Broadcast()
end

function MOAT_BOUNTIES:SendChat(tier, str, ply)
	net.Start("moat_bounty_chat")
	net.WriteUInt(tier, 4)
	net.WriteString(str)
	net.Send(ply)
end

MOAT_BOUNTIES.CreateTable("bounties_refresh" .. MOAT_BOUNTIES.DatabasePrefix, "CREATE TABLE IF NOT EXISTS bounties_refresh" .. MOAT_BOUNTIES.DatabasePrefix .. " (shouldrefresh TEXT NOT NULL)")
MOAT_BOUNTIES.CreateTable("bounties_current" .. MOAT_BOUNTIES.DatabasePrefix, "CREATE TABLE IF NOT EXISTS bounties_current" .. MOAT_BOUNTIES.DatabasePrefix .. " (bounty1 TEXT NOT NULL, bounty2 TEXT NOT NULL, bounty3 TEXT NOT NULL)")
MOAT_BOUNTIES.CreateTable("bounties_save" .. MOAT_BOUNTIES.DatabasePrefix, "CREATE TABLE IF NOT EXISTS bounties_save" .. MOAT_BOUNTIES.DatabasePrefix .. " (steamid VARCHAR(30) NOT NULL PRIMARY KEY, bounty1 INTEGER NOT NULL, bounty2 INTEGER NOT NULL, bounty3 INTEGER NOT NULL)")

local bounty_id = 1

function MOAT_BOUNTIES:AddBounty(name_, tbl)
	local bounty = {
		name = name_,
		tier = tbl.tier,
		desc = tbl.desc,
		vars = tbl.vars,
		runfunc = tbl.runfunc,
		rewards = tbl.rewards,
		rewardtbl = tbl.rewardtbl
	}

	self.Bounties[bounty_id] = bounty

	bounty_id = bounty_id + 1
end

function MOAT_BOUNTIES:RewardPlayer(ply, bounty_id)
	if (not ply:IsValid()) then return end
	local rewards = self.Bounties[bounty_id].rewardtbl

	if (rewards.ic) then
		ply:m_GiveIC(rewards.ic)
	end

	if (rewards.exp) then
		ply:ApplyXP(rewards.exp)
	end

	if (rewards.drop) then
		if (istable(rewards.drop)) then
			for i = 1, #rewards.drop do
				ply:m_DropInventoryItem(rewards.drop[i])
			end
		else
			ply:m_DropInventoryItem(rewards.drop)
		end
	end

	local level = self.Bounties[bounty_id].tier

	self:SendChat(level, "You have completed the " .. self.Bounties[bounty_id].name .. " Bounty and have been rewarded " .. self.Bounties[bounty_id].rewards .. ".", ply)
end

function MOAT_BOUNTIES:IncreaseProgress(ply, bounty_id, max)
	if (not ply:IsValid()) then return end
	local tier = self.Bounties[bounty_id].tier
	local id = ply:SteamID64()
	if MOAT_MINIGAME_OCCURING then return end
	if (not tier or not id) then return end

	local cur_progress = sql.Query(string.format("SELECT bounty" .. tier .. " FROM bounties_save" .. MOAT_BOUNTIES.DatabasePrefix .. " WHERE steamid = %s", id))

	if (not cur_progress) then return end
	
	local cur_num = tonumber(cur_progress[1]["bounty" .. tier])

	if (cur_num < max) then
		sql.Query(string.format("UPDATE bounties_save" .. MOAT_BOUNTIES.DatabasePrefix .. " SET bounty" .. tier .. " = bounty" .. tier .. " + 1 WHERE steamid = %s", id))

		net.Start("moat_bounty_update")
		net.WriteUInt(tier, 4)
		net.WriteUInt(cur_num + 1, 16)
		net.Send(ply)

		if (self.Bounties[bounty_id].name == "Marathon Walker") then
			MOAT_BOUNTIES:SendChat(1, "You have completed a round of the marathon walker bounty!", ply)
		end

		if (cur_num + 1 == max) then
			self:RewardPlayer(ply, bounty_id)
		end
	end
end


local weapon_challenges = {
    {"weapon_zm_shotgun", "an XM1014", "XM1014"},
    {"weapon_zm_mac10", "a MAC10", "MAC10"},
    {"weapon_ttt_p90", "an FN P90", "FN P90"},
    {"weapon_ttt_aug", "an AUG", "AUG"},
    {"weapon_ttt_ak47", "an AK47", "AK47"},
    {"weapon_ttt_mr96", "a Revolver", "Revolver"},
    {"weapon_zm_pistol", "a Pistol", "Pistol"},
    {"weapon_ttt_sg550", "an SG550", "SG550"},
    {"weapon_ttt_m16", "an M16", "M16"},
    {"weapon_zm_sledge", "a H.U.G.E-249", "H.U.G.E-249"},
    {"weapon_ttt_dual_elites", "Dual Elites", "Dual Elites"},
    {"weapon_zm_revolver", "a Deagle", "Deagle"},
    {"weapon_ttt_ump45", "an UMP-45", "UMP-45"},
    {"weapon_ttt_msbs", "a MSBS", "MSBS"},
    {"weapon_ttt_shotgun", "a Shotgun", "Shotgun"},
    {"weapon_xm8b", "an M8A1", "M8A1"},
    {"weapon_zm_rifle", "a Rifle", "Rifle"},
    {"weapon_ttt_galil", "a Galil", "Galil"},
    {"weapon_ttt_sg552", "an SG552", "SG552"},
    {"weapon_ttt_m590", "a Mossberg", "Mossberg"},
    {"weapon_flakgun", "a Flak-28", "Flak-28"},
    {"weapon_thompson", "a Tommy Gun", "Tommy Gun"},
    {"weapon_ttt_famas", "a Famas", "Famas"},
    {"weapon_ttt_glock", "a Glock", "Glock"},
    {"weapon_ttt_mp5", "an MP5", "MP5"}
}

local function WasRightfulKill(att, vic)
	if (GetRoundState() ~= ROUND_ACTIVE) then return false end
	
	local vicrole = vic:GetRole()
	local attrole = att:GetRole()

	if (vicrole == ROLE_TRAITOR and attrole == ROLE_TRAITOR) then return false end
	if ((vicrole == ROLE_DETECTIVE or vicrole == ROLE_INNOCENT) and attrole ~= ROLE_TRAITOR) then return false end

	return true
end

local chal_prefix = {
	"Dangerous",
	"Alarming",
	"Hazardous",
	"Troubling",
	"Deadly",
	"Fatal",
	"Nasty",
	"Risky",
	"Serious",
	"Terrible",
	"Threatening",
	"Ugly",
	"Cruel",
	"Evil",
	"Atrocious",
	"Vicious",
	"Pitiless",
	"Brutal",
	"Harsh",
	"Hateful",
	"Heartless",
	"Merciless",
	"Wicked",
	"Ferocious",
	"Spiteful"
}

local chal_suffix = {
	"Killer",
	"Assassin",
	"Hunter",
	"Exterminator",
	"Slayer",
	"Criminal",
	"Murderer"
}

local tier1_rewards = {
	ic = 2000,
	exp = 2500,
	drop = 5
}
local tier1_rewards_str = "2,000 Inventory Credits + 2,500 Player Experience + High-End+ Item"


local tier2_rewards = {
	ic = 3500,
	exp = 5500,
	drop = 5
}
local tier2_rewards_str = "3,500 Inventory Credits + 5,500 Player Experience + High-End+ Item"


local tier3_rewards = {
	ic = 5000,
	exp = 8500,
	drop = 5
}
local tier3_rewards_str = "5,000 Inventory Credits + 8,500 Player Experience + High-End+ Item"



--[[-------------------------------------------------------------------------
TIER 1 BOUNTIES
---------------------------------------------------------------------------]]


for i = 1, #weapon_challenges do
	local wpntbl = weapon_challenges[i]

	MOAT_BOUNTIES:AddBounty((chal_prefix[i] or "Dangerous") .. " " .. wpntbl[3] .. " " .. (chal_suffix[i] or "Slayer"), {
		tier = 1,
		desc = "Eliminate # terrorists, rightfully, with ".. wpntbl[2] .. ". Can be completed as any role.",
		vars = {
			math.random(35, 65),
		},
		runfunc = function(mods, bountyid)
			hook.Add("PlayerDeath", "moat_weapon_challenges_1_" .. wpntbl[1], function(ply, inf, att)
				if (att:IsValid() and att:IsPlayer()) then
					inf = att:GetActiveWeapon()
				end

				if (att:IsValid() and att:IsPlayer() and ply ~= att and inf and inf.ClassName and inf.ClassName == wpntbl[1] and WasRightfulKill(att, ply)) then
					MOAT_BOUNTIES:IncreaseProgress(att, bountyid, mods[1])
				end
			end)
		end,
		rewards = tier1_rewards_str,
		rewardtbl = tier1_rewards
	})
end

--v
MOAT_BOUNTIES:AddBounty("Detective Hunter", {
	tier = 1,
	desc = "Eliminate a total of # detectives. Can be completed as a traitor only.",
	vars = {
		math.random(5,15)
	},
	runfunc = function(mods, bountyid)
		hook.Add("PlayerDeath", "moat_death_dethunt", function(ply, inf, att)
			if (att:IsValid() and att:IsPlayer()) then
				inf = att:GetActiveWeapon()
			end

			if (att:IsValid() and att:IsPlayer() and ply ~= att and att:GetRole() == ROLE_TRAITOR and GetRoundState() == ROUND_ACTIVE and ply:GetRole() == ROLE_DETECTIVE) then
				MOAT_BOUNTIES:IncreaseProgress(att, bountyid, mods[1])
			end
		end)
	end,
	rewards = tier3_rewards_str,
	rewardtbl = tier3_rewards
})

--v
MOAT_BOUNTIES:AddBounty("One Tapper", {
	tier = 1,
	desc = "Eliminate # terrorists rightfully, only with one shot kills. Can be completed as any role.",
	vars = {
		math.random(35, 65),
	},
	runfunc = function(mods, bountyid)
        hook.Add("TTTBeginRound", "moat_reset_1tap", function()
			for k, v in pairs(player.GetAll()) do
				v.attacked = {}
			end
		end)

		hook.Add("ScalePlayerDamage", "moat_track_1tap", function(ply, hitgroup, dmginfo)
			local att = dmginfo:GetAttacker()
            if not GetRoundState() == ROUND_ACTIVE then return end


            if (not att.attacked) then
            	att.attacked = {}
            end

			if not att.attacked[ply] then
                att.attacked[ply] = {1,CurTime() + 0.1}
            elseif att.attacked[ply][2] < CurTime() then
                att.attacked[ply] = {2,0}
            end
		end)

		hook.Add("PlayerDeath", "moat_headshot_expert", function(ply, inf, att)
			if (att:IsValid() and att:IsPlayer() and ply ~= att and IsValid(inf) and inf:IsWeapon() and WasRightfulKill(att, ply)) then
                if att.attacked[ply][1] > 1 then return end
				MOAT_BOUNTIES:IncreaseProgress(att, bountyid, mods[1])
			end
		end)
	end,
	rewards = tier1_rewards_str,
	rewardtbl = tier1_rewards
})

--v
MOAT_BOUNTIES:AddBounty("Marathon Walker", {
	tier = 1,
	desc = "In # different rounds, take # steps each round. (doesn't have to be in a row)",
	vars = {
		math.random(2,5),
		math.random(350, 700)
        -- Should probably be higher idk
	},
	runfunc = function(mods, bountyid)
        hook.Add("TTTBeginRound", "moat_reset_steps", function()
			for k, v in pairs(player.GetAll()) do
				v.cSteps = 0
			end
		end)

		hook.Add("PlayerFootstep", "moat_step_tracker", function(ply)
		    if GetRoundState() ~= ROUND_ACTIVE then return end
		    if ply:Team() == TEAM_SPEC then return end
		    if (not ply.cSteps) then ply.cSteps = 0 end
		    
            ply.cSteps = ply.cSteps + 1
            
            if ply.cSteps == mods[2] then
                MOAT_BOUNTIES:IncreaseProgress(ply, bountyid, mods[1])
            end
		end)
	end,
	rewards = tier1_rewards_str,
	rewardtbl = tier1_rewards
})

MOAT_BOUNTIES:AddBounty("Close Quaters Combat", {
	tier = 1,
	desc = "Eliminate # terrorists, rightfully, while being close to your target. Can be completed as any role.",
	vars = {
		math.random(35, 65),
	},
	runfunc = function(mods, bountyid)
		hook.Add("PlayerDeath", "moat_close_quaters_combat", function(ply, inf, att)
			local vic_pos = ply:GetPos()

			if (att:IsValid() and att:IsPlayer() and ply ~= att and vic_pos:Distance(att:GetPos()) < 500 and WasRightfulKill(att, ply)) then
				MOAT_BOUNTIES:IncreaseProgress(att, bountyid, mods[1])
			end
		end)
	end,
	rewards = tier1_rewards_str,
	rewardtbl = tier1_rewards
})

MOAT_BOUNTIES:AddBounty("Longshot Killer", {
	tier = 1,
	desc = "Eliminate # terrorists, rightfully, while being far away from your target. Can be completed as any role.",
	vars = {
		math.random(35, 65),
	},
	runfunc = function(mods, bountyid)
		hook.Add("PlayerDeath", "moat_longshot_killer", function(ply, inf, att)
			local vic_pos = ply:GetPos()

			if (att:IsValid() and att:IsPlayer() and ply ~= att and vic_pos:Distance(att:GetPos()) > 1000 and WasRightfulKill(att, ply)) then
				MOAT_BOUNTIES:IncreaseProgress(att, bountyid, mods[1])
			end
		end)
	end,
	rewards = tier1_rewards_str,
	rewardtbl = tier1_rewards
})

MOAT_BOUNTIES:AddBounty("Headshot Expert", {
	tier = 1,
	desc = "Eliminate # terrorists, rightfully, with a headshot as the cause of death. Can be completed as any role.",
	vars = {
		math.random(35, 65),
	},
	runfunc = function(mods, bountyid)
		hook.Add("ScalePlayerDamage", "moat_headshot_expert_scale", function(ply, hitgroup, dmginfo)
			local att = dmginfo:GetAttacker()

			if (hitgroup == HITGROUP_HEAD) then
				att.lasthead = ply
			elseif (att.lasthead == ply) then
				att.lasthead = att
			end
		end)

		hook.Add("PlayerDeath", "moat_headshot_expert", function(ply, inf, att)
			if (att:IsValid() and att:IsPlayer()) then
				inf = att:GetActiveWeapon()
			end

			if (att:IsValid() and att:IsPlayer() and ply ~= att and IsValid(inf) and inf:IsWeapon() and (att.lasthead and att.lasthead == ply) and WasRightfulKill(att, ply)) then
				MOAT_BOUNTIES:IncreaseProgress(att, bountyid, mods[1])
			end
		end)
	end,
	rewards = tier1_rewards_str,
	rewardtbl = tier1_rewards
})


--[[-------------------------------------------------------------------------
TIER 2 BOUNTIES
---------------------------------------------------------------------------]]



MOAT_BOUNTIES:AddBounty("Demolition Expert", {
	tier = 2,
	desc = "Eliminate # terrorists, rightfully, with an explosion as the cause of death. Can be completed as any role.",
	vars = {
		math.random(25, 35),
	},
	runfunc = function(mods, bountyid)
		hook.Add("DoPlayerDeath", "moat_demo_expert", function(ply, att, dmg)
			if (att:IsValid() and att:IsPlayer() and ply ~= att and dmg:IsExplosionDamage() and WasRightfulKill(att, ply)) then
				MOAT_BOUNTIES:IncreaseProgress(att, bountyid, mods[1])
			end
		end)
	end,
	rewards = tier2_rewards_str,
	rewardtbl = tier2_rewards
})

MOAT_BOUNTIES:AddBounty("Anti-Traitor Force", {
	tier = 2,
	desc = "# Task. Eliminate # traitors, rightfully, in one round. Can be completed as any role.",
	vars = {
		1,
		math.random(3, 5)
	},
	runfunc = function(mods, bountyid)
		hook.Add("TTTBeginRound", "moat_reset_antitraitor_force", function()
			for k, v in pairs(player.GetAll()) do
				v.antitforce = 0
			end
		end)

		hook.Add("PlayerDeath", "moat_antitraitor_force_death", function(ply, inf, att)
			if (att:IsValid() and att:IsPlayer()) then
				inf = att:GetActiveWeapon()
			end

			if (att:IsValid() and att:IsPlayer() and ply ~= att and GetRoundState() == ROUND_ACTIVE and ply:GetRole() == ROLE_TRAITOR and (att:GetRole() == ROLE_INNOCENT or att:GetRole() == ROLE_DETECTIVE)) then
				att.antitforce = att.antitforce + 1

				if (att.antitforce == mods[2]) then
					MOAT_BOUNTIES:IncreaseProgress(att, bountyid, mods[1])
				end
			end
		end)
	end,
	rewards = tier2_rewards_str,
	rewardtbl = tier2_rewards
})

MOAT_BOUNTIES:AddBounty("Knife Addicted", {
	tier = 2,
	desc = "Eliminate # terrorists, rightfully, with a knife. Can be completed as a traitor only.",
	vars = {
		math.random(10, 20),
	},
	runfunc = function(mods, bountyid)
		hook.Add("PlayerDeath", "moat_knife_addicted", function(ply, inf, att)
			if (att:IsValid() and att:IsPlayer()) then
				inf = att:GetActiveWeapon()
			end

			if (att:IsValid() and att:IsPlayer() and ply ~= att and IsValid(inf) and inf.ClassName and ((inf:IsWeapon() and inf.ClassName == "weapon_ttt_knife") or (inf.ClassName == "ttt_knife_proj")) and WasRightfulKill(att, ply)) then
				MOAT_BOUNTIES:IncreaseProgress(att, bountyid, mods[1])
			end
		end)
	end,
	rewards = tier2_rewards_str,
	rewardtbl = tier2_rewards
})

MOAT_BOUNTIES:AddBounty("DNA Addicted", {
	tier = 2,
	desc = "Use the DNA tool to locate # traitors. Can be completed as a detective only.",
	vars = {
		math.random(7, 12),
	},
	runfunc = function(mods, bountyid)

		hook.Add("TTTBeginRound", "moat_reset_dna", function()
			for k, v in pairs(player.GetAll()) do
				v.dnatbl = {}
			end
		end)

		hook.Add("TTTFoundDNA", "moat_dna_addicted", function(ply, dna_owner, ent)
			if (ply:IsValid() and GetRoundState() == ROUND_ACTIVE and ply:GetRole() == ROLE_DETECTIVE and dna_owner:IsValid() and dna_owner:GetRole() == ROLE_TRAITOR and not table.HasValue(ply.dnatbl, ent)) then
				table.insert(ply.dnatbl, ent)
				
				MOAT_BOUNTIES:IncreaseProgress(ply, bountyid, mods[1])
			end
		end)
	end,
	rewards = tier2_rewards_str,
	rewardtbl = tier2_rewards
})

MOAT_BOUNTIES:AddBounty("Body Searcher", {
	tier = 2,
	desc = "Identify # unidentified dead bodies. Can be completed as any role.",
	vars = {
		math.random(50, 100),
	},
	runfunc = function(mods, bountyid)
		hook.Add("TTTBodyFound", "moat_body_searcher", function(ply, dead, rag)
			if (ply:IsValid() and GetRoundState() == ROUND_ACTIVE) then
				MOAT_BOUNTIES:IncreaseProgress(ply, bountyid, mods[1])
			end
		end)
	end,
	rewards = tier2_rewards_str,
	rewardtbl = tier2_rewards
})

MOAT_BOUNTIES:AddBounty("Health Station Addicted", {
	tier = 2,
	desc = "In # map, use a health station to heal # health. Can be completed as any role.",
	vars = {
		1,
		math.random(100, 200)
	},
	runfunc = function(mods, bountyid)
		hook.Add("TTTPlayerUsedHealthStation", "moat_health_station_addict", function(ply, ent_station, healed)
			if (not ply.healthaddict) then
				ply.healthaddict = 0
			end

			ply.healthaddict = ply.healthaddict + healed

			if (ply:IsValid() and GetRoundState() == ROUND_ACTIVE and ply.healthaddict >= mods[2]) then
				MOAT_BOUNTIES:IncreaseProgress(ply, bountyid, mods[1])
			end
		end)
	end,
	rewards = tier2_rewards_str,
	rewardtbl = tier2_rewards
})

MOAT_BOUNTIES:AddBounty("Equipment User", {
	tier = 2,
	desc = "Order # equipment items total. Can be completed as a traitor or detective only.",
	vars = {
		math.random(25, 55)
	},
	runfunc = function(mods, bountyid)
		hook.Add("TTTOrderedEquipment", "moat_order_equip", function(ply, equipment, is_item)
			if (ply:IsValid() and GetRoundState() == ROUND_ACTIVE and (ply:GetRole() == ROLE_TRAITOR or ply:GetRole() == ROLE_DETECTIVE)) then
				MOAT_BOUNTIES:IncreaseProgress(ply, bountyid, mods[1])
			end
		end)
	end,
	rewards = tier2_rewards_str,
	rewardtbl = tier2_rewards
})

MOAT_BOUNTIES:AddBounty("Traitor Assassin", {
	tier = 2,
	desc = "Eliminate # traitors, rightfully, while having full health. Can be completed as an innocent or detective only.",
	vars = {
		math.random(25, 35),
	},
	runfunc = function(mods, bountyid)
		hook.Add("PlayerDeath", "moat_traitor_assassin", function(ply, inf, att)
			if (att:IsValid() and att:IsPlayer() and ply ~= att and att:Health() >= att:GetMaxHealth() and ply:GetRole() == ROLE_TRAITOR and WasRightfulKill(att, ply)) then
				MOAT_BOUNTIES:IncreaseProgress(att, bountyid, mods[1])
			end
		end)
	end,
	rewards = tier2_rewards_str,
	rewardtbl = tier2_rewards
})

MOAT_BOUNTIES:AddBounty("No Equipments Allowed", {
	tier = 2,
	desc = "Win # rounds as a traitor or detective without purchasing a single equipment item.",
	vars = {
		math.random(7, 14),
	},
	runfunc = function(mods, bountyid)
		hook.Add("TTTEndRound", "moat_no_equipments_allowed_end", function(res)
			for k, v in pairs(player.GetAll()) do
				if (res == WIN_TRAITOR and v:GetRole() == ROLE_TRAITOR and v.noequipments) then
					MOAT_BOUNTIES:IncreaseProgress(v, bountyid, mods[1])
				elseif ((res == WIN_INNOCENT or res == WIN_TIMELIMIT) and v:GetRole() == ROLE_DETECTIVE and v.noequipments) then
					MOAT_BOUNTIES:IncreaseProgress(v, bountyid, mods[1])
				end
			end
		end)

		hook.Add("TTTBeginRound", "moat_no_equipments_allowed_begin", function()
			for k, v in pairs(player.GetAll()) do
				v.noequipments = true
			end
		end)

		hook.Add("TTTOrderedEquipment", "moat_no_equipments_allowed_equip", function(ply, equipment, is_item)
			if (ply:IsValid() and GetRoundState() == ROUND_ACTIVE and (ply:GetRole() == ROLE_TRAITOR or ply:GetRole() == ROLE_DETECTIVE)) then
				ply.noequipments = false
			end
		end)
	end,
	rewards = tier2_rewards_str,
	rewardtbl = tier2_rewards
})



--[[-------------------------------------------------------------------------
TIER 3 BOUNTIES
---------------------------------------------------------------------------]]

--v
MOAT_BOUNTIES:AddBounty("Quickswitching killer", {
	tier = 3,
	desc = "In # round, get # rightful kills with # different guns.",
	vars = {
        1,
        math.random(5, 10),
		math.random(3, 5),
	},
	runfunc = function(mods, bountyid)
        hook.Add("TTTBeginRound", "QuickSwitch_",function()
            for k,v in pairs(player.GetAll()) do
                v.QuickSwitch_ = {}
                v.Quick_Kills = 0
            end
        end)
		hook.Add("PlayerDeath", "moat_quickswitch_killer", function(ply, inf, att)
            if not att.QuickSwitch_ then return end -- Before round started
			if (att:IsValid() and att:IsPlayer()) then
				inf = att:GetActiveWeapon()
			end

			if (att:IsValid() and att:IsPlayer() and ply ~= att and WasRightfulKill(att, ply)) then
                if #att.QuickSwitch_ >= mods[3] then 
                    if table.HasValue(att.QuickSwitch_,att:GetActiveWeapon()) then 
                        att.Quick_Kills = att.Quick_Kills + 1
                    end
                else
                    table.insert(att.QuickSwitch_, att:GetActiveWeapon())
				    att.Quick_Kills = att.Quick_Kills + 1
                end
                if att.Quick_Kills >= mods[2] and #att.QuickSwitch_ >= mods[3] then
                    MOAT_BOUNTIES:IncreaseProgress(att, bountyid, mods[1])
                end
			end
		end)
	end,
	rewards = tier3_rewards_str,
	rewardtbl = tier3_rewards
})

MOAT_BOUNTIES:AddBounty("Professional Traitor", {
	tier = 3,
	desc = "In # round, eliminate a total of # innocents brutally. Can be completed as a traitor only.",
	vars = {
		1,
		math.random(8, 11)
	},
	runfunc = function(mods, bountyid)
		hook.Add("TTTBeginRound", "moat_reset_prof_traitor", function()
			for k, v in pairs(player.GetAll()) do
				v.proftraitor = 0
			end
		end)

		hook.Add("PlayerDeath", "moat_death_prof_traitor", function(ply, inf, att)
			if (att:IsValid() and att:IsPlayer() and ply ~= att and att:GetRole() == ROLE_TRAITOR and WasRightfulKill(att, ply)) then
				att.proftraitor = att.proftraitor + 1

				if (att.proftraitor == mods[2]) then
					MOAT_BOUNTIES:IncreaseProgress(att, bountyid, mods[1])
				end
			end
		end)
	end,
	rewards = tier3_rewards_str,
	rewardtbl = tier3_rewards
})

MOAT_BOUNTIES:AddBounty("Bloodthirsty Traitor", {
	tier = 3,
	desc = "Eliminate at least 5 innocents in one round, # times. Can be completed as a traitor only.",
	vars = {
		math.random(7, 14)
	},
	runfunc = function(mods, bountyid)
		hook.Add("TTTBeginRound", "moat_reset_blood_traitor", function()
			for k, v in pairs(player.GetAll()) do
				v.bloodtraitor = 0
			end
		end)

		hook.Add("PlayerDeath", "moat_death_blood_traitor", function(ply, inf, att)
			if (att:IsValid() and att:IsPlayer() and ply ~= att and att:GetRole() == ROLE_TRAITOR and WasRightfulKill(att, ply)) then
				att.bloodtraitor = att.bloodtraitor + 1

				if (att.bloodtraitor == 5) then
					MOAT_BOUNTIES:IncreaseProgress(att, bountyid, mods[1])
				end
			end
		end)
	end,
	rewards = tier3_rewards_str,
	rewardtbl = tier3_rewards
})

MOAT_BOUNTIES:AddBounty("Melee Maniac", {
	tier = 3,
	desc = "Eliminate # terrorists, rightfully, with a melee weapon as the cause of death. Can be completed as any role.",
	vars = {
		math.random(25, 35)
	},
	runfunc = function(mods, bountyid)
		hook.Add("PlayerDeath", "moat_melee_addicted", function(ply, inf, att)
			if (att:IsValid() and att:IsPlayer()) then
				inf = att:GetActiveWeapon()
			end

			if (att:IsValid() and att:IsPlayer() and ply ~= att and IsValid(inf) and inf:IsWeapon() and inf.Weapon.Kind and inf.Weapon.Kind == WEAPON_MELEE and WasRightfulKill(att, ply)) then
				MOAT_BOUNTIES:IncreaseProgress(att, bountyid, mods[1])
			end
		end)
	end,
	rewards = tier3_rewards_str,
	rewardtbl = tier3_rewards
})

MOAT_BOUNTIES:AddBounty("Double Killer", {
	tier = 3,
	desc = "Eliminate an innocent back to back with another kill # times. Can be completed as a traitor only with guns.",
	vars = {
		math.random(15, 25)
	},
	runfunc = function(mods, bountyid)
		hook.Add("PlayerDeath", "moat_double_killer", function(ply, inf, att)
			if (att:IsValid() and att:IsPlayer()) then
				inf = att:GetActiveWeapon()
			end

			if (att:IsValid() and att:IsPlayer() and ply ~= at and IsValid(inf) and inf:IsWeapon() and att:GetRole() == ROLE_TRAITOR and WasRightfulKill(att, ply)) then
				local not_applied_progress = true

				if (att.lastkilltime and ((CurTime() - 5) < att.lastkilltime)) then
					MOAT_BOUNTIES:IncreaseProgress(att, bountyid, mods[1])
					att.lastkilltime = 0
					not_applied_progress = false
				end

				if (not_applied_progress) then
					att.lastkilltime = CurTime()
				end
			end
		end)
	end,
	rewards = tier3_rewards_str,
	rewardtbl = tier3_rewards
})

MOAT_BOUNTIES:AddBounty("Airborn Assassin", {
	tier = 3,
	desc = "Eliminate # terrorists with a gun, rightfully, while airborn. Can be completed as any role.",
	vars = {
		math.random(20, 35)
	},
	runfunc = function(mods, bountyid)
		hook.Add("PlayerDeath", "moat_airborn_assassin", function(ply, inf, att)
			if (att:IsValid() and att:IsPlayer()) then
				inf = att:GetActiveWeapon()
			end

			if (att:IsValid() and att:IsPlayer() and ply ~= att and IsValid(inf) and inf:IsWeapon() and not att:IsOnGround() and att:WaterLevel() == 0 and WasRightfulKill(att, ply)) then
				MOAT_BOUNTIES:IncreaseProgress(att, bountyid, mods[1])
			end
		end)
	end,
	rewards = tier3_rewards_str,
	rewardtbl = tier3_rewards
})

MOAT_BOUNTIES:AddBounty("The A Team", {
	tier = 3,
	desc = "Win # rounds as a traitor with none of your traitor buddies dying. Can be completed as a traitor only.",
	vars = {
		math.random(1, 3),
	},
	runfunc = function(mods, bountyid)
		local traitor_died = false

		hook.Add("TTTEndRound", "moat_a_team_end", function(res)
			for k, v in pairs(player.GetAll()) do
				if (res == WIN_TRAITOR and v:GetRole() == ROLE_TRAITOR and not traitor_died) then
					MOAT_BOUNTIES:IncreaseProgress(v, bountyid, mods[1])
				end
			end
		end)

		hook.Add("TTTBeginRound", "moat_a_team_begin", function(res)
			traitor_died = false
		end)

		hook.Add("PlayerDeath", "moat_a_team_death", function(ply, inf, att)
			if (ply:GetRole() == ROLE_TRAITOR) then
				traitor_died = true
			end
		end)
	end,
	rewards = tier3_rewards_str,
	rewardtbl = tier3_rewards
})


--[[-------------------------------------------------------------------------

BOUNTY UPDATE

---------------------------------------------------------------------------]]

MOAT_BOUNTIES:AddBounty("Innocent Exterminator", {
	tier = 1,
	desc = "Exterminate # total innocents with any weapon. Can be completed as a traitor only.",
	vars = {
		math.random(20, 30),
	},
	runfunc = function(mods, bountyid)
		hook.Add("PlayerDeath", "moat_innocent_exterminator", function(ply, inf, att)
			if (att:IsValid() and att:IsPlayer() and ply ~= att and att:GetRole() == ROLE_TRAITOR and WasRightfulKill(att, ply)) then
				MOAT_BOUNTIES:IncreaseProgress(att, bountyid, mods[1])
			end
		end)
	end,
	rewards = tier1_rewards_str,
	rewardtbl = tier1_rewards
})

MOAT_BOUNTIES:AddBounty("Clutch Master", {
	tier = 3,
	desc = "Win # rounds as the last traitor alive with the most amount of kills. Can be completed as a traitor only.",
	vars = {
		math.random(1, 3),
	},
	runfunc = function(mods, bountyid)
		local traitor_died = false

		hook.Add("TTTEndRound", "moat_a_team_end", function(res)
			if (res ~= WIN_TRAITOR) then return end

			local pls = player.GetAll()
			local traitor = nil
			local traitors = 0
			for i = 1, #pls do
				if (pls[i]:Team() ~= TEAM_SPEC and pls[i]:GetRole() == ROLE_TRAITOR) then
					traitors = traitors + 1
					traitor = pls[i]
				end
			end

			if (traitors == 1 and traitor) then
				MOAT_BOUNTIES:IncreaseProgress(traitor, bountyid, mods[1])
			end
		end)
	end,
	rewards = tier3_rewards_str,
	rewardtbl = tier3_rewards
})

MOAT_BOUNTIES:AddBounty("Bunny Roleplayer", {
	tier = 1,
	desc = "In # round, jump # times. Cannot be completed with auto hop.",
	vars = {
		1,
		math.random(200, 300)
	},
	runfunc = function(mods, bountyid)
        hook.Add("TTTBeginRound", "moat_reset_steps", function()
			for k, v in pairs(player.GetAll()) do
				v.BJumps = 0
			end
		end)

		hook.Add("SetupMove", "moat_bunny_roleplayer", function(pl, mv, cmd)
			if GetRoundState() ~= ROUND_ACTIVE then return end
			if pl:Team() == TEAM_SPEC then return end

			if (not pl:IsBot() and pl:WaterLevel() == 0 and mv:KeyDown(IN_JUMP) and not pl:IsOnGround()) then
				pl.CanReceiveJump = true
			end

			if (not pl:IsBot() and pl:WaterLevel() == 0 and mv:KeyDown(IN_JUMP) and pl:IsOnGround() and pl.CanReceiveJump) then
				pl.CanReceiveJump = false

				if (not pl.BJumps) then pl.BJumps = 0 end
				pl.BJumps = pl.BJumps + 1
			end

            if pl.BJumps == mods[2] then
                MOAT_BOUNTIES:IncreaseProgress(pl, bountyid, mods[1])
            end
		end)
	end,
	rewards = tier1_rewards_str,
	rewardtbl = tier1_rewards
})

MOAT_BOUNTIES:AddBounty("An Explosive Ending", {
	tier = 3,
	desc = "With # explosion, elimite # terrorists rightfully. Can be completed as any role.",
	vars = {
		1,
		math.random(3, 4)
	},
	runfunc = function(mods, bountyid)
		hook.Add("EntityTakeDamage", "moat_explosive_ending", function(targ, dmg)
			local att = dmg:GetAttacker()

			if (targ:IsPlayer() and att:IsValid() and att:IsPlayer() and targ ~= att and WasRightfulKill(att, targ) and dmg:IsExplosionDamage() and dmg:GetDamage() >= targ:Health()) then
				if (att.LastExplosiveKill and att.LastExplosiveKill > CurTime() - 2) then
					if (not att.TotalExplosiveKills) then att.TotalExplosiveKills = 0 end
					att.TotalExplosiveKills = att.TotalExplosiveKills + 1

					if (att.TotalExplosiveKills >= mods[2]) then
						MOAT_BOUNTIES:IncreaseProgress(att, bountyid, mods[1])
					end
				else
					att.TotalExplosiveKills = 1
				end

				att.LastExplosiveKill = CurTime()
			end
		end)
	end,
	rewards = tier3_rewards_str,
	rewardtbl = tier3_rewards
})

function MOAT_BOUNTIES:LoadBounties()
	local bounties = sql.Query("SELECT * FROM bounties_current" .. self.DatabasePrefix)

	if (not bounties) then return end
	
	local bounties_row = bounties[1]

	for i = 1, 3 do
		local tbl = util.JSONToTable(bounties_row["bounty" .. i])
		local bounty = self.Bounties[tbl.id]

		if (bounty.runfunc) then
			bounty.runfunc(tbl.mods, tbl.id)
		end

		self.ActiveBounties[i] = {bnty = bounty, mods = tbl.mods}

		MsgC(Color(0, 255, 0), "Daily Bounty with ID " .. tbl.id .. " has Loaded.\n")
	end
end

function MOAT_BOUNTIES:GetBountyVariables(bounty_id)
	local tbl = {}
	local possible_vars = self.Bounties[bounty_id].vars

	for i = 1, #possible_vars do
		tbl[i] = possible_vars[i]
	end

	return tbl
end

function MOAT_BOUNTIES:GetRandomBounty(tier_)
	local bounty_tbl = {}

	if (tier_ ~= 1) then
		for k, v in RandomPairs(self.Bounties) do
			if (v.tier == tier_) then 
				bounty_tbl.id = k
				bounty_tbl.mods = self:GetBountyVariables(k)

				break
			end
		end
	else
		local tier1_bounty = math.random(1, 2)

		if (tier1_bounty == 1) then
			for k, v in RandomPairs(self.Bounties) do
				if (v.tier == tier_) then 
					bounty_tbl.id = k
					bounty_tbl.mods = self:GetBountyVariables(k)

					break
				end
			end
		else
			local random_num = math.random(1, 3)

			if (random_num == 1) then
				bounty_tbl.id = 26
				bounty_tbl.mods = self:GetBountyVariables(26)

			elseif (random_num == 2) then
				bounty_tbl.id = 27
				bounty_tbl.mods = self:GetBountyVariables(27)
			else
				bounty_tbl.id = 28
				bounty_tbl.mods = self:GetBountyVariables(28)
			end
		end
	end

	return sql.SQLStr(util.TableToJSON(bounty_tbl), true)
end

function game.GetIP()

    local hostip = GetConVarString( "hostip" ) -- GetConVarNumber is inaccurate
    hostip = tonumber( hostip )

    local ip = {}
    ip[ 1 ] = bit.rshift( bit.band( hostip, 0xFF000000 ), 24 )
    ip[ 2 ] = bit.rshift( bit.band( hostip, 0x00FF0000 ), 16 )
    ip[ 3 ] = bit.rshift( bit.band( hostip, 0x0000FF00 ), 8 )
    ip[ 4 ] = bit.band( hostip, 0x000000FF )

    return table.concat( ip, "." ) .. ":" .. GetConVarString("hostport")
end

function MOAT_BOUNTIES.ResetBounties()
	sql.Query("DROP TABLE bounties_current" .. MOAT_BOUNTIES.DatabasePrefix)
	sql.Query("DROP TABLE bounties_save" .. MOAT_BOUNTIES.DatabasePrefix)

	MOAT_BOUNTIES.CreateTable("bounties_current" .. MOAT_BOUNTIES.DatabasePrefix, "CREATE TABLE IF NOT EXISTS bounties_current" .. MOAT_BOUNTIES.DatabasePrefix .. " (bounty1 TEXT NOT NULL, bounty2 TEXT NOT NULL, bounty3 TEXT NOT NULL)")
	MOAT_BOUNTIES.CreateTable("bounties_save" .. MOAT_BOUNTIES.DatabasePrefix, "CREATE TABLE IF NOT EXISTS bounties_save" .. MOAT_BOUNTIES.DatabasePrefix .. " (steamid VARCHAR(30) NOT NULL PRIMARY KEY, bounty1 INTEGER NOT NULL, bounty2 INTEGER NOT NULL, bounty3 INTEGER NOT NULL)")


	local bounty1 = MOAT_BOUNTIES:GetRandomBounty(1)
	local bounty2 = MOAT_BOUNTIES:GetRandomBounty(2)
	local bounty3 = MOAT_BOUNTIES:GetRandomBounty(3)

	for i = 1, 3 do
		sql.Query(string.format("INSERT INTO bounties_current" .. MOAT_BOUNTIES.DatabasePrefix .. " (bounty1, bounty2, bounty3) VALUES ('%s', '%s', '%s')", bounty1, bounty2, bounty3))
	end

	sql.Query("UPDATE bounties_refresh" .. MOAT_BOUNTIES.DatabasePrefix .. " SET shouldrefresh = 'false'")

	MOAT_BOUNTIES:LoadBounties()

	local url = "https://discordapp.com/api/webhooks/406539243909939200/6Uhyh9_8adif0a5G-Yp06I-SLhIjd3gUzFA_QHzCViBlrLYcoqi4XpFIstLaQSal93OD"
	local s = "|\nDaily bounties of **" .. os.date("%B %d, %Y",os.time()) .. "**:\nServer: **" .. GetHostName() .. "** (" .. game.GetIP() .. ")\n```"
	for i = 1,3 do
		local bounty = MOAT_BOUNTIES.ActiveBounties[i].bnty
		local mods = MOAT_BOUNTIES.ActiveBounties[i].mods
		local bounty_desc = bounty.desc
		local c = 0
		for i = 1, #mods do
			bounty_desc = bounty_desc:gsub("#", function() c = c + 1 return mods[c] end)
		end
		s = s .. [[]] .. bounty.name .. "\n---------------------\n" .. bounty_desc .. "\n---------------------\nRewards: " .. bounty.rewards .. "\n\n\n\n"
		
	end
	s = s .. "```"
	SVDiscordRelay.SendToDiscordRaw("Bounties",nil,s,url)
end

function MOAT_BOUNTIES.InitializeBounties()

	local check = sql.Query("SELECT * FROM bounties_refresh" .. MOAT_BOUNTIES.DatabasePrefix)

	if (check == nil) then
		sql.Query("INSERT INTO bounties_refresh" .. MOAT_BOUNTIES.DatabasePrefix .. " (shouldrefresh) VALUES ('true')")
		check = {shouldrefresh = "true"}
	end

	local datime = os.date("!*t", (os.time() - 21600 - 3600))

    local hr = 24 - datime.hour
    local load_bounties = true

    -- pray to god the server doesn't die
    if (hr >= 8) then
    	if (check[1].shouldrefresh == "true") then
    		load_bounties = false
    		MOAT_BOUNTIES.ResetBounties()
    	end
    else
    	if (check[1].shouldrefresh == "false") then
    		sql.Query("UPDATE bounties_refresh" .. MOAT_BOUNTIES.DatabasePrefix .. " SET shouldrefresh = 'true'")
    	end
    end

    if (load_bounties) then
    	MOAT_BOUNTIES:LoadBounties()
    end

    SetGlobalFloat("moat_bounties_refresh_next", false)

    local datime = os.date("!*t", (os.time() - 21600 - 3600))
    
    if (datime.hour == 0) then datime.hour = 24 end

    local hr = 24 - datime.hour
    local min = 60 - datime.min
    local sec = 60 - datime.sec

    if (hr == 0 and min == 0 and sec == 1) then
    	SetGlobalFloat("moat_bounties_refresh_next", true)
    end

    timer.Create("moat_bounties_refresh_check", 1, 0, function()
    	local datime = os.date("!*t", (os.time() - 21600 - 3600))

    	if (datime.hour == 0) then datime.hour = 24 end

    	local hr = 24 - datime.hour
    	local min = 60 - datime.min
    	local sec = 60 - datime.sec

    	if (hr == 0 and min == 0 and sec == 1) then
    		SetGlobalFloat("moat_bounties_refresh_next", true)
    	end
    end)
end
MOAT_BOUNTIES.InitializeBounties()

function MOAT_BOUNTIES:SendBountyToPlayer(ply, bounty, mods, current_progress)

	local bounty_desc = bounty.desc
	local c = 0

	for i = 1, #mods do
		bounty_desc = bounty_desc:gsub("#", function() c = c + 1 return mods[c] end)
	end

    net.Start("moat_bounty_send")
    net.WriteUInt(bounty.tier, 4)
    net.WriteString(bounty.name)
    net.WriteString(bounty_desc)
    net.WriteString(bounty.rewards)
    net.WriteUInt(current_progress, 16)
    net.WriteUInt(mods[1], 16)
	net.Send(ply)
end

function MOAT_BOUNTIES.PlayerInitialSpawn(ply)
	if (ply:IsBot() or not ply:SteamID64()) then return end
	
	local check = sql.Query(string.format("SELECT * FROM bounties_save" .. MOAT_BOUNTIES.DatabasePrefix .. " WHERE steamid = %s", ply:SteamID64()))
	local bounties_cur = {0, 0, 0}

	if (not check) then
		sql.Query(string.format("INSERT INTO bounties_save" .. MOAT_BOUNTIES.DatabasePrefix .. " (steamid, bounty1, bounty2, bounty3) VALUES('%s', %s, %s, %s)", ply:SteamID64(), 0, 0, 0))
	else
		local data = sql.Query(string.format("SELECT * FROM bounties_save" .. MOAT_BOUNTIES.DatabasePrefix .. " WHERE steamid = %s", ply:SteamID64()))

		for i = 1, 3 do
			bounties_cur[i] = data[1]["bounty" .. i]
		end
	end

	for i = 1, 3 do
		local bounty = MOAT_BOUNTIES.ActiveBounties[i]
		if (not bounty) then continue end

		MOAT_BOUNTIES:SendBountyToPlayer(ply, bounty.bnty, bounty.mods, bounties_cur[i])
	end
end
hook.Add("PlayerInitialSpawn", "moat_bounties_insert_player", MOAT_BOUNTIES.PlayerInitialSpawn)

net.Receive("moat_bounty_reload", function(l, ply)
	if (ply:IsValid()) then
		MOAT_BOUNTIES.PlayerInitialSpawn(ply)	
	end
end)

concommand.Add("moat_reset_bounties", function(ply, cmd, args)
	if (ply ~= NULL and ply:SteamID() ~= "STEAM_0:0:46558052") then return end

	MOAT_BOUNTIES.ResetBounties()
end)

function m_DropIndiCrate(ply, amt)
	for i = 1, amt do
		ply:m_DropInventoryItem("Independence Crate")
	end
end