local skynet = require "skynet"
local handler = require "handler"

local config = require "config_items"


local REQUEST = {}
local CMD = {}
local user
handler = handler.new (REQUEST, nil, CMD)

handler:init (function (u)
	user = u
end)

--物品相关请求处理
function REQUEST.item_use(args)
    --资源类物品使用
    if not args.item_id then
        return { success = false, error = "invalid_arguments" }
    end

    -- 调用移除物品接口
    if not CMD.remove_item(args.item_id, args.count or 1) then
        return { success = false, error = "insufficient_item_count" }
    end

    --查询物品实际配置
    local itemdata = config.items[args.item_id]
    if not itemdata then
        return { success = false, error = "item_config_not_found" }
    end

    --增加资源
    if itemdata.type == "resource" then
        --使用resource_handler的接口增加资源
        user.CMD.add_resources(itemdata.resource)
    end

    -- 减少时间类物品使用
    if itemdata.type == "time" then
        if not args.target_id then
            return { success = false, error = "invalid_arguments" }
        end
        --调用task_handler的接口减少任务时间
        user.CMD.task_speedup(args.target_id, itemdata.duration, itemdata.limit_type)
    end

    

    return { success = true }
end

-- 移除物品接口
function CMD.remove_item(item_id, count)
    count = count
    --检查物品是否存在
    local item= user.items[item_id]
    if not item then
        return false, "item_not_found"
    end
    if item.count < count then
        return false, "insufficient_item_count"
    end
    item.count = item.count - count
    if item.count == 0 then
        user.items[item_id] = nil
    end
    return true
end

--增加物品接口
function CMD.add_item(item_id, count)
    count = count or 1
    --检查物品配置是否存在
    local itemdata = config.items[item_id]
    if not itemdata then
        return false, "item_config_not_found"
    end

    --增加物品到用户物品列表
    local item= user.items[item_id]
    if item then
        item.count = item.count + count
        return true
    else
        user.items[item_id] = { id = item_id, count = count }
    end

    user.send_package( user.request("item_update", { id = item_id, count = count }))

    return true
end

return handler