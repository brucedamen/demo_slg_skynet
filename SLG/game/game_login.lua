local skynet = require "skynet"
local datacenter = require "datacenter"
local cluster = require "skynet.cluster"

local user_agent_map = {} -- city service address → agent

local CMD = {}
local server = 1
local mysql



-- 处理登录请求
function CMD.login(user_id, token, machine_id, agent)
    -- 验证 token  测试阶段先不验证
    --local auth_service = datacenter.get("auth")
    --local is_valid, err = cluster.call(auth_service, "lua", "validate_token", user_id, token)
    --if not is_valid then
    --    return false, "Invalid token: " .. (err or "unknown error")
    --end

    -- 检查是否已有登录的 agent  断开旧连接
    local old_agent = user_agent_map[user_id]
    if old_agent then
        skynet.call(old_agent, "lua", "kick")
    end
    user_agent_map[user_id] = agent
    

    return true
end

-- 处理登出请求
function CMD.logout(user_id)
    -- 清理映射 
    user_agent_map[user_id] = nil
    return true
end




skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            skynet.error("Unknown command:", cmd)
            skynet.ret(skynet.pack(nil, "Unknown command"))
        end
    end)
end)
