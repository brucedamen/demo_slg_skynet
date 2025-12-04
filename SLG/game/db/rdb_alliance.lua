local skynet = require "skynet"
local mysql = require "skynet.db.mysql"
local config = require "config_db"
local redis = require "skynet.db.redis"

local sqldb = nil
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


local command = {}

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





-- 获取所有联盟数据从redisdb
function command.rdb_get_all_alliance()
    -- alliance:ids  保存所有联盟ID的key set
    -- alliance:1001 {id= 1001, name= "Alliance1", level= 5, leader_id= 2001, member_count= 50}  -- 联盟基本信息  hash
    -- alliance:members:1001 {2001,2002, ...}      -- 联盟成员表  set
    -- alliance:applied_members:1001 {3001, 3002, ...}      -- 联盟申请成员表 set
    -- member:2001 {id= 2001, name= "Player1", role= "leader"}  -- 成员基本信息  hash
    -- applied_member:2001 {id= 2001, name= "Player1", role= "role"}  -- 申请成员基本信息  hash

    local alliance_ids = rdb:smembers("alliance:ids")
    if alliance_ids then
        -- 从ID表中获取每个联盟的基本信息
        local alliances = {}
        for _, id in ipairs(alliance_ids) do
            local alliance_id = tonumber(id)
            -- 获取联盟基本信息
            local key = "alliance:" .. tostring(alliance_id)
            local alliance_data = load_table(rdb, key)
            alliances[alliance_id] = alliance_data

            -- 获取成员列表
            local members_key = "alliance:" .. tostring(alliance_id) .. ":members"
            local members_list = rdb:smembers(members_key)
            local member_entries = {}
            for _, id in ipairs(members_list) do  --必定有leader,无需判断空
                local member_key = "member:" .. tostring(id)
                local member_data = load_table(rdb, member_key)
                member_entries[member_data.id] = member_data
            end
            alliances[alliance_id].members = member_entries

            -- 获取申请成员列表
            local applied_members_key = "alliance:" .. tostring(alliance_id) .. ":applied_members"
            local applied_members_list = rdb:smembers(applied_members_key)
             alliances[alliance_id].applied_members = {}
            if( applied_members_list ~= nil ) then --- 可能无人申请
                for _, id in ipairs(applied_members_list) do
                    local member_key = "member:" .. tostring(id)
                    local member_data = load_table(rdb, member_key)
                    alliances[alliance_id].applied_members[member_data.id] = member_data
                end
            end

            -- 获取互助任务列表
            alliances[alliance_id].assist_tasks = {}
            local aid_tasks_key = "alliance:" .. tostring(alliance_id) .. ":aid_tasks"
            local aid_task_ids = rdb:smembers(aid_tasks_key)
            if ( aid_task_ids ~= nil ) then-- 可能无互助任务
                for _, task_id in ipairs(aid_task_ids) do
                    local task_key = "alliance:" .. tostring(alliance_id) .. ":aid_task:" .. tostring(task_id)
                    local helper_ids = rdb:smembers(task_key)
                    -- 构建任务对象
                    local task = {
                        id = tonumber(task_id),
                        helper_ids = {},
                    }
                    if( helper_ids ~= nil ) then -- 可能无人帮助
                        for _, hid in ipairs(helper_ids) do
                            table.insert(task.helper_ids, tonumber(hid))
                        end
                    end
                    table.insert(alliances[alliance_id].assist_tasks, task)
                end
            end

        end
        return alliances
    end
end

-- 保存单个联盟数据到redisdb
function command.rdb_save_alliance(alliance)

    -- 更新 联盟存在表
    rdb:sadd("alliance:ids", alliance.id)


    -- 存 alliance 基本信息（save_table会过滤table，覆盖原有数据）
    save_table( rdb, "alliance:"..alliance.id, alliance)


    -- 存成员列表（成员table,单独处理）
    for _, m in ipairs(alliance.members) do
        rdb:sadd("alliance:"..alliance.id..":members", m.id)
        save_table(rdb, "member:"..m.id, m)
    end

    -- 存申请成员列表
    for id, m in ipairs(alliance.applied_members) do
        if( rdb:incr("applied_member:"..m.id..":ref_count") == 1) then 
            rdb:sadd("alliance:"..alliance.id..":applied_members", m.id)
            save_table(rdb, "applied_member:"..m.id, m)
        end
    end

    -- 保存联盟互助任务列表
    for _, task in ipairs(alliance.assist_tasks) do
        -- 任务id set
        rdb:sadd("alliance:"..alliance.id..":aid_tasks", task.id)
        -- 存储任务基本信息
        local task_key = "alliance:"..alliance.id..":aid_task:"..task.id
        rdb:sadd(task_key, tostring(task.id))
    end
end

-- 移除联盟
function command.rdb_remove_alliance(alliance_id)
    -- 移除 联盟存在表
    rdb:srem("alliance:ids", alliance_id)

    -- 移除 联盟基本信息
    rdb:del("alliance:"..alliance_id)

    -- 移除 成员信息
    local members_key = "alliance:"..alliance_id..":members"
    local member_ids = rdb:smembers(members_key)
    for _, member_id in ipairs(member_ids) do
        rdb:del("member:"..member_id)
    end
    rdb:del(members_key)

    -- 移除 申请成员信息
    local applied_members_key = "alliance:"..alliance_id..":applied_members"
    local applied_member_ids = rdb:smembers(applied_members_key)

    for _, member_id in ipairs(applied_member_ids) do
        -- 引用校验，移除申请成员信息
        if( rdb:decr("applied_member:"..member_id..":ref_count") == 0) then
            rdb:del("applied_member:"..member_id)
        end
    end
    -- 删除申请成员列表
    rdb:del(applied_members_key)

    -- 移除 互助任务信息
    local aid_tasks_key = "alliance:"..alliance_id..":aid_tasks"
    local aid_task_ids = rdb:smembers(aid_tasks_key)
    for _, task_id in ipairs(aid_task_ids) do
        local task_key = "alliance:"..alliance_id..":aid_task:"..task_id
        rdb:del(task_key)
    end
    rdb:del(aid_tasks_key)

end

-- 联盟添加成员
function command.rdb_add_alliance_member(alliance_id, member)
    -- 添加成员ID到成员列表
    rdb:sadd("alliance:"..alliance_id..":members", member.id)
    -- 保存成员基本信息
    save_table(rdb, "member:"..member.id, member)
end

-- 联盟移除成员
function command.rdb_remove_alliance_member(alliance_id, member_id)
    -- 从成员列表移除成员ID
    rdb:srem("alliance:"..alliance_id..":members", member_id)
    -- 删除成员基本信息
    rdb:del("member:"..member_id)
end
-- 添加联盟申请成员
function command.rdb_add_alliance_applied_member(alliance_id, member)
    -- 添加申请成员ID到申请成员列表
    rdb:sadd("alliance:"..alliance_id..":applied_members", member.id)
    -- 保存申请成员基本信息
    if( rdb:incr("applied_member:"..member.id..":ref_count") == 1 ) then
        save_table(rdb, "applied_member:"..member.id, member)
    end
end
-- 移除联盟申请成员
function command.rdb_remove_alliance_applied_member(alliance_id, member_id)
    -- 从申请成员列表移除成员ID
    rdb:srem("alliance:"..alliance_id..":applied_members", member_id)
    -- 删除申请成员基本信息
    if( rdb:decr("applied_member:"..member_id..":ref_count") == 0 ) then
        rdb:del("applied_member:"..member_id)
    end
end
-- 添加联盟互助任务
function command.rdb_add_alliance_aid_task(alliance_id, task)
    -- 任务id set
    rdb:sadd("alliance:"..alliance_id..":aid_tasks", task.id)
end
-- 移除联盟互助任务
function command.rdb_remove_alliance_aid_task(alliance_id, task_id)
    -- 从任务id set移除
    rdb:srem("alliance:"..alliance_id..":aid_tasks", task_id)
    -- 删除任务基本信息
    local task_key = "alliance:"..alliance_id..":aid_task:"..task_id
    rdb:del(task_key)
end
-- 添加互助任务帮助者
function command.rdb_add_alliance_aid_task_helper(alliance_id, task_id, helper_id)
    local task_key = "alliance:"..alliance_id..":aid_task:"..task_id
    rdb:sadd(task_key, tostring(helper_id))
end





--获取联盟列表
function command.get_all_alliance()

	local res = db:query("SELECT * FROM alliances")
    if not res then
        skynet.error("Failed to query alliance table")
    end

	skynet.error("alliance_data: ", dump(res))


	return res
end



-- 保存联盟基本信息
function command.save_alliance_basic_info(alliance)
    local sql = string.format("REPLACE INTO alliance (alliance_id, name, level, leader_id, member_count) VALUES (%d, %s, %d, %d, %d)",
        alliance.alliance_id,
        mysql.quote_sql_str(alliance.name),
        alliance.level,
        alliance.leader_id,
        alliance.member_count
    )
    local res = db:execute(sql)
    if not res then
        skynet.error("Failed to save alliance basic info for ID:", alliance.alliance_id)
    end

end
-- 移除联盟
function command.remove_alliance(alliance_id)
    -- 删除联盟基本信息
    local sql = string.format("DELETE FROM alliances WHERE id = %d",
        alliance_id
    )
    local res = db:execute(sql)
    if not res then
        skynet.error("Failed to remove alliance basic info for ID:", alliance_id)
    end
    -- 同时移除相关成员和申请数据
    command.remove_alliance_applied_members(alliance_id)
    command.delete_alliance_members(alliance_id)
    command.delete_alliance_aid_tasks(alliance_id)
end

--获取联盟成员列表
function command.get_alliance_members(alliance_id)
    local res = db:query("SELECT * FROM alliance_members WHERE alliance_id = ".. alliance_id)
    if not res then
        skynet.error("Failed to query alliance_members table for alliance_id:", alliance_id)
    end

	skynet.error("alliance_members: ", dump(res))

	return res
end
-- 保存联盟成员
function command.save_alliance_member(alliance_id, member)

    local sql = string.format("REPLACE INTO alliance_members (alliance_id, member_id, member_name, role) VALUES (%d, %d, %s, %s)",
        alliance_id,
        member.id,
        mysql.quote_sql_str(member.name),
        mysql.quote_sql_str(member.role)
    )
    local res = db:query(sql)
    if not res then
        skynet.error("Failed to save alliance member ID:", member.id, "for alliance ID:", alliance_id)
    end
end
-- 清除联盟所有成员
function command.delete_alliance_members(alliance_id)
    local sql = string.format("DELETE FROM alliance_members WHERE alliance_id = %d",
        alliance_id
    )
    local res = db:query(sql)
    if not res then
        skynet.error("Failed to delete alliance members for alliance ID:", alliance_id)
    end
    return true
end


-- 获取联盟申请成员列表
function command.get_alliance_applied_members(alliance_id)
    local res = db:query("SELECT * FROM alliance_applied_members WHERE alliance_id = ".. mysql.quote_sql_str(alliance_id))
    if not res then
        skynet.error("Failed to query alliance_applied_members table for alliance_id:", alliance_id)
    end

	print("alliance_applied_members: ", dump(res))

	return res
end
-- 保存联盟申请成员
function command.save_alliance_applied_member(alliance_id, member)
    local sql = string.format("REPLACE INTO alliance_applied_members (alliance_id, member_id, member_name) VALUES (%d, %d, %s)",
        alliance_id,
        member.id,
        mysql.quote_sql_str(member.name)
    )
    local res = db:execute(sql)
    if not res then
        skynet.error("Failed to save alliance applied member ID:", member.id, "for alliance ID:", alliance_id)
    end
end

-- 清除联盟所有申请成员
function command.remove_alliance_applied_members(alliance_id)
    local sql = string.format("DELETE FROM alliance_applied_members WHERE alliance_id = %d",
        alliance_id
    )
    local res = db:query(sql)
    if not res then
        skynet.error("Failed to delete alliance applied members for alliance ID:", alliance_id)
    end
    return true
end
-- 清除联盟申请成员
function command.remove_alliance_applied_member(alliance_id, member_id)
    local sql = string.format("DELETE FROM alliance_applied_members WHERE alliance_id = %d AND member_id = %d",
        alliance_id,
        member_id
    )
    local res = db:query(sql)
    if not res then
        skynet.error("Failed to delete alliance applied members for alliance ID:", alliance_id)
    end
    return true
end

-- 获取联盟互助任务列表
function command.get_alliance_aid_tasks(alliance_id)
    local res = db:query("SELECT * FROM alliance_aid_tasks WHERE alliance_id = ".. mysql.quote_sql_str(alliance_id))
    if not res then
        skynet.error("Failed to query alliance_aid_tasks table for alliance_id:", alliance_id)
    end
    -- 以，分隔的帮助者ID字符串 转换为 表
    for _, task in ipairs(res) do
        if task.helper_ids and task.helper_ids ~= "" then
            local helper_ids = {}
            for id in string.gmatch(task.helper_ids, '([^,]+)') do
                table.insert(helper_ids, id)
            end
            task.helper_ids = helper_ids
        else
            task.helper_ids = {}
        end
    end

	print("alliance_help_tasks: ", dump(res))
    return res
end

-- 更新联盟互助任务帮助者列表
function command.update_alliance_aid_task_helpers(alliance_id, task)
    -- 更新，没有就插入
    local sql = string.format("INSERT INTO alliance_aid_tasks (alliance_id, task_id, helper_ids) VALUES (%d, %d, %s) ON DUPLICATE KEY UPDATE helper_ids = VALUES(helper_ids);",
        alliance_id,
        task.id,
        mysql.quote_sql_str(table.concat(task.helper_ids, ","))
    )
    local res = sqldb:execute(sql)
    if not res then
        skynet.error("Failed to update alliance aid task ID:", task.id, "for alliance ID:", alliance_id)
    end
end

-- 移除联盟互助任务
function command.remove_alliance_aid_task(alliance_id, task_id)
    local sql = string.format("DELETE FROM alliance_aid_tasks WHERE alliance_id = %d AND task_id = %d",
        alliance_id,
        task_id
    )
    local res = sqldb:execute(sql)
    if not res then
        skynet.error("Failed to remove alliance aid task ID:", task_id, "from alliance ID:", alliance_id)
    end
    return true
end


skynet.start(function()
	local function on_connect(db)
		db:query("set charset utf8mb4");
	end
	sqldb=mysql.connect({
		host=config.sql.host,
		port=config.sql.port,
		database=config.sql.database,
		user=config.sql.user,
		password=config.sql.password,
        charset="utf8mb4",
		max_packet_size = 1024 * 1024,
		on_connect = on_connect
	})
	if not sqldb then
		print("failed to connect")
	end
	print("mysql success to connect to mysql server")

    rdb = redis.connect{
        host = config.redis.host,
        port = config.redis.port,
        db = config.redis.db,
        auth = config.redis.auth,
    }
    if not rdb then
        print("failed to connect to redis")
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

