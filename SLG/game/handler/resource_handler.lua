local skynet = require "skynet"

local handler = require "handler"




local REQUEST = {}
local CMD = {}
local user
handler = handler.new (REQUEST, nil, CMD)

handler:init (function (u)
	user = u
end)


-- 载入资源数据
function CMD.load_resources(resource_data)
    user.resources = resource_data or {food = 1000, wood = 1000, stone = 1000, iron = 1000}
    return true
end


--推送资源变动
local function push_resource_change(update)
    user.CMD.send_msg( "resource_change", { update = update } )
end

--资源相关请求处理
function REQUEST.resource_query(args)
    --拾取完毕返回当前资源
    return { success = true, resources = user.resources }
end

-- 资源扣除接口
function CMD.deduct_resources(cost)
    --检查资源是否足够
    for k, v in pairs(cost) do
        if user.resources[k] < v then
            return false
        end
    end
    --扣除资源
    for k, v in pairs(cost) do
        user.resources[k] = user.resources[k] - v
    end
    --推送资源变动
    local update = {}
    for k, v in pairs(cost) do
        update[k] = -v
    end
    push_resource_change(update)
    return true
end

-- 资源增加接口
function CMD.add_resources(gain)
    for k, v in pairs(gain) do
        user.resources[k] = user.resources[k] + v
    end
    push_resource_change(gain)
end


return handler