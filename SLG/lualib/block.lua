local block = {}
block.__index = block

--初始化
function block:init( width, height, region_size )
    self.width = width
    self.height = height
    self.region_size = region_size
end

-- 获取区域ID
function block:get_block_id(x, y)
    local rx = math.floor((x - 1) / self.region_size) + 1
    local ry = math.floor((y - 1) / self.region_size) + 1
    return (rx - 1) * (self.height / self.region_size) + ry
end

--获取附近区域ID列表（9宫格区域）
function block:get_block_id_list(x, y)
    local blocks = {}
    local rx = math.floor((x - 1) / self.region_size) + 1
    local ry = math.floor((y - 1) / self.region_size) + 1

    for dx = -1, 1 do
        for dy = -1, 1 do
            local nrx = rx + dx
            local nry = ry + dy
            if nrx >= 1 and nry >= 1 and nrx <= (self.width / self.region_size) and nry <= (self.height / self.region_size) then
                local region_id = (nrx - 1) * (self.height / self.region_size) + nry
                table.insert(blocks, region_id)
            end
        end
    end

    return blocks
end


return block