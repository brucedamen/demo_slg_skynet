local skynet = require "skynet"
local mysql = require "skynet.db.mysql"


local db

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

local function test2( db)
    local i=1
    while true do
        local    res = db:query("select * from cats order by id asc")
        print ( "test2 loop times=" ,i,"\n","query result=",dump( res ) )
        res = db:query("select * from cats order by id asc")
        print ( "test2 loop times=" ,i,"\n","query result=",dump( res ) )

        skynet.sleep(1000)
        i=i+1
    end
end
local function test3( db)
    local i=1
    while true do
        local    res = db:query("select * from cats order by id asc")
        print ( "test3 loop times=" ,i,"\n","query result=",dump( res ) )
        res = db:query("select * from cats order by id asc")
        print ( "test3 loop times=" ,i,"\n","query result=",dump( res ) )
        skynet.sleep(1000)
        i=i+1
    end
end
local function test4( db)
	local stmt = db:prepare("SELECT * FROM cats WHERE name=?")
    print ( "test4 prepare result=",dump( stmt ) )
	local res = db:execute(stmt,'Bob')
    print ( "test4 query result=",dump( res ) )
    db:stmt_close(stmt)
end

-- 测试存储过程和blob读写
local function test_sp_blob(db)
	print("test stored procedure")
	-- 创建测试表
	db:query "DROP TABLE IF EXISTS `test`"
	db:query [[
		CREATE TABLE `test` (
			`id` int(11) NOT NULL AUTO_INCREMENT,
			`str` varchar(45) COLLATE utf8mb4_bin DEFAULT NULL,
			`dt` timestamp NULL DEFAULT NULL,
			`flt` double DEFAULT NULL,
			`blb` mediumblob,
			`num` int(11) DEFAULT NULL,
			PRIMARY KEY (`id`),
			UNIQUE KEY `id_UNIQUE` (`id`)
			) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
	]]
	-- 创建测试存储过程
	db:query "DROP PROCEDURE IF EXISTS `get_test`"
	db:query [[
		CREATE PROCEDURE `get_test`(IN p_id int)
		BEGIN
			select * from test where id=p_id;
		END
	]]
	local stmt_insert = db:prepare("INSERT test (str,dt,flt,num,blb) VALUES (?,?,?,?,?)")
	local stmt_csp = db:prepare("call get_test(?)")
	local test_blob = string.char(0xFF,0x8F,0x03,0x04,0x0a,0x0b,0x0d,0x0e,0x10,0x20,0x30,0x40)

	local r = db:execute(stmt_insert,'test_str','2020-3-20 15:30:40',3.1415,89,test_blob)
	print("insert result : insert_id",r.insert_id,"affected_rows",r.affected_rows
		,"server_status",r.server_status,"warning_count",r.warning_count)

	r = db:execute(stmt_csp,1)
	local rs = r[1][1]
	print("call get_test() result : str",rs.str,"dt",rs.dt,"flt",rs.flt,"num",rs.num
		,"blb len",#rs.blb,"equal",test_blob==rs.blb)

	print("test stored procedure ok")
end

local function test_signed(db)
    local res = db:query("drop table if exists test_i_u")
    res = db:query("create table test_i_u (i tinyint primary key, u tinyint unsigned)")
    print(dump(res))

    res = db:query("insert into test_i_u (i,u) values (-1,1),(127,128),(-127,255)")
    print(dump(res))

    local prep = "SELECT * FROM test_i_u"
    local stmt = db:prepare(prep)
    local res = db:execute(stmt)
    print("test_i_u: ", dump(res))
    db:stmt_close(stmt)
end



local command = {}
--用户登录
function command.user_login(name, password)
	skynet.error("user_login:", name, password)

	res = db:query("SELECT * FROM users WHERE username = "
				.. db.quote_sql_str(name) .. " AND password = "
				.. db.quote_sql_str(password))
	print("user_login query: ", dump(res))

	--写入登录时间和日志（不够重要的操作，可以不做事务处理）
	if #res == 1 then
		print("user_login result: ", dump(res))

		local uid = res[1].id
		local time = os.date("%Y-%m-%d %H:%M:%S")
		prep = "UPDATE users SET last_login = "
				.. db.quote_sql_str(time)
				.. " WHERE id = " .. db.quote_sql_str(uid)
		res = db:query(prep)
		print("update last_login: ", dump(res))

		prep = "INSERT INTO login_log (uid, login_time, ip) VALUES ("
				.. db.quote_sql_str(uid) .. ", "
				.. db.quote_sql_str(time) .. ", "
				.. db.quote_sql_str("<client_ip>") .. ")"
		res = db:query(prep)
		print("insert login_log: ", dump(res))
	end


	return res
end


--用户注册，写入注册时间和日志
function command.user_register(name, password)
	local time = os.date("%Y-%m-%d %H:%M:%S")
	local prep = "INSERT INTO users (username, password, register_time) VALUES ("
				.. db.quote_sql_str(name) .. ", "
				.. db.quote_sql_str(password) .. ", "
				.. db.quote_sql_str(time) .. ")"
	local stmt = db:prepare(prep)
	local res = db:execute(stmt)
	print("user_register: ", dump(res))
	db:stmt_close(stmt)
	if res.affected_rows == 1 then
		local uid = res.insert_id
		prep = "INSERT INTO register_log (uid, register_time, ip) VALUES ("
				.. db.quote_sql_str(uid) .. ", "
				.. db.quote_sql_str(time) .. ", "
				.. db.quote_sql_str("<client_ip>") .. ")"
		stmt = db:prepare(prep)
		res = db:execute(stmt)
		print("insert register_log: ", dump(res))
		db:stmt_close(stmt)
	end
	return res
end



skynet.start(function()
	local function on_connect(db)
		db:query("set charset utf8mb4");
	end
	db=mysql.connect({
		host="192.168.1.125",
		port=3306,
		database="skynet",
		user="root",
		password="brucedamensqlpw",
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

