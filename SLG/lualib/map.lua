local mapcheck = require "mapblock"--地图块占用检测模块
local block = require "block" --地图区域模块
local math_random = math.random

local Map = {}
Map.__index = Map

local entity_size = {
    city = { w = 2, h = 2 },
    monster = { w = 1, h = 1 },
    resource = { w = 1, h = 1 },
    alliance = { w = 3, h = 3 },
}

--- 创建地图实例
function Map.new(width, height, region_size)
    local self = setmetatable({}, Map)

    block.init( width, height, region_size )

    -- 初始化地图占用
    mapcheck.init(width, height)

    return self
end




-- 增加节点
function Map:add_node(node_id, x, y, node_type)
    local size = entity_size[node_type]
    if not size then return false, "Unknown node type" end
    local w, h = size.w, size.h

    -- 检查重叠
    if mapcheck.check(x, y, w, h) then
        return false, "Overlapping with existing nodes"
    end
    -- 标记地图块占用
    mapcheck.set(x, y, w, h)

    return self:get_block_id(x, y)
end
--移动节点
function Map:move_node(old_x, old_y, new_x, new_y, node_type)
    local size = entity_size[node_type]
    if not size then return false, "Unknown node type" end
    local w, h = size.w, size.h

    -- 检查新位置重叠
    if mapcheck.check(new_x, new_y, w, h) then
        return false, "Overlapping with existing nodes"
    end

    local old_block_id = self:get_block_id(old_x, old_y)
    local new_block_id = self:get_block_id(new_x, new_y)

    --释放旧位置占用
    mapcheck.clear(old_x, old_y, w, h)
    -- 标记新位置占用
    mapcheck.set(new_x, new_y, w, h)

    return old_block_id, new_block_id
end
-- 移除节点
function Map:remove_node(node_id, x, y, node_type)
    local size = entity_size[node_type]
    if not size then return false, "Unknown node type" end
    local w, h = size.w, size.h

    -- 释放地图块占用
    mapcheck.clear(x, y, w, h)

    return self:get_block_id(x, y)
end



-- 寻找空位（从随机位置开始）
function Map:find_empty_position(node_type)
    local size = entity_size[node_type]
    if not size then return nil, "Unknown node type" end
    local w, h = size.w, size.h

    local start_x = math_random(1, self.width)
    local start_y = math_random(1, self.height)

    for dx = 0, self.width - 1 do
        for dy = 0, self.height - 1 do
            local x = (start_x + dx - 1) % self.width + 1
            local y = (start_y + dy - 1) % self.height + 1
            if x + w - 1 <= self.width and y + h - 1 <= self.height then
                -- 检查是否有重叠
                if not mapcheck.check(x, y, w, h) then
                    return x, y
                end
            end
        end
    end

    return nil, "No empty position found"
end

-- 在附近寻找空位
function Map:find_nearby_empty_position(x, y, node_type, max_range)
    local size = entity_size[node_type]
    if not size then return nil, "Unknown node type" end
    local w, h = size.w, size.h

    for range = 0, max_range do
        for dx = -range, range do
            for dy = -range, range do
                local nx, ny = x + dx, y + dy
                if nx >= 1 and ny >= 1 and nx + w - 1 <= self.width and ny + h - 1 <= self.height then
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

return Map
