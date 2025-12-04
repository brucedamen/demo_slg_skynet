local skynet = require "skynet"

local sequence = 0
local last_ts = 0

-- 获取当前时间戳（毫秒）
local function now()
    return math.floor(skynet.time() * 1000)
end

-- 生成下一个唯一 ID
local function next_id()
    local ts = now()
    if ts == last_ts then
        sequence = sequence + 1
    else
        sequence = 0
        last_ts = ts
    end
    -- 拼接成一个整数: 时间戳 << 16 | 序列号
    return (ts << 16) | sequence
end

-- Skynet 服务启动
skynet.start(function()
    skynet.dispatch("lua", function(_, source, cmd, ...)
        if cmd == "next_id" then
            local id = next_id()
            skynet.ret(skynet.pack(id))
        else
            skynet.ret(skynet.pack(nil, "Unknown command"))
        end
    end)
end)
