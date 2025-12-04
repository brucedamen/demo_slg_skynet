local skynet = require "skynet"
local redis  = require "skynet.db.redis"
local datacenter = require "skynet.datacenter"

local mysql
local redisdb
local authcenter

local redis_config = {
    host = "127.0.0.1",
    port = 6379,
    db   = 0,
    auth = "brucedamenredispw",
}


local command = {}

function command.login(username, password, region, device_id)
    print("Attempting login for user: " .. username)

    --验证用户名和密码
    --优先使用redis缓存验证账号密码
    local cached = redisdb:GET("userpass:" .. username)
    if cached and cached == password then

        --在redis中设置用户在线状态
        redisdb:SET("online:" .. username, "1")

        --创建一个持久化的token
        local token = skynet.call(authcenter, "lua", "login", username, region, device_id)
        if not token then
            return { success = 0, message = "Failed to create token" }
        end

        return { success = 1, token = token }
    end

    --查询MySQL数据库
    local res = skynet.call(mysql, "lua", "user_login", username, password)
    if #res == 1 then
        --在redis中设置用户在线状态
        redisdb:SET("online:" .. username, "1")

        --创建一个持久化的token
        local token = skynet.call(authcenter, "lua", "login", username, region, device_id)

        return { success = 1, token = token }
    else
        print("Login failed for user by mysql " .. username)
    end
    --返回失败
	return { success = 0, message = "Login failed please check username and password" }
end

--注册新用户
function command.register(username, password)
    local res = skynet.call(mysql, "lua", "user_register", username, password)
    if res then
        -- 写入redis缓存
        redisdb:SET("userpass:" .. username, password)
        return { success = 1 }
    else
        return { success = 0, message = "Registration failed, username may already exist" }
    end
end

-- 修改密码
function command.change_password(username, old_password, new_password)
    -- 验证旧密码
    local cached = redisdb:GET("userpass:" .. username)
    if cached and cached == old_password then
        -- 更新MySQL数据库中的密码
        local res = skynet.call(mysql, "lua", "user_change_password", username, new_password)
        if res then
            -- 更新redis缓存
            redisdb:SET("userpass:" .. username, new_password)
            return { success = 1 }
        else
            return { success = 0, message = "Failed to update password in database" }
        end
    else
        return { success = 0, message = "Old password is incorrect" }
    end
end



skynet.start(function()

    redisdb = redis.connect(redis_config)
    print("success to connect to login redis  server")

    mysql = datacenter.get("mysql")
    authcenter = datacenter.get("auth")

    print("login server success to get to login mysql server:", mysql)
    print("login server success to get to login auth server:", authcenter)


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
