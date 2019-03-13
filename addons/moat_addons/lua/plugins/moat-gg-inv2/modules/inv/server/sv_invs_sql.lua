require("mysqloo")

MINVENTORY_MYSQL = mi.SQL and mi.SQL.mysqloo
local SQL = mi.SQL

hook.Add("InventoryPrepare", "MINVENTORY_MYSQL", function()
	MINVENTORY_MYSQL = mi.SQL.mysqloo -- TODO: REMOVE!!!
	SQL = mi.SQL
	MINVENTORY_CONNECTED = true
	print("Connected to Database.")
end)

hook.Add("SQLConnectionFailed", "MINVENTORY_MYSQL", function(db)
	MINVENTORY_CONNECTED = false
end)

function m_InsertCompTicket(c, cb, cbf)
	local q = MINVENTORY_MYSQL:query("INSERT INTO moat_comps ( time, steamid, admin, link, ic, ec, item, class, talent1, talent2, talent3, talent4, comment, approved ) VALUES ( UNIX_TIMESTAMP(), '" .. MINVENTORY_MYSQL:escape(util.SafeSteamID(c.steamid)) .. "', '" .. MINVENTORY_MYSQL:escape(c.admin) .. "', '" .. MINVENTORY_MYSQL:escape(c.ticket) .. "', '" .. MINVENTORY_MYSQL:escape(c.ic) .. "', '" .. MINVENTORY_MYSQL:escape(c.ec) .. "', '" .. MINVENTORY_MYSQL:escape(c.item) .. "', '" .. MINVENTORY_MYSQL:escape(c.class) .. "', '" .. MINVENTORY_MYSQL:escape(c.talent1) .. "', '" .. MINVENTORY_MYSQL:escape(c.talent2) .. "', '" .. MINVENTORY_MYSQL:escape(c.talent3) .. "', '" .. MINVENTORY_MYSQL:escape(c.talent4) .. "', '" .. MINVENTORY_MYSQL:escape(c.comments) .. "', '0')")

	function q:onSuccess(data)
		cb(data)
	end

	function q:onError(err)
		cbf(err)
	end

	q:start()
end

function m_CloseCompTicket(id)
	local q = MINVENTORY_MYSQL:query("UPDATE moat_comps SET approved = '4' WHERE ID = " .. id)

	function q:onError(err)
		if (tonumber(MINVENTORY_MYSQL:status()) == 2) then
			timer.Simple(1, m_CloseCompTicket(id))
		end
	end

	q:start()
end

function MoatLog(msg)
	local q = MINVENTORY_MYSQL:query("INSERT INTO moat_logs (time, message) VALUES (UNIX_TIMESTAMP(), '" .. MINVENTORY_MYSQL:escape(msg) .. "')")

	function q:onError(err)
		if (tonumber(MINVENTORY_MYSQL:status()) == 2) then
			timer.Simple(1, MoatLog(msg))
		end
	end

	q:start()
end

function m_CheckCompTickets(pl)
	local q = MINVENTORY_MYSQL:query("SELECT * FROM `moat_comps` WHERE (REGEXP_REPLACE(`steamid`, '[^a-z0-9_:]+', '') LIKE '" .. MINVENTORY_MYSQL:escape(pl:SteamID()).. "' AND `approved` LIKE '2')")
	function q:onSuccess(d)
		if (#d > 0) then

			for i = 1, #d do
				local tbl = d[i]

				if (tbl.ec and #tbl.ec >= 1) then
					timer.Simple(15, function()
						give_ec(pl, tonumber(tbl.ec))

						net.Start("moat.comp.chat")
						net.WriteString("You have received " .. tbl.ec .. " event credit(s) from a compensation ticket! <3")
						net.WriteBool(false)
						net.Send(pl)

						m_CloseCompTicket(tbl.ID)
					end)

					continue
				end

				local class = tbl.class
				local talents = false
				local comp_msg = "There was an issue giving you something for your compensation ticket!"

				if (tbl.class and #tbl.class > 1) then
					for k, v in RandomPairs(weapons.GetList()) do
						local name = v.PrintName or "Unknown"

						if (name:EndsWith("_name")) then
							name = name:sub(1, name:len() - 5)
							name = name:sub(1, 1):upper() .. name:sub(2, name:len())
						end

						if (name == class) then
							class = v.ClassName
							break
						end
					end
				else
					class = "endrounddrop"
				end

				if (tbl.talent1 and #tbl.talent1 > 1) then
					talents = {
						tbl.talent1,
						(#tbl.talent2 > 1 and tbl.talent2) or nil,
						(#tbl.talent3 > 1 and tbl.talent3) or nil,
						(#tbl.talent4 > 1 and tbl.talent4) or nil
					}
				end
				
				if (tbl.item and #tbl.item > 1) then
					pl:m_DropInventoryItem(tbl.item, class, true, false, true, talents)

					comp_msg = "You have received a " .. tbl.item .. " " .. class .. " from a compensation ticket! <3"
				end

				if (tbl.ic and #tbl.ic > 0) then
					pl:m_GiveIC(tonumber(tbl.ic))

					comp_msg = "You have received " .. tbl.ic .. " inventory credits from a compensation ticket! <3"
				end
				
				m_SaveInventory(pl)
				m_CloseCompTicket(tbl.ID)

				net.Start("moat.comp.chat")
				net.WriteString(comp_msg)
				net.WriteBool(false)
				net.Send(pl)
			end
		end
	end

	q:start()
end

--[[-------------------------------------------------------------------------
Velkon Code
---------------------------------------------------------------------------]]

function m_getTradeHistorySid(steamid, fun)
	local query1 = MINVENTORY_MYSQL:query("SELECT * FROM moat_trades WHERE my_steamid = '" .. MINVENTORY_MYSQL:escape(steamid) .. "' OR their_steamid = '" .. MINVENTORY_MYSQL:escape(steamid) .. "'") --SELECT * FROM moat_trades WHERE my_steamid = '76561198053381832' OR their_steamid = '76561198053381832'

	function query1:onSuccess(data)
		if (#data > 0) then
			--PrintTable(data)
			/*for k,v in pairs(data) do
				--PrintTable(v)
				local row = data[k]
				local tradetbl = util.JSONToTable(row["trade_tbl"])
				--PrintTable(tradetbl)
				--PrintTable(tradetbl)
			end*/
			fun(data)
		else
			fun({})
		end
	end

	query1:start()
end

function m_getTradeHistoryNick(nick, fun)
	nick = nick:lower()
	local query1 = MINVENTORY_MYSQL:query("SELECT * FROM moat_trades WHERE my_nick LIKE '%" .. MINVENTORY_MYSQL:escape(nick) .. "%' OR their_nick LIKE '%" .. MINVENTORY_MYSQL:escape(nick) .. "%'")

	function query1:onSuccess(data)
		if (#data > 0) then
			--PrintTable(data)
			/*for k,v in pairs(data) do
				--PrintTable(v)
				local row = data[k]
				local tradetbl = util.JSONToTable(row["trade_tbl"])
				--PrintTable(tradetbl)
				--PrintTable(tradetbl)
			end*/
			fun(data)
		else
			fun({})
		end
	end

	query1:start()
end

function m_getSearchTradesStaff(str, cb)
	local q = MINVENTORY_MYSQL:query("SELECT * FROM moat_trades WHERE (my_nick LIKE '%" .. MINVENTORY_MYSQL:escape(str) .. "%' OR their_nick LIKE '%" .. MINVENTORY_MYSQL:escape(str) .. "%' OR my_steamid = '" .. MINVENTORY_MYSQL:escape(str) .. "' OR their_steamid = '" .. MINVENTORY_MYSQL:escape(str) .. "' OR ID = '" .. MINVENTORY_MYSQL:escape(str) .. "')")
	function q:onSuccess(d)
		if (#d > 0) then
			cb(d)
		else
			cb({})
		end
	end

	function q:onError(d)
		ServerLog("Trade Logs SQL Error: " .. d .. "\n")
		if (tonumber(MINVENTORY_MYSQL:status()) == 2) then
			timer.Simple(1, function() m_getSearchTradesStaff(str, cb) end)
		end
	end

	q:start()
end

function m_getSearchTradesReg(str, id, cb)
	local q = MINVENTORY_MYSQL:query("SELECT * FROM moat_trades WHERE (my_nick LIKE '%" .. MINVENTORY_MYSQL:escape(str) .. "%' OR their_nick LIKE '%" .. MINVENTORY_MYSQL:escape(str) .. "%' OR my_steamid = '" .. MINVENTORY_MYSQL:escape(str) .. "' OR their_steamid = '" .. MINVENTORY_MYSQL:escape(str) .. "' OR ID = '" .. MINVENTORY_MYSQL:escape(str) .. "') AND (my_steamid = '" .. id .. "' OR their_steamid = '" .. id .. "')")
	function q:onSuccess(d)
		if (#d > 0) then
			cb(d)
		else
			cb({})
		end
	end

	function q:onError(d)
		ServerLog("Trade Logs SQL Error: " .. d .. "\n")
		if (tonumber(MINVENTORY_MYSQL:status()) == 2) then
			timer.Simple(1, function() m_getSearchTradesReg(str, id, cb) end)
		end
	end

	q:start()
end

function m_saveTrade(steamid, mynick, theirsid, theirnick, tbl)
	mynick = mynick:lower()
	theirnick = theirnick:lower()
	-- secret santa's steamid64 to stop people from using trade logs to search the account's trade history and spoil the gifts
	if (steamid == "76561198069382821" or theirsid == "76561198069382821") then return end
	local trade = MINVENTORY_MYSQL:escape(util.TableToJSON(tbl), true)

	sq = MINVENTORY_MYSQL:query("INSERT INTO moat_trades ( time, my_steamid, my_nick, their_steamid, their_nick, trade_tbl ) VALUES ( UNIX_TIMESTAMP(), '" .. steamid .. "', '" .. MINVENTORY_MYSQL:escape(mynick) .. "', '" .. theirsid .. "', '" .. MINVENTORY_MYSQL:escape(theirnick) .. "', '" .. trade .. "' )")
	sq:start()

	function sq:onError(err)
		if (tonumber(MINVENTORY_MYSQL:status()) == 2) then
			timer.Simple(1, function() m_saveTrade(steamid, mynick, theirsid, theirnick, tbl) end)
		end
	end
end

--[[-------------------------------------------------------------------------
/Velkon Code
---------------------------------------------------------------------------]]


function m_SaveRollItem(steamid, tbl)
	local item_save = sql.SQLStr(util.TableToJSON(tbl), true)
	sq = MINVENTORY_MYSQL:query("INSERT INTO moat_rollsave ( steamid, item_tbl ) VALUES ( '" .. steamid .. "', '" .. item_save .. "' )")
	sq:start()

	function sq:onError(err)
		ServerLog(err)
	end
end

function m_RemoveRollSave(steamid)
	sq = MINVENTORY_MYSQL:query("DELETE FROM moat_rollsave WHERE steamid = '" .. steamid .. "'")
	sq:start()

	function sq:onError(err)
		ServerLog(err)
	end
end

function m_CheckForRollSave(ply)
	local query1 = MINVENTORY_MYSQL:query("SELECT * FROM moat_rollsave WHERE steamid = '" .. ply:SteamID() .. "'")

	function query1:onSuccess(data)
		if (#data > 0) then
			local row = data[1]
			local itemtbl = util.JSONToTable(row["item_tbl"])
			itemtbl.item = m_GetItemFromEnum(itemtbl.u)

			if (itemtbl.w) then
				m_RemoveRollSave(ply:SteamID())
				ply:m_DropInventoryItem(itemtbl.item.Name, itemtbl.w)
			else
				m_RemoveRollSave(ply:SteamID())
				ply:m_DropInventoryItem(itemtbl.item.Name)
			end

			m_RemoveRollSave(ply:SteamID())
		end
	end

	query1:start()
end

if (not MOAT_INVS) then
	MOAT_INVS = {}
end

net.Receive("Moat.SendInvItem", function(len, ply)
	mi.SendInventoryToPlayer(ply)
end)

MOAT_CREDSAVE = MOAT_CREDSAVE or {}
function m_SendCreditsToPlayer(ply)
	local ply_creds = table.Copy(MOAT_INVS[ply]["credits"])
	net.Start("Moat.SendCredits")
	net.WriteDouble(ply_creds.c)
	net.Send(ply)

	if (not ply:SteamID64()) then return end
	MOAT_CREDSAVE[ply:SteamID64()] = ply_creds.c
end

function m_SaveCredits(ply)
	if (not ply or not ply:IsValid()) then return end
	
	local ply_creds = table.Copy(MOAT_INVS[ply]["credits"])
	local _credits = sql.SQLStr(util.TableToJSON(ply_creds), true)
	csq = MINVENTORY_MYSQL:query("UPDATE " .. mi.Config.OldInvTable .. " SET credits='" .. _credits .. "' WHERE steamid='" .. ply:SteamID() .. "'")
	csq:start()

	function csq:onError(err)
		if (tonumber(MINVENTORY_MYSQL:status()) == mysqloo.DATABASE_NOT_CONNECTED) then
			MINVENTORY_MYSQL:connect()
			timer.Simple(1, function() m_SaveCredits(ply) end)
			--MINVENTORY_MYSQL:wait()

			--m_SaveCredits(ply)
		end
	end

	m_SendCreditsToPlayer(ply)

	if (not ply:SteamID64()) then return end
	MOAT_CREDSAVE[ply:SteamID64()] = ply_creds.c
end

function m_SetCreditsSteamID(_credits, _steamid)
	csq = MINVENTORY_MYSQL:query("UPDATE " .. mi.Config.OldInvTable .. " SET credits='" .. _credits .. "' WHERE steamid='" .. _steamid .. "'")
	csq:start()

	function csq:onError(err)
		ServerLog(err)
	end
end

function m_AddCreditsToSteamID(_steamid, num_credits)
	local player_found = false

	for k, v in pairs(player.GetAll()) do
		if (v:SteamID() == _steamid) then
			v:m_GiveIC(num_credits)
			player_found = true
			break
		end
	end

	if (player_found) then return end

	local player_cur_credits = {
		c = 0
	}

	local query1 = MINVENTORY_MYSQL:query("SELECT * FROM " .. mi.Config.OldInvTable .. " WHERE steamid = '" .. _steamid .. "'")

	function query1:onSuccess(data)
		if (#data > 0) then
			local row = data[1]
			player_cur_credits = util.JSONToTable(row["credits"])
			local new_credits = player_cur_credits.c + num_credits

			local new_credit_table = {
				c = new_credits
			}

			local ply_creds = table.Copy(new_credit_table)
			local _credits = sql.SQLStr(util.TableToJSON(ply_creds), true)
			m_SetCreditsSteamID(_credits, _steamid)
		end
	end

	query1:start()
end

net.Receive("Moat.SendCredits", function(len, ply)
	m_SendCreditsToPlayer(ply)
end)

function m_InsertNewInventoryPlayer(ply)
	local _steamid = sql.SQLStr(ply:SteamID(), true)
	local _maxslots = 40

	local cred_table = {
		c = 0
	}

	local _credits = util.TableToJSON(cred_table)
	local comma = ","
	local fse = ""

	for i = 1, 10 do
		fse = fse .. " l_slot" .. tostring(i) .. comma
	end

	fse = fse .. " inventory"
	local eslot = util.TableToJSON({})
	local eslot2 = {}

	for i = 1, 40 do
		eslot2[i] = {}
	end

	local fs = string.format("INSERT INTO " .. mi.Config.OldInvTable .. " ( steamid, max_slots, credits, " .. fse .. " ) VALUES ( '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s' )", _steamid, _maxslots, _credits, eslot, eslot, eslot, eslot, eslot, eslot, eslot, eslot, eslot, eslot, util.TableToJSON(eslot2))
	iq = MINVENTORY_MYSQL:query(fs)
	iq:start()
	ply:SetNWInt("MOAT_MAX_INVENTORY_SLOTS", 40)

	local inventory_tbl = {
		{
			c = math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99),
			u = 0,
			s = {},
			w = "weapon_zm_improvised"
		},
		{
			c = math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99),
			u = 0,
			s = {},
			w = "weapon_zm_revolver"
		},
		{
			c = math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99),
			u = 0,
			s = {},
			w = "weapon_zm_pistol"
		},
		{
			c = math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99),
			u = 0,
			s = {},
			w = "weapon_zm_mac10"
		},
		{
			c = math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99),
			u = 0,
			s = {},
			w = "weapon_zm_rifle"
		},
		{
			c = math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99),
			u = 0,
			s = {},
			w = "weapon_zm_shotgun"
		},
		{
			c = math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99),
			u = 0,
			s = {},
			w = "weapon_zm_sledge"
		},
		{
			c = math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99),
			u = 0,
			s = {},
			w = "weapon_ttt_ak47"
		},
		{
			c = math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99),
			u = 0,
			s = {},
			w = "weapon_ttt_glock"
		},
		{
			c = math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99),
			u = 0,
			s = {},
			w = "weapon_ttt_m16"
		},
		{
			c = math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99),
			u = 0,
			s = {},
			w = "weapon_ttt_sg552"
		},
		{
			c = math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99),
			u = 0,
			s = {},
			w = "weapon_ttt_shotgun"
		},
		{
			c = math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99),
			u = 0,
			s = {},
			w = "weapon_ttt_galil"
		},
		{
			c = math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99),
			u = 0,
			s = {},
			w = "weapon_ttt_aug"
		},
		{
			c = math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99),
			u = 22,
			s = {}
		},
		{
			c = math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99),
			u = 22,
			s = {}
		},
		{
			c = math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99),
			u = 22,
			s = {}
		},
		{
			c = math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99),
			u = 22,
			s = {}
		},
		{
			c = math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99) .. math.random(99),
			u = 22,
			s = {}
		}
	}

	local inv_tbl = {}

	inv_tbl["credits"] = {
		c = 0
	}

	for i = 1, 10 do
		inv_tbl["l_slot" .. i] = {}
	end

	for i = 1, #inventory_tbl do
		inv_tbl["slot" .. i] = inventory_tbl[i]
	end

	for i = #inventory_tbl + 1, 40 do
		inv_tbl["slot" .. i] = {}

		if (i == ply:GetNWInt("MOAT_MAX_INVENTORY_SLOTS")) then
			MOAT_INVS[ply] = inv_tbl
			mi.SendInventoryToPlayer(ply)
		end
	end

	m_SendCreditsToPlayer(ply)
	m_SaveInventory(ply)
end

function m_InsertNewStatsPlayer(ply)
	local _steamid = sql.SQLStr(ply:SteamID(), true)

	local stats_table = {
		x = 0,
		l = 1,
		o = 0,
		r = 0,
		k = 0,
		d = 0
	}

	m_InitStatsToPlayer(ply, stats_table)
	stats_table = sql.SQLStr(util.TableToJSON(stats_table), true)
	local fs = string.format("INSERT INTO moat_stats ( steamid, stats_tbl ) VALUES ( '%s', '%s' )", _steamid, stats_table)
	iq = MINVENTORY_MYSQL:query(fs)
	iq:start()
end

function m_SaveInventory(ply)
	if (true) then return end
	if (not ply or not ply:IsValid()) then return end
	
	local ply_inv = table.Copy(MOAT_INVS[ply])
	local string1 = ""
	local comma1 = "',"
	
	if (not ply_inv) then return end
	
	local stop = false
	for i = 1, 10 do
		if (ply_inv["l_slot" .. i] and ply_inv["l_slot" .. i].item) then ply_inv["l_slot" .. i].item = nil end
		if (ply_inv["l_slot" .. i] and ply_inv["l_slot" .. i].Talents) then ply_inv["l_slot" .. i].Talents = nil end

		local str = sql.SQLStr(util.TableToJSON(ply_inv["l_slot" .. i]), true)
		if (not str or str == "nil") then stop = true break end
		string1 = string1 .. "l_slot" .. tostring(i) .. "='" .. str .. comma1
	end
	
	if (stop) then MsgC(Color(0, 255, 0), "COULDNT SAVE inventory for " .. ply:Nick() .. "\n") return end

	local inventory_table = {}

	for i = 1, ply:GetNWInt("MOAT_MAX_INVENTORY_SLOTS") do
		if (ply_inv["slot" .. i] and ply_inv["slot" .. i].item) then ply_inv["slot" .. i].item = nil end
		if (ply_inv["slot" .. i] and ply_inv["slot" .. i].Talents) then ply_inv["slot" .. i].Talents = nil end

		table.insert(inventory_table, ply_inv["slot" .. i])
	end

	string1 = string1 .. "inventory='" .. sql.SQLStr(util.TableToJSON(inventory_table), true) .. "'"
	sq = MINVENTORY_MYSQL:query("UPDATE " .. mi.Config.OldInvTable .. " SET " .. string1 .. " WHERE steamid='" .. ply:SteamID() .. "'")
	sq:start()

	function sq:onError(err)
		if (tonumber(MINVENTORY_MYSQL:status()) == mysqloo.DATABASE_NOT_CONNECTED) then
			MINVENTORY_MYSQL:connect()
			timer.Simple(1, function() m_SaveInventory(ply) end)
			--MINVENTORY_MYSQL:wait()

			--m_SaveInventory(ply)
		end
	end

	MsgC(Color(0, 255, 0), "Inventory saved for " .. ply:Nick() .. "\n")
end

function m_SaveMaxSlots(ply)
	if (true) then return end
	
	local ply_inv = table.Copy(MOAT_INVS[ply])

	if (not ply_inv or (ply_inv and not ply_inv["slot1"])) then
		return
	end

	local max_slots = ply:GetMaxSlots() or 40
	local string1 = "max_slots=" .. max_slots
	sq = MINVENTORY_MYSQL:query("UPDATE " .. mi.Config.OldInvTable .. " SET " .. string1 .. " WHERE steamid='" .. ply:SteamID() .. "'")
	sq:start()

	function sq:onError(err)
		if (tonumber(MINVENTORY_MYSQL:status()) == mysqloo.DATABASE_NOT_CONNECTED) then
			MINVENTORY_MYSQL:connect()
			timer.Simple(1, function() m_SaveMaxSlots(ply) end)
			--MINVENTORY_MYSQL:wait()
			
			--m_SaveMaxSlots(ply)
		end
	end

	MsgC(Color(0, 255, 0), "Max Slots saved for " .. ply:Nick() .. "\n")
end

function m_SaveStats(ply)
	if (not MOAT_STATS[ply] or MOAT_STATS[ply] == {}) then return end
	if (not MOAT_STATS[ply].k) then return end
	
	local ply_stats = table.Copy(MOAT_STATS[ply])
	ply_stats = sql.SQLStr(util.TableToJSON(ply_stats), true)

	if (#ply_stats < 5) then return end

	csq = MINVENTORY_MYSQL:query("UPDATE moat_stats SET stats_tbl='" .. ply_stats .. "' WHERE steamid='" .. ply:SteamID() .. "'")
	csq:start()

	function csq:onError(err)
		if (tonumber(MINVENTORY_MYSQL:status()) == mysqloo.DATABASE_NOT_CONNECTED) then
			MINVENTORY_MYSQL:connect()
			timer.Simple(1, function() m_SaveStats(ply) end)
		end
	end
end

function m_LoadStats(ply)
	local query1 = MINVENTORY_MYSQL:query("SELECT * FROM moat_stats WHERE steamid = '" .. ply:SteamID() .. "'")

	function query1:onSuccess(data)
		if (#data > 0) then
			local row = data[1]
			local stats_table = util.JSONToTable(row["stats_tbl"])
			m_InitStatsToPlayer(ply, stats_table)
		else
			m_InsertNewStatsPlayer(ply)
		end
	end

	query1:start()
end

hook.Add("PlayerInitialSpawn", "moat_LoadInventoryForPlayer", function(ply)
	-- mi.LoadInventoryForPlayer(ply)
	m_LoadStats(ply)
end)

hook.Add("MapVoteStarted", "moat_SaveInventoryForPlayer", function(ply)
	for k, v in ipairs(player.GetAll()) do
		--m_SaveInventory(v)
		m_SaveStats(v)
	end
end)

hook.Add("PlayerDisconnected", "moat_LoadInventoryForPlayer", function(ply)
	m_SaveInventory(ply)
	m_SaveStats(ply)
end)