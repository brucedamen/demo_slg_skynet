local skynet = require "skynet"
local handler = require "handler"


local REQUEST = {}
local CMD = {}
local user
handler = handler.new (REQUEST, nil, CMD)

handler:init (function (u)
	user = u
end)

-- 聊天消息处理
function REQUEST.chat_send(args)
    -- 参数检查
    if not args.message or type(args.message) ~= "string" or #args.message == 0 then
        return { success = false, error = "invalid_message" }
    end
    -- 构造聊天消息
    local chat_message = {
        user_id = user.id,
        user_name = user.name,
        message = args.message,
        timestamp = os.time(),
    }

    -- 这里可以添加将聊天消息广播给其他玩家的逻辑
    skynet.send("chat_service", "lua", "broadcast_message", chat_message)
    return { success = true }
end


return handler