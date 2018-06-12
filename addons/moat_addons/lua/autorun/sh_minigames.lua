MOAT_MINIGAMES = MOAT_MINIGAMES or {}
MOAT_MINIGAMES.Minigames = {}
MOAT_MINIGAME_OCCURING = false
MOAT_MINIGAMES.Print = function(s)
	MsgC(Color(0, 0, 0), "[", Color(255, 0, 0), "Moat Minigames", Color(0, 0, 0), "]", Color(0, 255, 255), s, "\n" )
end
MOAT_MINIGAMES.CantEnd = function()
	return (GetRoundState() == ROUND_PREP)
end
MOAT_MINIGAMES.AddMinigame = function(pname, dir, cmd, chance, desc)
	if (SERVER) then
		AddCSLuaFile(dir .. "m_cl.lua")
		include(dir .. "m_sv.lua")
	else
		include(dir .. "m_cl.lua")
	end

	MOAT_MINIGAMES.Print(pname)
	MOAT_MINIGAMES.Print(desc)
	MOAT_MINIGAMES.Print("1 in " .. chance .. " Chance")
	MOAT_MINIGAMES.Print("-----------------------------------------")

	MOAT_MINIGAMES.Minigames[#MOAT_MINIGAMES.Minigames + 1] = {pname, chance, cmd, desc}
end

MOAT_MINIGAMES.AddMinigame("Deathclaw Round", 
	"minigames/deathclaw/", 
	"moat_start_boss", 
	500, 
	"Team up with other players to defeat the boss and receive a prize only if you win!"
)
MOAT_MINIGAMES.AddMinigame("Apache Round", 
	"minigames/apache/", 
	"moat_start_apache", 
	500, 
	"Team up with other players to defeat the apache and receive a prize only if you win!"
)
MOAT_MINIGAMES.AddMinigame("Dragon Round", 
	"minigames/dragon/", 
	"moat_start_dragon", 
	500, 
	"Team up with other players to defeat the dragon and receive a prize only if you win!"
)

MOAT_MINIGAMES.AddMinigame("Team Deathmatch Round", 
	"minigames/tdm/", 
	"moat_start_tdm", 
	350, 
	"Team deathmatch is a fight between two teams, first team to get all kills, wins."
)

MOAT_MINIGAMES.AddMinigame("Free For All Round", 
	"minigames/ffa/", 
	"moat_start_ffa", 
	350, 
	"Like TDM, But it's free for all! Everyone must use the same gun."
)


MOAT_MINIGAMES.AddMinigame("Gun Game Round", 
	"minigames/gungame/", 
	"moat_start_gungame", 
	350, 
	"A gun game event."
)

MOAT_MINIGAMES.AddMinigame("One in the Chamber", 
	"minigames/onechamber/", 
	"moat_start_onechamber", 
	350, 
	"The class, single bullet, kill for ammo, last man standing."
)

MOAT_MINIGAMES.AddMinigame("Contagion Round", 
	"minigames/contagion/", 
	"moat_start_contagion", 
	250, 
	"Fight to become the last survivor."
)

MOAT_MINIGAMES.AddMinigame("Stalker Round", 
	"minigames/stalker/", 
	"moat_start_stalker", 
	10, 
	"Run from the stalker while trying to collect easter eggs. Kill him to win!"
)

MOAT_MINIGAMES.AddMinigame("Explosive Chickens", 
	"minigames/chickens/", 
	"moat_start_chickens", 
	10, 
	"Expoding chickens will spawn on you. Be the last alive to win!!"
)

MOAT_MINIGAMES.AddMinigame("The floor is lava", 
	"minigames/tfil/", 
	"moat_start_lava", 
	0, 
	"The floor is lava."
)

MOAT_MINIGAMES.AddMinigame("TNT Tag", 
	"minigames/tnt/", 
	"moat_start_tnt", 
	0, 
	"TNT Tag! The person holding the tnt eventually dies, and you can throw stuff at him to make him die faster!" --s
)
/*
MOAT_MINIGAMES.AddMinigame("Secret Santa Tag", 
	"minigames/hot_santa/", 
	"moat_start_hs", 
	0, 
	""
)

MOAT_MINIGAMES.AddMinigame("Secret Santa FFA", 
	"minigames/ffa_santa/", 
	"moat_start_ffas", 
	0, 
	""
)*/

MOAT_MINIGAMES.AddMinigame("Prop Hunt", 
	"minigames/ph/", 
	"moat_start_ph", 
	0, 
	"Prop hunt" --s
)

if (CLIENT) then
--s
	net.Receive("Minigame Chat", function(len)
		local str = net.ReadString()
		chat.AddText(Material("icon16/information.png"), Color(0, 0, 0), "[", Color(255, 0, 0), "Moat Minigames", Color(0, 0, 0), "]", Color(0, 255, 255), str)
	end)

	return
end

util.AddNetworkString("Minigame Chat")

MOAT_MINIGAMES.Chat = function(ply, str)
	if (ply == "all") then
		net.Start("Minigame Chat")
		net.WriteString(str)
		net.Broadcast()
	else
		net.Start("Minigame Chat")
		net.WriteString(str)
		net.Send(ply)
	end
end

-- this is just a way to not log damage during minigames
-- causes people to crash after one has finished and a player opens them
-- due to sending too much data
-- just set IsGhost to true on players and set back to false when minigame is over

-- random starting will be here, haven't added it yet lol