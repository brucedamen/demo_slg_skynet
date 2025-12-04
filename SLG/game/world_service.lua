--世界服务器，负责管理所有公用数据，如地图节点，编队等

local skynet = require "skynet"
local datacenter = require "datacenter"

local mapcheck = require "mapblock"--地图块占用检测模块
local block = require "block" --地图区域模块

local config = require "config_map"
local math_random = math.random


local subscribe

--存储city, monster, resource, alliance等实体
local entity_block_id = {} -- entity_id → block_id_list
local entitys = {} --  [block_id][entity_id] → entitydata
--编队列表
local formation_list = {}



--编队结构示例
--[[
formation = {
    id = 1,
    status = "move", -- move battle return 
    
    alliance_id = 12345, --所属联盟ID
    source_pos = { x = 100, y = 200 }, -- 出发位置
    dest_pos = { x = 300, y = 400 }, -- 目标位置
    current_pos = { x = 150, y = 250 }, -- 当前所在位置
    duration = 600, -- 预计到达时间(秒)
    model_id = 01, -- 编队模型ID 展示外观


    -- 所属信息
    owner = service, --所属玩家服务
    user_id = 123456, --所属玩家ID
}
--]]

--entity 结构示例
--[[
entity = {
    id = 1,
    type = "city", -- city, monster, resource, alliance
    position = { x = 100, y = 200 },
    level = 5, -- 等级
    name = "MyCity", -- 城市名称

    refresh_time = 0, -- 刷新时间(怪物和资源专用)
    resource_type = "gold", -- 资源类型(resource专用)
    alliance_id = 67890, -- 联盟ID 无联盟和怪物等均为0
    defense_ids = { {serveice,1}, }, -- 防守编队ID列表(怪物和资源无此字段) 被占用时则为占用编队 服务和ID

    -- 所属信息
    service = service, --所属服务
}
--]]



-- 寻找空位（从随机位置开始）
local function find_empty_position(node_type)
    local size = config.entity_size[node_type]
    if not size then return nil, "Unknown node type" end
    local w, h = size.w, size.h

    local start_x = math_random(1, config.width)
    local start_y = math_random(1, config.height)

    for dx = 0, config.width - 1 do
        for dy = 0, config.height - 1 do
            local x = (start_x + dx - 1) % config.width + 1
            local y = (start_y + dy - 1) % config.height + 1
            if x + w - 1 <= config.width and y + h - 1 <= config.height then
                -- 检查是否有重叠
                if not mapcheck.check(x, y, w, h) then
                    return x, y
                end
            end
        end
    end
end

-- 在附近寻找空位
local function find_nearby_empty_position(x, y, node_type, max_range)
    local size = config.entity_size[node_type]
    if not size then return nil, "Unknown node type" end
    local w, h = size.w, size.h

    for range = 0, max_range do
        for dx = -range, range do
            for dy = -range, range do
                local nx, ny = x + dx, y + dy
                if nx >= 1 and ny >= 1 and nx + w - 1 <= config.width and ny + h - 1 <= config.height then
                    -- 检查是否有重叠
                    if not mapcheck.check(nx, ny, w, h) then
                        return nx, ny
                    end
                end
            end
        end
    end

    return nil, "No empty position found nearby"
end



local CMD = {}

function CMD.start(config)
    mapcheck.init(config.width, config.height, config.block_size)
    block.init(config.width, config.height, config.block_size)
    --初始化地图数据等
    print("World server initialized")
    --载入地图固定资源，世界城争夺点等
end

-- 查询节点信息
function CMD.query_entity(entity_id)
    local block_id = entity_block_id[entity_id]
    if not block_id then
        return nil, "Entity not found"
    end
    local entity = entitys[block_id][entity_id]
    if entity then
        return entity
    end
    return nil, "Entity not found"
end

-- 注册节点（建筑、资源、阵型、联盟驻点等）
function CMD.register_entity(data)
    if not data.type then
        return false, "Entity type required"
    end
   
    --找到个合适的位置放置节点（如果没有指定位置）指定位置一般为重启载入时使用
    if not data.position or not data.position.x or not data.position.y then
        local x, y = find_empty_position(data.type)
        if x and y then
            data.position = { x = x, y = y }
        end
        if not data.position or not data.position.x or not data.position.y then
            return false, "No available position on map"
        end
    end

    --放置节点到地图上
    local block_id = block:get_block_id(data.position.x, data.position.y)

    --保存节点信息
    entitys[block_id] = entitys[block_id] or {}
    entitys[block_id][data.id] = data
    entity_block_id[data.id] = block_id

    local entity = entitys[block_id][data.id]

    --通知区域关注者节点信息变更
    local update_data = {
        event = "add_entity", --用于区分普通查询和新增节点
        entity = entity,
    }


    --广播通知
    skynet.call( subscribe, "lua", "broadcast_block", block_id, "entity_update", entity)
    
    --打印节点信息
    for k, v in pairs(data) do
        print("Entity data:", k, v) 
    end

    return data.position.x, data.position.y
end



--移动节点
function CMD.move_entity(entity_id, new_x, new_y)
    local old_block_id = entity_block_id[entity_id]
    if not old_block_id then
        return false, "Entity not found"
    end

    local entity = entitys[old_block_id][entity_id]
    if not entity then
        return false, "Entity not found"
    end

    --从地图上移动节点
    local new_block_id = block:get_block_id(new_x, new_y)
    if not new_block_id then
        return false, "Failed to move entity: Invalid block ID"
    end

    -- 移除地图节点
    mapcheck.clear(entity.position.x, entity.position.y, config.entity_size[entity.type].w, config.entity_size[entity.type].h)
    -- 重新标记地图节点
    mapcheck.set(new_x, new_y, config.entity_size[entity.type].w, config.entity_size[entity.type].h)


    --移动节点后更新entity_block_id映射关系
    entity_block_id[entity_id] = new_block_id
    entitys[old_block_id][entity_id] = nil
    entitys[new_block_id] = entitys[new_block_id] or {}
    entitys[new_block_id][entity_id] = entity

    entity.block_id = new_block_id

    local move_data = {
        id = entity_id,
        source_pos = {
            x = entity.position.x,
            y = entity.position.y
        },
        dest_pos = {
            x = new_x,
            y = new_y
        },
    }

    --更新节点位置
    entity.position.x = new_x
    entity.position.y = new_y

    --通知节点信息变更
    skynet.call( subscribe, "lua", "broadcast_block", old_block_id, "entity_move", {event = "out", move_data = move_data})
    skynet.call( subscribe, "lua", "broadcast_block", new_block_id, "entity_move", {event = "in", move_data = move_data})


    return true
end

-- 移动节点到附近位置
function CMD.move_entity_nearby(entity_id, x, y, max_range)
    local block_id = assert(entity_block_id[entity_id])
    local entity = assert(entitys[block_id][entity_id])

    local new_x, new_y = find_nearby_empty_position(x, y, entity.type, max_range)
    if not new_x or not new_y then
        return false, "No available nearby position"
    end

    return CMD.move_entity(entity_id, new_x, new_y)
end


-- 更新节点信息
function CMD.update_entity(entity_id, updates)
    local block_id = assert(entity_block_id[entity_id])
    local entity = assert(entitys[block_id][entity_id])

    for key, value in pairs(updates) do
        entity[key] = value
    end

    --通知节点信息变更
    skynet.call( subscribe, "lua", "broadcast_block", entity.block_id, "entity_update", {event = "update", entity = { entity }})

    return true
end



--注销节点 event用于区分哪个类型的移除，比如到期消失，战斗摧毁等
function CMD:unregister_node(entity_id, event)
    local block_id = entity_block_id[entity_id]
    if not block_id then
        return false, "Entity not found"
    end
    local entity = entitys[block_id][entity_id]
    if not entity then
        return false, "Entity not found"
    end
    
    -- 从地图上移除节点
    mapcheck.clear(entity.position.x, entity.position.y, config.entity_size[entity.type].w, config.entity_size[entity.type].h)

    --移除节点信息
    entitys[block_id][entity_id] = nil
    entity_block_id[entity_id] = nil


    --通知关注者节点被移除
    skynet.call( subscribe, "lua", "broadcast_block", block_id, "entity_remove", { id = entity_id, event = event})

    return true
end





--获取区块节点信息
function CMD.get_blocks_info( block_id_list )
    local entities = {}
    for _, block_id in ipairs(block_id_list) do
        entitys[block_id] = entitys[block_id] or {}
        local nodes = entitys[block_id]
        for node_id, entity in pairs(nodes)  do
            table.insert(entities, entity)
        end
    end
    return entities
end





-- 服务入口
skynet.start(function()
    subscribe = datacenter.get("subscribe_service")

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

