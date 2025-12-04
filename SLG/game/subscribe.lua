-- 订阅服务, 管理游戏区域块的订阅和消息广播
local skynet = require "skynet"
local Subscribe = {}
local blocks = {} 



-- 添加订阅者
function Subscribe:subscription(agent, block_id_list)
    for _, block_id in ipairs(block_id_list) do
        if not blocks[block_id] then
            blocks[block_id] = {}
        end
        blocks[block_id][agent] = true
    end

    return block_id_list
end


--取消订阅
function Subscribe:unsubscribe(agent, block_id_list)
    for _, block_id in ipairs(block_id_list) do
        local agent_list = blocks[block_id]
        if agent_list then
            agent_list[agent] = nil
        end
    end
end


--移除观察者
function Subscribe:clear_viewer(agent)
    for block_id, agent_list in pairs(blocks) do
        agent_list[agent] = nil
    end
end



-- 广播消息到订阅的观察者
function Subscribe:broadcast_block(block_id, event, message)
    local agent_list = blocks[block_id]
    if agent_list and next(agent_list) then
        for agent, _ in pairs(agent_list) do
            skynet.send(agent, "lua","send_message", event, message)
        end
    end
end


-- 服务入口
skynet.start(function()
    skynet.dispatch("lua", function(_, _, command, ...)
        local f = Subscribe[command]
        if f then
            skynet.ret(skynet.pack(f(Subscribe, ...)))
        else
            skynet.error(string.format("Unknown command: %s", command))
        end
    end)
end)
