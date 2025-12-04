-- authcenter.lua
local skynet = require "skynet"
local crypt = require "skynet.crypt"
local redis = require "skynet.db.redis"

local CMD = {}
local rdb



--权限中心使用单独的redis数据库
local conf = {
	host = "192.168.1.125",
    port = 6379,
    db   = 1,
    auth = "brucedamenredispw",
}

local function add_key_value_pairs(key, data)
    local t = {}
    --将data表转换为key1, value1, key2, value2, ... 然后写入redis
    for k, v in pairs(data) do
        table.insert(t, k)
        table.insert(t, v)
    end
    rdb:hmset(key, table.unpack(t))
end

--生成随机token
local function gen_token()
    return crypt.hexencode(crypt.randomkey())
end
-- 登录后生成长期 token
function CMD.login(uid, region, device_id, scopes)
    --查询用户是否存在，存在则移除旧key
    local user_key = "user:" .. uid
    local t = rdb:type(user_key)
    if t ~= "none" then
        local old_token = rdb:get(user_key)
        --移除旧 token
        local old_token_key = "token:long:" .. old_token
        rdb:del(old_token_key)
    end

    --生成一个长期 token，存储在 redis 中，设置过期时间为30
    local token = gen_token()
    rdb:set(user_key, token)
    local key = "token:long:" .. token
    --单次写入多条hmset,减少网络开销
    add_key_value_pairs(key, {
        user_id = uid,
        region = region,
        device_id = device_id,
        scopes = scopes --用逗号分隔的权限列表
    })
    rdb:expire(key, 30 * 24 * 3600)

    return token
end

-- 置换长期 token
function CMD.replace_long_token(old_token, region, device_id)
    local key = "token:long:" .. old_token
    if rdb:exists(key) == 0 then
        return nil, "old token not found"
    end
    --一次性读取所有字段
    local token_data = rdb:hmget(key, "user_id", "region", "device_id", "scopes")
    if not token_data[1] then
        return nil, "old token invalid"
    end
    local uid = token_data[1]
    local expected_region = token_data[2]
    local expected_device = token_data[3]
    local scopes = token_data[4]
    -- region 和 device_id 是否匹配
    if expected_region ~= region then
        return nil, "region mismatch"
    end
    if expected_device ~= device_id then
        return nil, "device_id mismatch"
    end


    --移除旧 tokens（ 先移除，以防万一 写入过程中出错 导致多个 token 并存，失败最多也就重新登录）
    rdb:del(key)

    --生成一个新的长期 token，存储在 redis 中，设置过期时间为30天
    local new_token = gen_token()
    rdb:set("user:" .. uid, new_token)
    local new_key = "token:long:" .. new_token
    --单次写入多条hmset,减少网络开销
    add_key_value_pairs(new_key, {
        user_id = uid,
        region = region,
        device_id = device_id,
        scopes = scopes --用逗号分隔的权限列表
    })
    rdb:expire(new_key, 30 * 24 * 3600)
    
    return new_token
end

--登出，移除长期 token
function CMD.logout(uid, token)
    print("Auth logout for user: " .. uid)
    local user_key = "user:" .. uid
    if rdb:exists(user_key) ~= 0 then
        local token = rdb:get(user_key)
        --移除 token
        local token_key = "token:long:" .. token
        rdb:del(token_key)
    end
end

-- 使用长期 token(比如登陆器) 请求限定权限范围的短期 token
function CMD.issue_short_token(long_token, region, device_id, scope)
    local key = "token:long:" .. long_token
    if rdb:exists(key) == 0 then
        return nil, "long token not found"
    end

    --一次性读取所有字段
    local token_data = rdb:hmget(key, "user_id", "region", "device_id", "scopes")
    if not token_data[1] then
        return nil, "long token invalid"
    end
    local uid = token_data[1]
    local expected_region = token_data[2]
    local expected_device = token_data[3]
    local required_scope = token_data[4]

    -- region 和 device_id 是否匹配
    if expected_region ~= region then
        return nil, "region mismatch"
    end
    if expected_device ~= device_id then
        return nil, "device_id mismatch"
    end

    --查询申请的临时权限是否在长期 token 的权限范围内
    --if not required_scope or required_scope == "" then
    --    return nil, "no scopes defined"
    --end 
    --local scope_map = split(required_scope, ",")
    --申请游戏服权限,绑定游戏服，比如有些测试服需要特定权限
    --if not scope_map[scope]  then
    --    return nil, "permission denied"
    --end


    --查询用户该服务器是否已有短期 token，存在则移除旧 token
    local user_key = "user:short:" .. uid..scope
    local t = rdb:type(user_key)
    if t ~= "none" then
        local old_token = rdb:get(user_key)
        --移除旧 token
        local old_token_key = "token:short:" .. old_token
        rdb:del(old_token_key)
    end

    local short_token = gen_token()
    local short_key = "token:short:" .. short_token
    rdb:set(user_key, short_token)

    --单次写入多条hmset,减少网络开销
    add_key_value_pairs(short_key, {
        user_id = uid,
        region = region,
        device_id = device_id,
        scope = scope
    })
    rdb:expire(short_key, 600)

    return short_token
end

-- 游戏服验证短期 token
function CMD.verify_short_token(short_token, region, device_id)
    local key = "token:short:" .. short_token
    if rdb:exists(key) == 0 then
        return nil, "short token not found"
    end

    --一次性读取所有字段
    local token_data = rdb:hmget(key, "user_id", "region", "device_id")
    if not token_data[1] then
        return nil, "short token invalid"
    end

    --
    local uid = token_data[1]
    local expected_region = token_data[2]
    local expected_device = token_data[3]

    --验证region 和 device_id 是否匹配
    if expected_region ~= region then
        return nil, "region mismatch"
    end
    if expected_device ~= device_id then
        return nil, "device_id mismatch"
    end

    return uid
end

skynet.start(function()
    rdb = redis.connect(conf)

    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        skynet.retpack(f(...))
    end)
end)

