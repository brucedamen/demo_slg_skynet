local skynet = require "skynet"
local mysql = require "skynet.db.mysql"
local config = require "config_db"

local db = nil


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
    local res = db:query(sql)
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
    local res = db:query(sql)
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
    local res = db:query(sql)
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
    local res = db:query(sql)
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

