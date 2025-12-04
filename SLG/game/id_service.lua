-- ID生成服务 
local skynet = require "skynet"
local idgen = {}
local sequence = 0
local last_ts = 0


local function now()
    return math.floor(skynet.time() * 1000)  -- 毫秒
end

function idgen.next_id()
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


-- 服务入口
skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = idgen[cmd]
        if f then
            skynet.ret(skynet.pack(f(source,...)))
        else
            skynet.ret(skynet.pack(nil, "Unknown command: " .. cmd))
        end
    end)
end)