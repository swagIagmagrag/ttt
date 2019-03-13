local meta = FindMetaTable "Player"

MOAT_DROPTABLE = {}
MOAT_COLLECT = {}



function m_AddDroppableItem(item_table, item_kind, file_str)
    local tbl = {}
    tbl = item_table
    tbl.Kind = item_kind

	if (SERVER and item_table.Collection) then
		if (not MOAT_COLLECT[item_table.Collection]) then MOAT_COLLECT[item_table.Collection] = {} end
		tbl.Rarity = (tbl.Rarity == 9 and 9) or (tbl.Rarity == 8 and 8) or tbl.Rarity
		tbl.Kind = (tbl.Kind == "tier" and "tier") or tbl.Kind

		local str = string ("\n",
			"mi.Item(" .. tbl.ID .. ")\n",
			"	" .. ":SetRarity (" .. tbl.Rarity .. ")\n",
			"	" .. ":SetType \"" .. tbl.Kind .. "\"\n",
			"	" .. ":SetName \"" .. tbl.Name .. "\"\n")
		
		if (tbl.NameColor) then
			str = string (str, "	" .. ":SetColor {", tbl.NameColor.r, ", ", tbl.NameColor.g, ", ", tbl.NameColor.b, "}\n")
		end

		if (tbl.NameEffect) then
			str = string (str, "	" .. ":SetEffect \"", tbl.NameEffect, "\"\n")
		end

		if (tbl.Description) then
			str = string (str, "	" .. ":SetDesc \"", tbl.Description, "\"\n")
		end

		if (tbl.Image) then
			str = string (str, "	" .. ":SetImage \"", tbl.Image, "\"\n")
		end

		if (tbl.Model) then
			str = string (str, "	" .. ":SetModel \"", tbl.Model, "\"\n")
		end

		if (tbl.Skin) then
			str = string (str, "	" .. ":SetSkin (", tbl.Skin, ")\n")
		end

		if (tbl.WeaponClass) then
			str = string (str, "	" .. ":SetWeapon \"", tbl.WeaponClass, "\"\n")
		end

		if (tbl.Stats) then
			str = string (str, "	" .. ":SetStats (", tbl.MinStats or table.Count(tbl.Stats), ", ", tbl.MaxStats or table.Count(tbl.Stats), ")\n")

			local def = tbl.Kind == "Melee" and "Melee" or "Gun"
			for k, v in pairs(tbl.Stats) do
				if ((tbl.Kind == "tier" or tbl.Kind == "Tier" or tbl.Kind == "Unique") and mi.Stat.Roster[k]) then
					if (mi.Stat.Roster[k].Defaults[def] and mi.Stat.Roster[k].Defaults[def][tbl.Rarity]) then
						if (mi.Stat.Roster[k].Defaults[def][tbl.Rarity].Min == v.min and mi.Stat.Roster[k].Defaults[def][tbl.Rarity].Max == v.max) then
							continue
						end
					end
				end

				str = string (str, "		" .. ":SetStat (", isnumber(k) and k or '"' .. k .. '"', ", ", v.min, ", ", v.max, ")\n")
			end
		end

		if (tbl.Talents) then
			str = string (str, "	" .. ":SetTalents (", tbl.MinTalents or table.Count(tbl.Talents), ", ", tbl.MaxTalents or table.Count(tbl.Talents), ")\n")

			for k, v in pairs(tbl.Talents) do
				if (v == "random") then continue end
				str = string (str, "		" .. ":SetTalent (", k, ", \"", v, "\")\n")
			end
		end

		if (tbl.ModifyClientsideModel and file_str) then
			local par = tbl.Bone or tbl.Attachment

			local needle = "ITEM:ModifyClientsideModel"
			local sf = string.find(file_str, needle)

			local ms = string.sub(file_str, sf + string.len(needle), string.len(file_str))
			ms = string.Replace(ms, "( ", "(")
			ms = string.Replace(ms, " )", ")")

			local tb, fs = string.Split(ms, "\n"), ""
			for i = 1, #tb do
				tb[i] = string.Trim(tb[i])

				if (string.len(tb[i]) <= 1) then
					continue
				end

				fs = fs .. "		" .. tb[i] .. "\n"
			end

			fs = string.sub(fs, 1, -2) .. ")"
			fs = string.Replace(fs, "		end)", "	" .. "end)")
			fs = string.Replace(fs, "		(", "(")
			
			str = string (str, "	" .. ":SetRender (\"", par, "\", function", string.sub(fs, 1, -2) .. ")", "\n")
		end

		if (tbl.Collection) then
			str = string (str, "	" .. ":SetCollection \"", tbl.Collection, "\"\n\n")
		end

		if (tbl.Price) then
			str = string (str, "	" .. ":SetShop (", tbl.Price, ", ", tbl.Active and "true" or "false", ")\n")
			MOAT_COLLECT[item_table.Collection].Crate = str
		else
			table.insert(MOAT_COLLECT[item_table.Collection], {String = str, Rarity = tbl.Rarity})
		end
	end


    MOAT_DROPTABLE[tbl.ID] = tbl
end

local MOAT_ITEM_FOLDER = "plugins/moat/modules/_items/items"
local MOAT_TALENT_FOLDER = "plugins/moat/modules/_items/talents"

local MOAT_ITEM_FOLDERS = {
    ["tier"] = "tiers",
    ["Unique"] = "uniques",
    ["Power-Up"] = "powerups",
    ["Hat"] = "hats",
    ["Mask"] = "masks",
    ["Model"] = "models",
    ["Crate"] = "crates",
    ["Melee"] = "melees",
    ["Effect"] = "effects",
    ["Body"] = "body",
    ["Other"] = "other",
    ["Usable"] = "usables"
}

function m_CreatePaints()
    for k , v in pairs(MOAT_PAINT.Tints) do
		local tbl = {}
        tbl.Name = v[1]
        tbl.ID = k
        tbl.Description = "Right click this tint to use it on a weapon"
        tbl.Rarity = v[3]
        tbl.Clr = v[2]
        tbl.Collection = "Paint Collection"
        tbl.PaintVer = 1
        tbl.Image = v[4] or "https://cdn.moat.gg/f/V1nF1EWK8QFL2Uwc87wla1ERPQLo.png"
        tbl.ItemCheck = 11
        function tbl:ItemUsed(pl, slot, item)
            m_TintItem(pl, slot, item, self.ID)
        end

		if (tbl.Name and tbl.Name == "Pure White Tint") then
			tbl.NotDroppable = true
		end

        m_AddDroppableItem(tbl, "Usable")
	end

	for k, v in pairs(MOAT_PAINT.Paints) do
		local tbl = {}
        tbl.Name = v[1]
        tbl.ID = k
        tbl.Description = "Right click this paint to use it on an item"
        tbl.Rarity = v[3]
        tbl.Clr = v[2]
        tbl.Collection = "Paint Collection"
        tbl.PaintVer = 2
        tbl.Image = v[4] or "https://cdn.moat.gg/f/3KvQGWvW2Rkb3u9oC3zZWsyRE0wt.png"
        tbl.ItemCheck = 10
        function tbl:ItemUsed(pl, slot, item)
            m_PaintItem(pl, slot, item, self.ID)
        end

        m_AddDroppableItem(tbl, "Usable")
	end

	for k, v in pairs(MOAT_PAINT.Skins) do
        local tbl = {}
        tbl.Name = v[1]
        tbl.ID = k
        tbl.Description = "Right click this skin to use it on a weapon"
        tbl.Rarity = v[3]
        tbl.Texture = v[2]
        tbl.Collection = v[5] or "Paint Collection"
        tbl.PaintVer = 2
        tbl.Image = v[4] or "https://cdn.moat.gg/f/O3DkFrSx6C66U4XBvbGm7aYm4xDV.png"
        tbl.ItemCheck = 12
        function tbl:ItemUsed(pl, slot, item)
            m_TextureItem(pl, slot, item, self.ID)
        end

        m_AddDroppableItem(tbl, "Usable")
    end
end

local COSMETIC_TYPES = {
    ["Hat"] = true,
    ["Mask"] = true, 
    ["Model"] = true, 
    ["Effect"] = true, 
    ["Body"] = true, 
    ["Melee"] = true
}

function m_InitializeItems()
    for type, folder in pairs(MOAT_ITEM_FOLDERS) do
        for _, filename in pairs(file.Find(MOAT_ITEM_FOLDER .. "/" .. folder .. "/*.lua", "LUA")) do
            ITEM = {}
            include(MOAT_ITEM_FOLDER .. "/" .. folder .. "/" .. filename)
            m_AddDroppableItem(ITEM, type, file.Read(MOAT_ITEM_FOLDER .. "/" .. folder .. "/" .. filename, "LUA"))
        end
    end

    include(MOAT_ITEM_FOLDER .. "/paints/load.lua")
    m_CreatePaints()
    -- boom beep items loooooaded
end
m_InitializeItems()

concommand.Add("_reloaditems", function(pl)
	if (IsValid(pl)) then return end
	m_InitializeTalents()
end)


MOAT_TALENTS = {}

function m_AddTalent(talent_tbl)
    MOAT_TALENTS[talent_tbl.ID] = talent_tbl
end

function m_InitializeTalents()
	for k, v in pairs(file.Find(MOAT_TALENT_FOLDER .. "/*.lua", "LUA")) do
    	TALENT = {}
    	include(MOAT_TALENT_FOLDER .. "/" .. v)
    	MsgC(Color(255, 255, 0), "[mInventory] Loaded Talent: " .. TALENT.Name .. "\n")
    	m_AddTalent(TALENT)
	end
end
m_InitializeTalents()

concommand.Add("moat_finditemid",function(ply)
    if (IsValid(ply)) then return end
    for i = 1,10000 do
        if (not MOAT_DROPTABLE[i]) then
            print("Unused: ITEM.ID = " .. i)
            break
        end
    end
end)

concommand.Add("_reloadtalents", function(pl)
	if (IsValid(pl)) then return end
	m_InitializeTalents()
end)

function m_GetRandomTalent(talent_lvl, talent_name, talent_melee)
    local talent_tbl = {}
    local moat_fourth_talent = false

    if (talent_lvl > 3) then
        talent_lvl = 3
        moat_fourth_talent = true
    end


    if (talent_name ~= "random") then
        for k, v in pairs(MOAT_TALENTS) do
            if (talent_name == v.Name) then
                talent_tbl = table.Copy(v)
                break
            end
        end
    else
        for k, v in RandomPairs(MOAT_TALENTS) do
            if (talent_lvl == v.Tier and v.NotUnique) then
				if (talent_melee and not v.Melee) then continue end
                talent_tbl = table.Copy(v)
                break
            end
        end
    end

    if (moat_fourth_talent) then
        talent_tbl.LevelRequired = {min = 40, max = 50}
    end

    return talent_tbl
end

local titan_tier_ids = {}
titan_tier_ids["1146"] = true
titan_tier_ids["1147"] = true
titan_tier_ids["1148"] = true
titan_tier_ids["1149"] = true
titan_tier_ids["1150"] = true

function meta:m_DropInventoryItem(cmd_item, cmd_class, drop_cosmetics, delay_le_saving, hide_chat, dev_talent_tbl)
    local dropped_item = mi:Buildable()
    local drop_table = table.Copy(MOAT_DROPTABLE)
    local chosen_rarity = 1
    local item_name_chosen = false

    if (cmd_item and cmd_item ~= "endrounddrop") then
        local cmd_item_number = false
        local cmd_item_number2 = false

        for i = 0, 9 do
            if (string.StartWith(cmd_item, tostring(i))) then
                cmd_item_number = true
            end
        end

        for i = 0, 9 do
            if (string.EndsWith(cmd_item, tostring(i))) then
                cmd_item_number2 = true
            end
        end

        if (cmd_item_number and cmd_item_number2) then
            chosen_rarity = tonumber(cmd_item)
        else
            item_name_chosen = true
        end
    else
        for i = 1, 7 do
            if (i == 7) then
                local chance_to_move = math.random(8)

                if (chance_to_move == 8) then
                    chosen_rarity = MOAT_RARITIES[9].ID
                    break
                end
            else
                local chance_to_move = math.random(MOAT_RARITIES[i + 1].Rarity)

                if (chance_to_move ~= MOAT_RARITIES[i + 1].Rarity) then
                    chosen_rarity = MOAT_RARITIES[i].ID
                    break
                end
            end
        end
    end

    local items_to_drop = {}

    if (not item_name_chosen) then
        for k, v in pairs(drop_table) do
            if (v.Rarity == chosen_rarity and (drop_cosmetics == nil or (((not drop_cosmetics[1] and not COSMETIC_TYPES[v.Kind]) or drop_cosmetics[1]) and ((not drop_cosmetics[2] and (v.ID < 6001 or v.ID > 6500)) or drop_cosmetics[2])))) then
                if (v.Collection == "Holiday Collection" or v.NotDroppable) then continue end
                
                table.insert(items_to_drop, v)
            end
        end
    else
        for k, v in pairs(drop_table) do
            if (string.lower(v.Name) == string.lower(cmd_item)) then
                table.insert(items_to_drop, v)
            end
        end
    end

    if (#items_to_drop > 0) then
        local item_to_drop = items_to_drop[math.random(#items_to_drop)]
        dropped_item.u = item_to_drop.ID

        if (item_to_drop.Kind == "tier" or item_to_drop.Kind == "Unique") then
            dropped_item:CreateStats()
            local stats_to_apply = 0

            if (item_to_drop.MinStats and item_to_drop.MaxStats) then
                stats_to_apply = math.random(item_to_drop.MinStats, item_to_drop.MaxStats)
            end

            local stats_chosen = 0

            for k, v in RandomPairs(item_to_drop.Stats) do
                if (tostring(k) == "Damage") then
                    dropped_item.s.d = math.Round(math.Rand(0, 1), 3)
                elseif (tostring(k) == "Accuracy") then
                    dropped_item.s.a = math.Round(math.Rand(0, 1), 3)
                elseif (tostring(k) == "Kick") then
                    dropped_item.s.k = math.Round(math.Rand(0, 1), 3)
                elseif (tostring(k) == "Firerate") then
                    dropped_item.s.f = math.Round(math.Rand(0, 1), 3)
                elseif (tostring(k) == "Magazine") then
                    dropped_item.s.m = math.Round(math.Rand(0, 1), 3)
                elseif (tostring(k) == "Range") then
                    dropped_item.s.r = math.Round(math.Rand(0, 1), 3)
                elseif (tostring(k) == "Weight") then
                    dropped_item.s.w = math.Round(math.Rand(0, 1), 3)
                end

                if (stats_to_apply > 0) then
                    stats_chosen = stats_chosen + 1
                    if (stats_chosen >= stats_to_apply) then break end
                end
            end

            dropped_item.w = ""

            if (item_to_drop.Collection == "Pumpkin Collection" or item_to_drop.Collection == "Holiday Collection" or item_to_drop.Collection == "New Years Collection") then
                for k, v in RandomPairs(weapons.GetList()) do
                    if (v.Base == "weapon_tttbase" and (v.ClassName:StartWith("weapon_ttt_te_") or v.AutoSpawnable)) then
                        dropped_item.w = v.ClassName
                        break
                    end
                end
            elseif (titan_tier_ids[tostring(item_to_drop.ID)]) then
                for k, v in RandomPairs(weapons.GetList()) do
                    if (v.Base == "weapon_tttbase" and v.ClassName:StartWith("weapon_ttt_te_")) then
                        dropped_item.w = v.ClassName
                        break
                    end
                end
            else
                for k, v in RandomPairs(weapons.GetList()) do
                    if (v.AutoSpawnable and v.Base == "weapon_tttbase" and ((item_to_drop.ID == 912 and not v.ViewModelFlip) or item_to_drop.ID ~= 912)) then
                        dropped_item.w = v.ClassName
                        break
                    end
                end
            end

            if (cmd_class and cmd_class ~= "endrounddrop") then
                local weapon_class_found = ""

                for k, v in RandomPairs(weapons.GetList()) do
                    if (v.AutoSpawnable and v.Base == "weapon_tttbase") then
                        weapon_class_found = v.ClassName
                    end

                    if (v.ClassName == cmd_class) then
                        weapon_class_found = v.ClassName
                        break
                    end
                end

                dropped_item.w = weapon_class_found
            end

            if (item_to_drop.Kind == "Unique" and item_to_drop.WeaponClass) then
                dropped_item.w = item_to_drop.WeaponClass
            end

            if (item_to_drop.MinTalents and item_to_drop.MaxTalents and item_to_drop.Talents) then
                dropped_item.s.l = 1
                dropped_item.s.x = 0
                dropped_item:CreateTalents()
                local talents_chosen = {}
                local talents_to_loop = dev_talent_tbl or item_to_drop.Talents

                for k, v in ipairs(talents_to_loop) do
                    talents_chosen[k] = m_GetRandomTalent(k, v, false)
                end

                for i = 1, table.Count(talents_chosen) do
                    local talent_tbl = talents_chosen[i]
                    dropped_item.t[i] = {}
                    dropped_item.t[i].e = talent_tbl.ID
                    dropped_item.t[i].l = math.random(talent_tbl.LevelRequired.min, talent_tbl.LevelRequired.max)
                    dropped_item.t[i].m = {}

                    for k, v in ipairs(talent_tbl.Modifications) do
                        dropped_item.t[i].m[k] = math.Round(math.Rand(0, 1), 2)
                    end
                end
            end
        elseif (item_to_drop.Kind == "Melee") then
            dropped_item.s:CreateStats()
            local stats_to_apply = 0

            if (item_to_drop.MinStats and item_to_drop.MaxStats) then
                stats_to_apply = math.random(item_to_drop.MinStats, item_to_drop.MaxStats)
            end

            local stats_chosen = 0

            for k, v in RandomPairs(item_to_drop.Stats) do
                if (tostring(k) == "Damage") then
                    dropped_item.s.d = math.Round(math.Rand(0, 1), 3)
                elseif (tostring(k) == "Firerate") then
                    dropped_item.s.f = math.Round(math.Rand(0, 1), 3)
                elseif (tostring(k) == "Pushrate") then
                    dropped_item.s.p = math.Round(math.Rand(0, 1), 3)
                elseif (tostring(k) == "Force") then
                    dropped_item.s.v = math.Round(math.Rand(0, 1), 3)
                elseif (tostring(k) == "Weight") then
                    dropped_item.s.w = math.Round(math.Rand(0, 1), 3)
                end

                if (stats_to_apply > 0) then
                    stats_chosen = stats_chosen + 1
                    if (stats_chosen >= stats_to_apply) then break end
                end
            end

            dropped_item.w = ""

            if (item_to_drop.WeaponClass) then
                dropped_item.w = item_to_drop.WeaponClass
            end

            if (math.random(2) == 1) then
                dropped_item.s.l = 1
                dropped_item.s.x = 0
                dropped_item.t:CreateTalents()
                local talents_chosen = {}
                local talents_to_loop = {"random"}
				
				if (math.random(3) == 1) then
					table.insert(talents_to_loop, "random")
					if (math.random(5) == 1) then
						table.insert(talents_to_loop, "random")
					end
				end

				if (dev_talent_tbl) then
					talents_to_loop = dev_talent_tbl
				end

                for k, v in ipairs(talents_to_loop) do
                    talents_chosen[k] = m_GetRandomTalent(k, v, true)
                end

                for i = 1, table.Count(talents_chosen) do
                    local talent_tbl = talents_chosen[i]
                    dropped_item.t[i] = {}
                    dropped_item.t[i].e = talent_tbl.ID
                    dropped_item.t[i].l = math.random(talent_tbl.LevelRequired.min, talent_tbl.LevelRequired.max)
                    dropped_item.t[i].m = {}

                    for k, v in ipairs(talent_tbl.Modifications) do
                        dropped_item.t[i].m[k] = math.Round(math.Rand(0, 1), 2)
                    end
                end
            end
        elseif ((item_to_drop.Kind == "Power-Up" or item_to_drop.Kind == "Other" or item_to_drop.Kind == "Usable") and item_to_drop.Stats) then
            dropped_item.s:CreateStats()

            for i = 1, #item_to_drop.Stats do
                dropped_item.s[i] = math.Round(math.Rand(0, 1), 3)
            end
        end

        dropped_item.c = util.CRC(os.time() .. SysTime())

        hook.Run("PlayerObtainedItem", self, dropped_item)
        local dont_show_chat = false
        delay_le_saving = delay_le_saving or false

        if (cmd_class and cmd_class == "hide_chat_obtained") then
            dont_show_chat = true
        end

        if (hide_chat == true) then
            dont_show_chat = true
        end

        if (dropped_item and dropped_item.u and item_to_drop and item_to_drop.Rarity) then
            if (item_to_drop.Rarity == 6) then
				cdn.PlayURL "https://cdn.moat.gg/f/jNtvxfzegrrhSzpFi2ldjPLFVCuL.mp3"
            elseif (item_to_drop.Rarity == 7) then
				cdn.PlayURL "https://cdn.moat.gg/f/CUuOaURrcDiexrntlVjs9famksuK.wav"
				BroadcastLua("util.ScreenShake(LocalPlayer():GetPos(), 5, 5, 10, 5000)")
            elseif (item_to_drop.Rarity == 9) then
                cdn.PlayURL "https://cdn.moat.gg/f/1ePlkeSBwT6xXxcUJ7frbSUzT1BW.mp3"
				BroadcastLua("util.ScreenShake(LocalPlayer():GetPos(), 25, 25, 15, 5000)")
                local ITEM_HOVERED = item_to_drop
                local wpnstr = item_to_drop.Name
                local ITEM_NAME_FULL = ""
                if (ITEM_HOVERED.Kind == "tier") then
                    local ITEM_NAME = util.GetWeaponName(dropped_item.w) or wpnstr

                    if (string.EndsWith(ITEM_NAME, "_name")) then
                        ITEM_NAME = string.sub(ITEM_NAME, 1, ITEM_NAME:len() - 5)
                        ITEM_NAME = string.upper(string.sub(ITEM_NAME, 1, 1)) .. string.sub(ITEM_NAME, 2, ITEM_NAME:len())
                    end

                    ITEM_NAME_FULL = ITEM_HOVERED.Name .. " " .. ITEM_NAME
                else
                    ITEM_NAME_FULL = ITEM_HOVERED.Name
                end
                gglobalchat_planetary(self:Nick(),ITEM_NAME_FULL)
            elseif (tonumber(dropped_item.u) == 912 or titan_tier_ids[tostring(dropped_item.u)]) then
                cdn.PlayURL "https://cdn.moat.gg/f/u8diZ6qyoxuJPbwHOlLC25SdC3jY.mp3"
			end
        end

        self:m_AddInventoryItem(dropped_item, delay_le_saving, dont_show_chat)
    else
        self:ChatPrint("ERROR OBTAINING ITEM! CONTACT MOAT!")
    end
end

function m_GetRandomRarity(min, max)
    local chosen_rarity = min

    if (min == max) then
        return min
    end

    for i = min, max do
        local chance_to_move = math.random(MOAT_RARITIES[i + 1].Rarity)

        if (chance_to_move ~= MOAT_RARITIES[i + 1].Rarity) then
            chosen_rarity = MOAT_RARITIES[i].ID
            break
        end
	end

	if (chosen_rarity == 8 and max == 9) then
		chosen_rarity = 9
	end

    return chosen_rarity
end


local cached_droptable
local cached_itemstodrop = {}
local cached_items = {}
local cached_rarities = {}
local cached_weapons
function m_GetRandomInventoryItem(arg_collection)
    if (not cached_droptable) then cached_droptable = table.Copy(MOAT_DROPTABLE) end
    local dropped_item = {}
    local drop_table = cached_droptable
    local items_to_drop = {}

    if (cached_itemstodrop[arg_collection]) then
        items_to_drop = cached_itemstodrop[arg_collection]
    elseif (arg_collection ~= "50/50 Collection") then
        for k, v in pairs(drop_table) do
            if (v.Collection == arg_collection and not v.NotDroppable) then
                table.insert(items_to_drop, v)
            end
        end

        cached_itemstodrop[arg_collection] = items_to_drop
    end

    -- Make sure all the rarities from the collection are set
    local min_rarity = 9
    local max_rarity = 1

    if (cached_rarities[arg_collection]) then
        min_rarity = cached_rarities[arg_collection][1]
        max_rarity = cached_rarities[arg_collection][2]
    elseif (arg_collection ~= "50/50 Collection") then
        for k, v in pairs(items_to_drop) do
            if (v.Rarity > max_rarity) then
                max_rarity = v.Rarity
            end

            if (v.Rarity < min_rarity) then
                min_rarity = v.Rarity
            end
        end

        cached_rarities[arg_collection] = {min_rarity, max_rarity}
    end

    local rarity_chosen = 1

    if (arg_collection == "Easter Collection") then
        rarity_chosen = 8
    elseif (arg_collection ~= "50/50 Collection") then
        rarity_chosen = m_GetRandomRarity(min_rarity, max_rarity)
    end
    
    local items_from_collection = {}
    if (arg_collection == "50/50 Collection") then
        rarity_chosen = math.random(1, 100) <= 50 and 5 or 1

        if (cached_items[arg_collection] and cached_items[arg_collection][rarity_chosen]) then
            items_from_collection = cached_items[arg_collection][rarity_chosen]
        else
            for k, v in pairs(drop_table) do
                if (v.Rarity == rarity_chosen and v.Kind ~= "Crate" and not COSMETIC_TYPES[v.Kind] and v.Collection ~= "Holiday Collection" and not v.NotDroppable) then
                    table.insert(items_from_collection, v)
                end
            end

            if (not cached_items[arg_collection]) then cached_items[arg_collection] = {} end
            cached_items[arg_collection][rarity_chosen] = items_from_collection
        end
    else
        if (cached_items[arg_collection] and cached_items[arg_collection][rarity_chosen]) then
            items_from_collection = cached_items[arg_collection][rarity_chosen]
        else
            for k, v in pairs(items_to_drop) do
                if (v.Rarity == rarity_chosen and v.Kind ~= "Crate") then
                    table.insert(items_from_collection, v)
                end
            end

            if (not cached_items[arg_collection]) then cached_items[arg_collection] = {} end
            cached_items[arg_collection][rarity_chosen] = items_from_collection
        end
    end
    
    if (#items_from_collection > 0) then
        local item_to_drop = items_from_collection[math.random(#items_from_collection)]
        dropped_item.u = item_to_drop.ID

        if (not cached_weapons) then cached_weapons = weapons.GetList() end

        if (item_to_drop.Kind == "tier" or item_to_drop.Kind == "Unique") then
            dropped_item.w = ""

            if (item_to_drop.Collection == "Pumpkin Collection"or item_to_drop.Collection == "Holiday Collection") then
                for k, v in RandomPairs(cached_weapons) do
                    if (v.Base == "weapon_tttbase" and (v.AutoSpawnable or v.ClassName:StartWith("weapon_ttt_te_"))) then
                        dropped_item.w = v.ClassName
                        break
                    end
                end
            elseif (titan_tier_ids[tostring(item_to_drop.ID)]) then
                for k, v in RandomPairs(cached_weapons) do
                    if (v.Base == "weapon_tttbase" and v.ClassName:StartWith("weapon_ttt_te_")) then
                        dropped_item.w = v.ClassName
                        break
                    end
                end
            else
                for k, v in RandomPairs(cached_weapons) do
                    if (v.AutoSpawnable and v.Base == "weapon_tttbase") then
                        dropped_item.w = v.ClassName
                        break
                    end
                end
            end

            if (item_to_drop.Kind == "Unique" and item_to_drop.WeaponClass) then
                dropped_item.w = item_to_drop.WeaponClass
            end
        end

        if (item_to_drop.Kind == "Melee") then
            dropped_item.w = ""

            if (item_to_drop.WeaponClass) then
                dropped_item.w = item_to_drop.WeaponClass
            end
        end

        dropped_item.c = 1

        return dropped_item
    else
        return {}
    end
end

concommand.Add("moat_drop_item", function(ply, cmd, args)
    if (not moat.isdev(ply)) then return end

    local pl = ply
    if (args[3]) then
        pl = player.GetBySteamID(args[3])
    end
    if (args) then
        pl:m_DropInventoryItem(args[1], args[2])
    else
        pl:m_DropInventoryItem()
    end
end)

function m_AddTestRarity(tbl)
    local chosen_rarity = 1

    for i = 1, #MOAT_RARITIES do
        local chance_to_move = math.random(MOAT_RARITIES[i + 1].Rarity)

        if (chance_to_move ~= MOAT_RARITIES[i + 1].Rarity) then
            chosen_rarity = MOAT_RARITIES[i].ID
            break
        end
    end

    table.insert(tbl, chosen_rarity)
end

concommand.Add("moat_test_drops", function(ply, cmd, args)
    if (not moat.isdev(ply)) then return end
    local moat_test_dropstbl = {}

    for _ = 1, tonumber(args[1]) do
        m_AddTestRarity(moat_test_dropstbl)
    end

    timer.Simple(3, function()
        local droptbl_nums = {0, 0, 0, 0, 0, 0, 0}
        print(#moat_test_dropstbl)

        for k, v in pairs(moat_test_dropstbl) do
            droptbl_nums[v] = droptbl_nums[v] + 1
        end

        timer.Simple(5, function()
            PrintTable(droptbl_nums)
        end)
    end)
end)

local MOAT_PLAYER_DROPS_CHECK = {}
local MOAT_FORCED_DROPS = {}

hook.Add("TTTEndRound", "moat_DropsEndRound", function()
    for k, v in pairs(player.GetAll()) do
        if ((v:IsSpec() and not v:IsDeadTerror()) or (not MOAT_PLAYER_DROPS_CHECK[v])) then continue end
        if (MOAT_FORCED_DROPS[v:SteamID()]) then
            v:m_DropInventoryItem(MOAT_FORCED_DROPS[v:SteamID()][1], MOAT_FORCED_DROPS[v:SteamID()][2], {tonumber(v:GetInfo("moat_dropcosmetics")) == 1, tonumber(v:GetInfo("moat_droppaint")) == 1})
            
            continue
        end
        local drop_item = false
        local chance = math.random(3)

        if (chance == 1) then
            drop_item = true
        end

        if (drop_item) then
            v:m_DropInventoryItem("endrounddrop", "endrounddrop", {tonumber(v:GetInfo("moat_dropcosmetics")) == 1, tonumber(v:GetInfo("moat_droppaint")) == 1})
        end
    end
end)

concommand.Add("moat_end_drop_test", function(ply, cmd, args)
    if (not moat.isdev(ply)) then return end

    ply:m_DropInventoryItem("endrounddrop", "endrounddrop", {tonumber(ply:GetInfo("moat_dropcosmetics")) == 1, tonumber(ply:GetInfo("moat_droppaint")) == 1})
end)

concommand.Add("moat_end_drop", function(ply, cmd, args)
    if (not moat.isdev(ply)) then return end

    local steamid = args[1]
    local item = args[2]
    local class = args[3]

    MOAT_FORCED_DROPS[steamid] = {item, class}
end)

hook.Add("TTTBeginRound", "moat_DropsEndRoundCheck", function()
    MOAT_FORCED_DROPS = {}
    for k, v in pairs(player.GetAll()) do
        MOAT_PLAYER_DROPS_CHECK[v] = false
        v.NotAFK = false
    end
end)

local MOAT_KEYS_TO_CHECK = {
    [IN_ATTACK] = true,
    [IN_ATTACK2] = true,
    [IN_BACK] = true,
    [IN_DUCK] = true,
    [IN_FORWARD] = true,
    [IN_JUMP] = true,
    [IN_MOVELEFT] = true,
    [IN_MOVERIGHT] = true
}

hook.Add("KeyPress", "moat_DropsEndRoundCheckKeys", function(ply, key)
    if (MOAT_KEYS_TO_CHECK[key] and not MOAT_PLAYER_DROPS_CHECK[ply]) then
        MOAT_PLAYER_DROPS_CHECK[ply] = true
        ply.NotAFK = true
    end
end)

function m_TextureItem(pl, wep_slot, itemtbl, paint)
    local ply_item = MOAT_INVS[pl]["slot" .. wep_slot]

    ply_item.p2 = nil
    ply_item.p3 = paint
    m_SaveInventory(pl)
    m_SendInvItem(pl, wep_slot)
end

function m_PaintItem(pl, wep_slot, itemtbl, paint)
    local ply_item = MOAT_INVS[pl]["slot" .. wep_slot]

    ply_item.p3 = nil
    ply_item.p2 = paint
    m_SaveInventory(pl)
    m_SendInvItem(pl, wep_slot)
end

function m_TintItem(pl, wep_slot, itemtbl, paint)
    local ply_item = MOAT_INVS[pl]["slot" .. wep_slot]

    ply_item.p = paint
    m_SaveInventory(pl)
    m_SendInvItem(pl, wep_slot)
end

function m_ResetTalents(pl, wep_slot, itemtbl)
    local ply_item = MOAT_INVS[pl]["slot" .. wep_slot]
	itemtbl = itemtbl.item

    if ((itemtbl.MinTalents and itemtbl.MaxTalents and itemtbl.Talents) or (itemtbl.Kind and itemtbl.Kind == "Melee")) then
        local old_talents = #ply_item.t

		ply_item.s.l = 1
        ply_item.s.x = 0
        ply_item.t = {}

        local talents_chosen = {}
        local talents_to_loop = itemtbl.Talents

		if (itemtbl.Kind and itemtbl.Kind == "Melee") then
			talents_to_loop = {}
			for i = 1, old_talents do
				table.insert(talents_to_loop, "random")
			end
		end

        for k, v in ipairs(talents_to_loop) do
            talents_chosen[k] = m_GetRandomTalent(k, v, (itemtbl.Kind and itemtbl.Kind == "Melee"))
        end

        for i = 1, table.Count(talents_chosen) do
            local talent_tbl = talents_chosen[i]
            ply_item.t[i] = {}
            ply_item.t[i].e = talent_tbl.ID
            ply_item.t[i].l = math.random(talent_tbl.LevelRequired.min, talent_tbl.LevelRequired.max)
            ply_item.t[i].m = {}

            for k, v in ipairs(talent_tbl.Modifications) do
                ply_item.t[i].m[k] = math.Round(math.Rand(0, 1), 2)
            end
        end

        ply_item.tr = 1
    end

    m_SaveInventory(pl)
    m_SendInvItem(pl, wep_slot)
end

function m_AssignDogLover(pl, wep_slot, itemtbl)
    local ply_item = MOAT_INVS[pl]["slot" .. wep_slot]
    local talent_index = 2

    if (not ply_item.t) then
        ply_item.s.l = 1
        ply_item.s.x = 0
        ply_item.t = {}

        talent_index = 1
    end

    ply_item.t[talent_index] = {}
    ply_item.t[talent_index].e = 154
    ply_item.t[talent_index].l = math.random(15, 20)
    ply_item.t[talent_index].m = {}
    ply_item.t[talent_index].m[1] = math.Round(math.Rand(0, 1), 2)
    ply_item.t[talent_index].m[2] = math.Round(math.Rand(0, 1), 2)
    ply_item.tr = 1

    m_SaveInventory(pl)
    m_SendInvItem(pl, wep_slot)
end

function m_ResetStats(pl, wep_slot, itemtbl)
    local ply_item = MOAT_INVS[pl]["slot" .. wep_slot]
	itemtbl = itemtbl.item

    if (itemtbl.Kind == "tier" or itemtbl.Kind == "Unique") then
        local saved_level = nil

        if (ply_item.s and ply_item.s.l) then
            saved_level = {ply_item.s.l, ply_item.s.x}
        end

        ply_item.s = {}

        if (saved_level) then
            ply_item.s.l = saved_level[1]
            ply_item.s.x = saved_level[2]
        end

        local stats_to_apply = 0

        if (itemtbl.MinStats and itemtbl.MaxStats) then
            stats_to_apply = math.random(itemtbl.MinStats, itemtbl.MaxStats)
        end

        local stats_chosen = 0

        for k, v in RandomPairs(itemtbl.Stats) do
            if (tostring(k) == "Damage") then
                ply_item.s.d = math.Round(math.Rand(0, 1), 3)
            elseif (tostring(k) == "Accuracy") then
                ply_item.s.a = math.Round(math.Rand(0, 1), 3)
            elseif (tostring(k) == "Kick") then
                ply_item.s.k = math.Round(math.Rand(0, 1), 3)
            elseif (tostring(k) == "Firerate") then
                ply_item.s.f = math.Round(math.Rand(0, 1), 3)
            elseif (tostring(k) == "Magazine") then
                ply_item.s.m = math.Round(math.Rand(0, 1), 3)
            elseif (tostring(k) == "Range") then
                ply_item.s.r = math.Round(math.Rand(0, 1), 3)
            elseif (tostring(k) == "Weight") then
                ply_item.s.w = math.Round(math.Rand(0, 1), 3)
            end

            if (stats_to_apply > 0) then
                stats_chosen = stats_chosen + 1
                if (stats_chosen >= stats_to_apply) then break end
            end
        end
    elseif (itemtbl.Kind == "Melee") then
        local saved_level = nil

        if (ply_item.s and ply_item.s.l) then
            saved_level = {ply_item.s.l, ply_item.s.x}
        end

        ply_item.s = {}

        if (saved_level) then
            ply_item.s.l = saved_level[1]
            ply_item.s.x = saved_level[2]
        end

        local stats_to_apply = 0

        if (itemtbl.MinStats and itemtbl.MaxStats) then
            stats_to_apply = math.random(itemtbl.MinStats, itemtbl.MaxStats)
        end

        local stats_chosen = 0

        for k, v in RandomPairs(itemtbl.Stats) do
            if (tostring(k) == "Damage") then
                ply_item.s.d = math.Round(math.Rand(0, 1), 3)
            elseif (tostring(k) == "Firerate") then
                ply_item.s.f = math.Round(math.Rand(0, 1), 3)
            elseif (tostring(k) == "Pushrate") then
                ply_item.s.p = math.Round(math.Rand(0, 1), 3)
            elseif (tostring(k) == "Force") then
                ply_item.s.v = math.Round(math.Rand(0, 1), 3)
            elseif (tostring(k) == "Weight") then
                ply_item.s.w = math.Round(math.Rand(0, 1), 3)
            end

            if (stats_to_apply > 0) then
                stats_chosen = stats_chosen + 1
                if (stats_chosen >= stats_to_apply) then break end
            end
        end
    elseif ((itemtbl.Kind == "Power-Up" or itemtbl.Kind == "Other" or itemtbl.Kind == "Usable") and itemtbl.Stats) then
        local saved_level = nil

        if (ply_item.s and ply_item.s.l) then
            saved_level = {ply_item.s.l, ply_item.s.x}
        end

        ply_item.s = {}

        if (saved_level) then
            ply_item.s.l = saved_level[1]
            ply_item.s.x = saved_level[2]
        end

        for i = 1, #itemtbl.Stats do
            ply_item.s[i] = math.Round(math.Rand(0, 1), 3)
        end
    end

    m_SaveInventory(pl)
    m_SendInvItem(pl, wep_slot)
end