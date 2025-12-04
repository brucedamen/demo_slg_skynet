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





--获取所有玩家ID
function command.get_all_user( )
	local res = db:query("SELECT * FROM usercity")
    if not res then
        error("Failed to query user_to_city table")
    end
	return res
end


--获取单个玩家城市数据
function command.get_city_data(uuid)
	local res = db:query("SELECT * FROM  usercity WHERE uuid = ".. mysql.quote_sql_str(uuid))
    if not res then
        error("Failed to query city table")
    end

	print("get_city_data: ", dump(res))

	if res and #res > 0 then
		local data = res[1]
		return data
	end
	return nil
end
--创建新的玩家城市记录
function command.create_new_city( uuid, name, level )
	--插入新的城市记录
	db:query("INSERT INTO usercity (uuid, name, level) VALUES ("
				.. mysql.quote_sql_str(uuid) .. ", "
                .. mysql.quote_sql_str(name) .. ", "
                .. mysql.quote_sql_str(level) .. ")")
	
	return true
end

--创建/更新玩家建筑
function command.update_building( user_id, building_data )
    db:query("REPLACE INTO buildings (user_id, id, type, level, status) VALUES ("
                .. mysql.quote_sql_str(user_id) .. ", "
                .. mysql.quote_sql_str(building_data.id) .. ", "
                .. mysql.quote_sql_str(building_data.type) .. ", "
                .. mysql.quote_sql_str(building_data.level) .. ", "
                .. mysql.quote_sql_str(building_data.status) .. ")")
    return true
end

-- 玩家编队创建
function command.create_new_formation( user_id, formation_name, soldiers )
    db:query("INSERT INTO formations (user_id, name, soldiers) VALUES ("
                .. mysql.quote_sql_str(user_id) .. ", "
                .. mysql.quote_sql_str(formation_name) .. ", "
                .. mysql.quote_sql_str(skynet.pack(soldiers)) .. ")")
    --获取新插入编队的ID
    local res = db:query("SELECT LAST_INSERT_ID() AS id")
    if not res or #res == 0 then
        error("Failed to get last insert id for formation")
    end
    local new_id = res[1].id
    return new_id
end

-- 删除玩家编队
function command.delete_formation( formation_id )
    db:query("DELETE FROM formations WHERE id = " .. mysql.quote_sql_str(formation_id))
    return true
end





--游戏操作日志
function command.game_log(uid, action, result)
	local prep = "INSERT INTO game_log (uid, action, result) VALUES ("
				.. mysql.quote_sql_str(uid) .. ", "
				.. mysql.quote_sql_str(action) .. ", "
				.. mysql.quote_sql_str(result) .. ")"
	local stmt = db:prepare(prep)
	local res = db:execute(stmt)
	print("game_log: ", dump(res))
	db:stmt_close(stmt)
	return res	
end



skynet.start(function()
	local function on_connect(db)
		db:query("set charset utf8mb4");
	end
	db=mysql.connect({
		host=config.sql.host,
		port=config.sql.port,
		database=config.sql.database,
		user=config.sql.user,
		password=config.sql.password,
        charset="utf8mb4",
		max_packet_size = 1024 * 1024,
		on_connect = on_connect
	})
	if not db then
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

