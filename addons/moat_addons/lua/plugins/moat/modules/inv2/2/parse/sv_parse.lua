local SQL = mi.SQL
hook.Add("InventoryPrepare", "mi.Prepare", function(sql)
    print"\n\n\n\n\n\n\n\n\n\n\n\n\n"
    SQL = mi.SQL
end)
--[[-----------------------------------
Parsing SQL > Table
------------------------------------]]--

if (GetHostName():lower():find "dev") then
    --[[PAIRS_REAL = PAIRS_REAL or pairs
    local p = PAIRS_REAL
    function pairs(d)
        local mt = debug.getmetatable(d)
        if (mt and mt.__pairs) then
            return mt.__pairs(d)
        end
        return p(d)
    end]]
end

local weapon_mt = {
    __tostring = function(self)
        return "Weapon linked to SQL"
    end,
    __index = function(self, k)
        local real_data = rawget(self, "real_data")
        if (real_data) then
            return real_data[k]
        end
    end,
    __newindex = function(self, k, v)
        assert(k ~= "uid", "UID set")
        if (self.Update) then
            self:Update(k, v)
        end
        local real_data = rawget(self, "real_data")
        if (real_data) then
            real_data[k] = v
        end
    end
}
local stats_mt = {
    __tostring = function(self)
        return "Weapon stats linked to SQL"
    end,
    __index = function(self, k)
        local real_data = rawget(self, "real_data")
        if (real_data) then
            return real_data[k]
        end
    end,
    __newindex = function(self, k, v)
        local wep = self.wep
        if (wep and wep.UpdateStat) then
            wep:UpdateStat(k, v)
        end
        local real_data = rawget(self, "real_data")
        if (real_data) then
            real_data[k] = v
        end
    end
}
local talents_mt = {
    __tostring = function(self)
        return "Weapon talents linked to SQL"
    end,
    __index = function(self, k)
        local real_data = rawget(self, "real_data")
        if (real_data) then
            return real_data[k]
        end
    end,
    __newindex = function(self, k, v)
        local wep = self.wep
        if (wep and wep.UpdateTalent) then
            wep:UpdateTalent(k, v)
        end
        local real_data = rawget(self, "real_data")
        if (real_data) then
            real_data[k] = v
        end
    end
}
local function new_stats(wep)
    return setmetatable({real_data = {}, wep = wep}, stats_mt)
end
local function new_talents(wep)
    return setmetatable({real_data = {}, wep = wep}, talents_mt)
end

local function WriteWeaponToNet(self)
    net.WriteBool(not not self.c)
    if (not self.c) then
        return
    end

    net.WriteUInt(self.c, 32)
    net.WriteUInt(self.u, 32)

    net.WriteBool(not not self.w)
    if (self.w) then
        net.WriteString(self.w)
    end
    -- item stats
    if (self.s) then
        for statid, value in pairs(self.s.real_data) do
            net.WriteType(statid)
            net.WriteFloat(value)
        end
    end
    net.WriteType(nil)

    -- item talents
    if (self.t) then
        for tier, data in pairs(self.t.real_data) do
            net.WriteUInt(tier, 8)
            net.WriteUInt(data.e, 16)
            net.WriteUInt(data.l, 16)
            local mods = data.m
            for i = 1, 255 do
                if (not mods[i]) then
                    break
                end
                net.WriteBool(true)
                net.WriteFloat(mods[i])
            end
            net.WriteBool(false)
        end
    end
    net.WriteUInt(255, 8)

    -- item paints
    net.WriteBool(not not self.p1)
    if (self.p1) then
        net.WriteUInt(self.p1, 16)
    end
    net.WriteBool(not not self.p2)
    if (self.p2) then
        net.WriteUInt(self.p2, 16)
    end
    net.WriteBool(not not self.p3)
    if (self.p3) then
        net.WriteUInt(self.p3, 16)
    end

    -- item nickname
    net.WriteBool(not not self.n)
    if (self.n) then
        net.WriteString(self.n)
    end
end
local function new_weapon(init)
    return setmetatable({
        real_data = init or {},
        WriteToNet = WriteWeaponToNet
    }, weapon_mt)
end

local blank = new_weapon {}
function mi:Blank()
    return blank
end

local buildable = {}
function buildable:CreateStats(data)
    self.s = new_stats(data)
end
function buildable:CreateTalents(data)
    self.t = new_talents(data)
end

function mi:Buildable()
    return new_weapon(table.Copy(buildable))
end

local function UpdateStat(self, statid, val)
    local query = mi:CreateQuery("REPLACE INTO mg_itemstats (value, statid, weaponid) VALUES (?, ?, ?);", val, statid, self.c)
    mi:SQLQuery(query, function()
        print("saved stat for ", self)
    end)
end

function mi:ParseInventoryQuery(d, q)
    local inv = {["cache"] = {}}

    for i = 1, #d do
        local r = d[i]
        inv[r["id"]] = new_weapon {
            ["c"] = r["id"],
            ["u"] = r["itemid"],
            ["w"] = r["classname"] or nil,
            ["slotid"] = r["slotid"] or nil
        }
    end

    while (q:hasMoreResults()) do
        d = q:getData()
        if (not d[1]) then break end

        if (d[1]["statid"]) then self:ParseItemStatsQuery(d, inv) end
        if (d[1]["talentid"]) then self:ParseItemTalentsQuery(d, inv) end
        if (d[1]["paintid"]) then self:ParseItemPaintsQuery(d, inv) end
        if (d[1]["nickname"]) then self:ParseItemNamesQuery(d, inv) end

        q:getNextResults()
    end
    inv["cache"] = nil

    for id, wep in pairs(inv) do
        wep.UpdateStat = UpdateStat
    end

    return inv
end

function mi:ParseItemStatsQuery(d, inv)
    for i = 1, #d do
        local r = d[i]
        local wep = inv[r["id"]]
        if (not wep["s"]) then
            wep["s"] = new_stats(wep)
        end
        wep["s"][tonumber(r["statid"]) or r["statid"]] = r["value"]
    end
end

function mi:ParseItemTalentsQuery(d, inv)
    for i = 1, #d do
        local r = d[i]
        local wep = inv[r["id"]]
        if (not wep["t"]) then
            wep["t"] = new_talents(wep)
        end
        local c = r["id"] .. r["talentid"] .. r["required"]
        local t = MOAT_TALENTS[r["talentid"]]["Tier"]

        if (r["modification"] > 1) then
            local n = inv["cache"][c] or t
            wep["t"][n]["m"][r["modification"]] = r["value"]
            continue
        end

        inv["cache"][c] = wep["t"][t] and t + 1 or t
        wep["t"][inv["cache"][c]] = {
            ["m"] = {
                r["value"]
            },
            ["e"] = r["talentid"],
            ["l"] = r["required"]
        }
    end
end

function mi:ParseItemPaintsQuery(d, inv)
    for i = 1, #d do
        local r = d[i]
        inv[r["id"]]["p" .. r["type"]] = r["paintid"]
    end
end

function mi:ParseItemNamesQuery(d, inv)
    for i = 1, #d do
        local r = d[i]
        inv[r["id"]]["n"] = r["nickname"]
    end
end


--[[-----------------------------------
Parsing Item > SQL
------------------------------------]]--

function mi:QueryFromItem(i, o)
    if (i.s and next(i.s.real_data) ~= nil) then -- weapon
        if (i.t and next(i.t.real_data) ~= nil) then
            return self:InsertWeaponTalents(i, o)
        else
            return self:InsertWeaponStats(i, o)
        end
    else
        if (i.w) then
            return self:InsertWeapon(i, o)
        else
            return self:InsertItem(i, o)
        end
    end
end

function mi:InsertItem(tbl, ownerid)
    return SQL:CreateQuery("call insertItem(?, ?!, ?);", tbl.u, ownerid, tbl.slot)
end


function mi:InsertWeapon(tbl, ownerid)
    return SQL:CreateQuery("call insertWeapon(?, ?!, ?, ?);", tbl.u, ownerid, tbl.slot, tbl.w)
end

function mi:InsertWeaponStats(tbl, ownerid)
    local data = {
        stat_count = 0,
        slot = tbl.slot,
        class_name = tbl.w,
        tbl.u,
        ownerid
    }
    for k, v in pairs(tbl.s.real_data) do
        data.stat_count = data.stat_count + 1
        table.insert(data, k)
        table.insert(data, v)
    end

    if (data.stat_count == 0) then
        return self:InsertWeapon(tbl, ownerid)
    end
    return SQL:CreateQuery("call insertWeapon?stat_countStats(?, ?!, ?slot, ?class_name"..string.rep(", ?, ?", data.stat_count)..");", data)
end

function mi:InsertWeaponTalents(tbl, ownerid)
    local data = {
        stat_count = 0,
        talent_count = 0,
        slot = tbl.slot,
        class_name = tbl.w,
        tbl.u,
        ownerid,
    }
    for k, v in pairs(tbl.s.real_data) do
        table.insert(data, k)
        table.insert(data, v)
        print(k, v)
        data.stat_count = data.stat_count + 1
    end
    for k, v in ipairs(tbl.t.real_data) do
        for i = 1, #v["m"] do
            table.insert(data, v.e)
            table.insert(data, v.l)
            table.insert(data, i)
            table.insert(data, v.m[i])
            data.talent_count = data.talent_count + 1
        end
    end
    return SQL:CreateQuery("call insertWeapon?stat_countStats?talent_countTalents(?, ?!, ?slot, ?class_name"..string.rep(", ?", data.stat_count * 2 + data.talent_count * 4)..");", data)
end

function mi:LastInsertID()
    return SQL:Function("LAST_INSERT_ID")
end

function mi:Raw(s)
    return SQL:Raw(s)
end

function mi:QueryForName(n, u)
    return SQL:CreateQuery("call insertItemName(?, ?);", u, n)
end

function mi:CreateQuery(...)
    return SQL:CreateQuery(...)
end

function mi:QueryForPaint(i, u)
    local query = {}
    if (i["p"]) then
        table.insert(query, SQL:CreateQuery("call insertItemPaint(?, ?, ?);", u, 1, i.p))
    end

    if (i["p2"]) then
        table.insert(query, SQL:CreateQuery("call insertItemPaint(?, ?, ?);", u, 2, i.p2))
    end

    if (i["p3"]) then
        table.insert(query, SQL:CreateQuery("call insertItemPaint(?, ?, ?);", u, 3, i.p3))
    end

    return table.concat(query, "")
end

function mi:GetOldInvQuery(inv, id)
    local LAST_INSERT_ID = mi:LastInsertID()
    local qstr = ""
    for k, v in pairs(inv) do
        if (not v.u) then continue end
        v["slot"] = k:StartWith("l") and -tonumber(k:TrimLeft("l_slot")) or tonumber(k:TrimLeft("slot"))
        if (v["tr"] and v["s"]) then v["s"]["tr"] = nil v["s"]["j"] = "1" end

        local str = mi:QueryFromItem(v, id)
        local var = mi:Raw "@cid"
        str = str .. mi:CreateQuery("set ? = ?;", var, LAST_INSERT_ID)

        if (v.n) then
            str = str .. mi:QueryForName(v.n, var)
        end

        if (v.p or v.p2 or v.p3) then
            str = str .. mi:QueryForPaint(v, var)
        end

        qstr = qstr .. str
    end

	return qstr
end

concommand.Add("test_inv1", function(pl, cmd, args)
    local start_time = SysTime()

    pl:LoadInventory(function(pl, inv)
        local end_time = SysTime()
        print(end_time - start_time)

		LoadInventory_Deprecated(pl, function()
        	start_time = SysTime()
        	print(start_time - end_time)
		end)
    end)
end)