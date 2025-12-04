local skynet = require "skynet"
local redis = require "skynet.db.redis"
local config = require "config_db"

local rdb = nil

--打印table内容，调试用
local function dump(obj)

    local getIndent, quoteStr, wrapKey, wrapVal, dumpObj
    getIndent = function(level)
        return string.rep("\t", level)
    end
    quoteStr = function(str)
        return '"' .. string.gsub(str, '"', '\\"') .. '"'
    end
    wrapKey = function(val)
        if type(val) == "number" then
            return "[" .. val .. "]"
        elseif type(val) == "string" then
            return "[" .. quoteStr(val) .. "]"
        else
            return "[" .. tostring(val) .. "]"
        end
    end
    wrapVal = function(val, level)
        if type(val) == "table" then
            return dumpObj(val, level)
        elseif type(val) == "number" then
            return val
        elseif type(val) == "string" then
            return quoteStr(val)
        else
            return tostring(val)
        end
    end
    dumpObj = function(obj, level)
        if type(obj) ~= "table" then
            return wrapVal(obj)
        end
        level = level + 1
        local tokens = {}
        tokens[#tokens + 1] = "{"
        for k, v in pairs(obj) do
            tokens[#tokens + 1] = getIndent(level) .. wrapKey(k) .. " = " .. wrapVal(v, level) .. ","
        end
        tokens[#tokens + 1] = getIndent(level - 1) .. "}"
        return table.concat(tokens, "\n")
    end
    return dumpObj(obj, 0)
end

------------------------------------------------------
-- 通用存储函数：把 Lua table 存到 Redis Hash
------------------------------------------------------
local function save_table(db, key, tbl)
    -- 使用hmset存储表字段
    local data = {}
    for field, value in pairs(tbl) do
        if( type(value) == "table" ) then
            --跳过table类型字段
            goto continue
        end
        -- 所有值转成字符串存储
        table.insert(data, field)
        table.insert(data, tostring(value))
        ::continue::
    end
    db:hmset(key, table.unpack(data))
end

------------------------------------------------------
-- 通用读取函数：把 Redis Hash 转换回 Lua table
-- 支持自动类型转换（数字转 number）
------------------------------------------------------
local function load_table(db, key)
    local raw = db:hgetall(key)
    local result = {}
    for field, value in pairs(raw) do
        -- 如果是纯数字字符串，转成 number
        local num = tonumber(value)
        if num ~= nil then
            result[field] = num
        else
            result[field] = value
        end
    end
    return result
end





local command = {}

-- redis 获取所有玩家城市数据
function command:rdb_get_user_ids()
    assert(rdb ~= nil, "Redis DB not initialized")
    -- city:ids  保存所有玩家城市ID的key set
    local city_ids = rdb:smembers("city:ids")
    if not city_ids then
        skynet.error("Failed to get city ids from redis")
    end

    return city_ids
end


-- redis 获取单个玩家所有城市数据
function command:rdb_get_city_data(user_id)
    -- 城市基本数据
    local city_key = "city:" .. tostring(user_id)
    local city_data = load_table(rdb, city_key)

    -- 城市建筑数据
    -- 建筑ID表
    local buildings_key = "city:" .. tostring(user_id) .. ":buildings"
    local building_ids = rdb:smembers(buildings_key)
    if building_ids ~= nil then
        local buildings = {}
        for _, bid in ipairs(building_ids) do
            local building_keys = "building:" .. tostring(bid)
            local building_data = load_table(rdb, building_keys)
            buildings[tonumber(bid)] = building_data
        end
        city_data.buildings = buildings
    end

    -- 城市资源数据
    local resources_key = "city:" .. tostring(user_id) .. ":resources"
    local resource_data = load_table(rdb, resources_key)
    city_data.resources = resource_data

    -- 城市部队编组数据
    local formations_key = "city:" .. tostring(user_id) .. ":formations"
    local formation_ids = rdb:smembers(formations_key)
    if formation_ids ~= nil then
        local formations = {}
        for _, fid in ipairs(formation_ids) do
            local formation_keys = "formation:" .. tostring(fid)
            local formation_data = skynet.unpack(rdb:get(formation_keys))
            formations[tonumber(fid)] = formation_data
        end
        city_data.formations = formations
    end
end

-- 保存单个玩家城市数据到 redis
function command:rdb_save_city_data(user_id, city_data)
    assert(rdb ~= nil, "Redis DB not initialized")
    -- 城市基本数据
    local city_key = "city:" .. tostring(user_id)
    save_table(rdb, city_key, city_data)

    
    -- 城市建筑数据
    if city_data.buildings ~= nil then
        -- 先保存建筑ID表
        local buildings_key = "city:" .. tostring(user_id) .. ":buildings"
        local building_ids = {}
        for bid, _ in pairs(city_data.buildings) do
            table.insert(building_ids, tostring(bid))
        end
        rdb:del(buildings_key)
        if #building_ids > 0 then
            rdb:sadd(buildings_key, table.unpack(building_ids))
        end
        -- 保存每个建筑数据
        for bid, building_data in pairs(city_data.buildings) do
            local building_key = "building:" .. tostring(bid)
            save_table(rdb, building_key, building_data)
        end
    end
    -- 城市资源数据
    if city_data.resources ~= nil then
        local resources_key = "city:" .. tostring(user_id) .. ":resources"
        save_table(rdb, resources_key, city_data.resources)
    end
    -- 城市部队编组数据
    if city_data.formations ~= nil then
        -- 先保存编组ID表
        local formations_key = "city:" .. tostring(user_id) .. ":formations"
        local formation_ids = {}
        for fid, _ in pairs(city_data.formations) do
            table.insert(formation_ids, tostring(fid))
        end
        rdb:del(formations_key)
        if #formation_ids > 0 then
            rdb:sadd(formations_key, table.unpack(formation_ids))
        end
        -- 保存每个编组数据
        for fid, formation_data in pairs(city_data.formations) do
            local formation_key = "formation:" .. tostring(fid)
            rdb:set(formation_key, skynet.pack(formation_data))
        end
    end
end

-- 保存建筑数据到 redisdb
function command:rdb_save_building(user_id, building_data)
    assert(rdb ~= nil, "Redis DB not initialized")
    -- 保存建筑数据
    local building_key = "building:" .. tostring(building_data.id)
    save_table(rdb, building_key, building_data)
    -- 把建筑ID加入城市建筑ID表
    local buildings_key = "city:" .. tostring(user_id) .. ":buildings"
    rdb:sadd(buildings_key, tostring(building_data.id))
end

-- 保存编队数据到 redisdb
function command:rdb_save_formation(user_id, formation_data)
    assert(rdb ~= nil, "Redis DB not initialized")
    -- 保存编队数据
    local formation_key = "formation:" .. tostring(formation_data.id)
    rdb:set(formation_key, skynet.pack(formation_data))
    -- 把编队ID加入城市编队ID表
    local formations_key = "city:" .. tostring(user_id) .. ":formations"
    rdb:sadd(formations_key, tostring(formation_data.id))
end

-- 删除编队数据 redis_db
function command:rdb_delete_formation(user_id, formation_id)
    assert(rdb ~= nil, "Redis DB not initialized")
    -- 删除编队数据
    local formation_key = "formation:" .. tostring(formation_id)
    rdb:del(formation_key)
    -- 从城市编队ID表移除编队ID
    local formations_key = "city:" .. tostring(user_id) .. ":formations"
    rdb:srem(formations_key, tostring(formation_id))
end


-- 保存任务到表
function command:rdb_save_task(user_id, task_data)
    assert(rdb ~= nil, "Redis DB not initialized")
    -- 保存任务数据
    local task_key = "task:" .. tostring(task_data.id)
    rdb:set(task_key, skynet.pack(task_data))
    -- 把任务ID加入用户任务ID表
    local tasks_key = "user:" .. tostring(user_id) .. ":tasks"
    rdb:sadd(tasks_key, tostring(task_data.id))
end

-- 删除任务数据 redis_db
function command:rdb_delete_task(user_id, task_id)
    assert(rdb ~= nil, "Redis DB not initialized")
    -- 删除任务数据
    local task_key = "task:" .. tostring(task_id)
    rdb:del(task_key)
    -- 从用户任务ID表移除任务ID
    local tasks_key = "user:" .. tostring(user_id) .. ":tasks"
    rdb:srem(tasks_key, tostring(task_id))
end




skynet.start(function()

    rdb = redis.connect{
        host = config.redis.host,
        port = config.redis.port,
        db = config.redis.db,
        auth = config.redis.auth,
    }
    if not rdb then
        error("Failed to connect to Redis server")
    end
    print("redis success to connect to redis server")


	skynet.dispatch("lua", function(session, address, cmd, ...)
		--cmd = cmd:upper()
		local f = command[cmd]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			error(string.format("Unknown command %s", tostring(cmd)))
		end
	end)

end)

