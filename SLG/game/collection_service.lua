local skynet = require "skynet"
local timewheel = require "time_wheel"
local config = require "config_resource_point"
local datacenter = require "skynet.datacenter"

local CMD = {}


local resource_point_data = {}
local world_service
local mysql_service
local id_service
local event_service


-- 计算采集奖励
local function calculate_rewards(resource_point, duration)

    local base_rate = resource_point.resource_rate or 100
    local total_amount = math.floor(base_rate * duration / 3600) -- 每小时产出
    
    local rewards = {wood = 0, stone = 0, food = 0, gold = 0}
    rewards[resource_point.resource_type] = total_amount
    return rewards
end



-- 初始化采集点组件
function CMD.init()
    skynet.error("Initializing resource point component")
    -- 加载采集点数据
    if mysql_service then
        resource_point_data = skynet.call(mysql_service, "lua", "load_resource_point_data")
    else
        -- 默认数据或从配置文件加载
        resource_point_data = {}
    end

    -- 向世界服务注册采集点数据
    local id_service = datacenter.get("id_service")
    for id, rp in pairs(resource_point_data) do
        skynet.call( world_service, "lua", "register_entity", CMD.get_display_attributes(rp))
    end
    

    return true
end
-- 创建资源点
function CMD.create_resource_point(level, resource_type)
    if not resource_type or not level then
        return false, "Invalid resource point data"
    end

    local id = skynet.call( id_service, "lua", "next_id")
    resource_point_data[id] = {
        id = id,
        level = level or 1,
        resource_type = resource_type,
        resource_rate = 100,
        resource_amount = 0,
    }

    -- 向世界服务注册采集点数据
    skynet.call( world_service, "lua", "register_entity", CMD.get_display_attributes(resource_point_data[id]) )

    return true
end


-- 获取显示属性（用于世界显示）
function CMD.get_display_attributes(point)
    local display_attributes = {
        id = point.id,
        type = "resource_point",
        level = point.level,
        resource_type = point.resource_type,
        resource_rate = point.resource_rate,
        resource_amount = point.resource_amount,
        defense_ids = point.occupied_id.formation_id or point.defense_ids,
    }
    return display_attributes
end



-- 开始采集
function CMD.start_collection(formation_id, point_id)
    local resource_point = resource_point_data[point_id]
    if not resource_point then
        return false
    end
    
    -- 检查采集点是否可用
    if resource_point.occupied_id and resource_point.occupied_id.id ~= formation_id then
        -- 通知原始采集者采集被打断
        local rewards  = CMD.stop_collection(point_id)
        skynet.send( event_service, "lua", "collection_interrupted", resource_point.occupied_id )
    end
    
    -- 设置采集状态
    resource_point.occupied_id = formation_id
    resource_point.start_time = skynet.time()

    -- 采集开始成功
    skynet.send( event_service, "lua", "collection_started", formation_id, point_id )

    -- 世界服务器更新显示属性
    skynet.call( world_service, "lua", "update_entity", CMD.get_display_attributes(point_id) )
    
    return true
end

-- 停止采集
function CMD.stop_collection(resource_point_id)
    local resource_point = resource_point_data[resource_point_id]
    if not resource_point then
        return { success = false, error = "Resource point not found" }
    end
    
    -- 计算收获
    local duration = skynet.time() - resource_point.start_time
    local rewards = calculate_rewards(resource_point, duration)

    skynet.send( event_service, "lua", "collection_stopped", resource_point.occupied_id, {id = resource_point.occupied_id, reward = rewards} )
    -- 清除占用状态
    resource_point.occupied_id = nil
    resource_point.start_time = nil

    -- 世界服务器更新显示属性
    skynet.call( world_service, "lua", "update_entity", CMD.get_display_attributes(resource_point_id) )


    return rewards
end






-- 更新采集点状态
function CMD.update_collections()
    local current_time = skynet.time()
    local updated_count = 0
    
    for collection_id, collection_point in pairs(resource_point_data) do
        if collection_point.occupied_by then
            -- 检查采集是否超时
            local max_duration = collection_point.max_duration or 3600 -- 默认1小时
            if current_time - collection_point.start_time > max_duration then
                -- 自动停止采集
                collection_point.occupied_by = nil
                collection_point.start_time = nil
                updated_count = updated_count + 1
            end
        end
    end
    
    if updated_count > 0 then
        skynet.error("Auto-stopped", updated_count, "collection points due to timeout")
    end
    return true
end





skynet.start(function()
    mysql_service = datacenter.get("mysql_service")
    world_service = datacenter.get("world_service")
    id_service = datacenter.get("id_service")
    event_service = datacenter.get("event_service")
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = CMD[command]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            skynet.error("Unknown command:", command)
            skynet.ret(skynet.pack(nil, "Unknown command"))
        end
    end)
end)

