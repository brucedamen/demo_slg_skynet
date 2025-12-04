local skynet = require "skynet"
local datacenter = require "datacenter"

local city_map = {} --  user_id → city service

local CMD = {}
local mysql
local rdb




function CMD.load_by_mysql()
    -- 从 MySQL 加载玩家数据的逻辑
    local user_data = skynet.call(mysql, "lua", "get_user_data", user_id)
     --遍历玩家城市表
    for _, data in pairs(user_ids) do
        --查询玩家城市数据
        local user_id = data.user_id

        local citydata = skynet.call(mysql, "lua", "get_city_data", server, user_id)
        if not citydata then
            print("Failed to get city data for user", user_id)
            goto continue
        end

        -- 依序初始化城市服务
        local city  =  skynet.newservice("city")
        if not city then
            print("No available city service for user", user_id)
            goto continue
        end
        local ok, err = skynet.call(city, "lua", "init", citydata)
        if not ok then
            print("Failed to init city service for user", user_id, "error:", err)
            skynet.call(city, "lua", "exit")
            goto continue
        end
        -- 写入内部缓存
        city_map[user_id] = city

        skynet.sleep(1) --避免阻塞太久

        ::continue::
    end
end


--初始化整个服务器的玩家数据
function CMD.start()
    skynet.error("Starting city manager service...")


    local rdb = skynet.newservice("rdb_city")
	assert(rdb)

    mysql = datacenter.get("mysql_db")


    --查询所有玩家
    local user_ids = skynet.call(rdb, "lua", "rdb_get_user_ids")
    if not user_ids then
        skynet.error("Failed to get all user ids from rdb")
        CMD.load_by_mysql()
        return
    end

    --遍历玩家城市表
    for _, id in pairs(user_ids) do
        --查询玩家城市数据
        local user_id = id

        local citydata = skynet.call(rdb, "lua", "rdb_get_city_data",user_id)
        if not citydata then
            print("Failed to get city data for user", user_id)
            goto continue
        end

        -- 依序初始化城市服务
        local city  =  skynet.newservice("city")
        if not city then
            print("No available city service for user", user_id)
            goto continue
        end
        local ok, err = skynet.call(city, "lua", "initialize_city", citydata)
        if not ok then
            print("Failed to init city service for user", user_id, "error:", err)
            skynet.call(city, "lua", "exit")
            goto continue
        end
        -- 写入内部缓存
        city_map[user_id] = city

        skynet.sleep(1) --避免阻塞太久

        ::continue::
    end

end
--获取城市服务
function CMD.get_city_service(user_id)
    return city_map[user_id]
end


--创建用户城市服务
function CMD.create_city_service(user_id)

    --创建初始城市数据
    local city_data = {
        uuid = user_id,
        level = 1,
        name = "Player" .. tostring(user_id),
    }

    --创建新城市
    skynet.call(mysql, "lua", "create_new_city", user_id, city_data.name, city_data.level)

    --保存到redis
    skynet.call(rdb, "lua", "rdb_save_city_data", user_id, city_data)

    -- 启动城市服务
    local city =  skynet.newservice("city")
    -- 初始化城市数据
    skynet.call(city, "lua", "initialize_city", city_data)

    --写入内部缓存
    city_map[user_id] = city

    return city
end





skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            skynet.error("ciyt manager Unknown command:", cmd)
        end
    end)
end)
