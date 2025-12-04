--物品配置
local item_config = {
    [1] = { id = 1, name = "木材", type = "resource", resource = {wood = 100, stone = 0, iron = 0, food = 0} },
    [2] = { id = 2, name = "石材", type = "resource", resource = {wood = 0, stone = 100, iron = 0, food = 0} },
    [3] = { id = 3, name = "铁矿", type = "resource", resource = {wood = 0, stone = 0, iron = 100, food = 0} },
    [4] = { id = 4, name = "粮食", type = "resource", resource = {wood = 0, stone = 0, iron = 0, food = 100} },
    [5] = { id = 5, name = "建筑加速", type = "time", limit_type = "building", duration = 3600 },
    [6] = { id = 6, name = "训练加速", type = "time", limit_type = "training", duration = 1800 },
    [7] = { id = 7, name = "科技加速", type = "time", limit_type = "research", duration = 7200 },
    [8] = { id = 8, name = "训练加速", type = "time", limit_type = "training", duration = 7200 },
    [9] = { id = 9, name = "行军加速", type = "time", limit_type = "march", duration = 900 },
    [10] = { id = 10, name = "通用加速", type = "time", duration = 1200 },
    [11] = { id = 11, name = "资源宝箱", type = "resource", resource = {wood = 500, stone = 500, iron = 500, food = 500} },
    [12] = { id = 12, name = "高级资源宝箱", type = "resource", resource = {wood = 2000, stone = 2000, iron = 2000, food = 2000} },
    [13] = { id = 13, name = "超级资源宝箱", type = "resource", resource = {wood = 10000, stone = 10000, iron = 10000, food = 10000} },
    --英雄类物品
    [14] = { id = 14, name = "英雄招募令", type = "hero", hero_id = 101, hero_name = "凯亚" },
    [15] = { id = 15, name = "英雄招募令", type = "hero", hero_id = 102, hero_name = "凯门" },
    [16] = { id = 16, name = "英雄招募令", type = "hero", hero_id = 103, hero_name = "塞尔" },
    [17] = { id = 17, name = "英雄招募令", type = "hero", hero_id = 104, hero_name = "亚瑟" },
    --经验类
    [18] = { id = 18, name = "经验书", type = "experience", experience = 1000 },
    [19] = { id = 19, name = "高级经验书", type = "experience", experience = 5000 },
    [20] = { id = 20, name = "超级经验书", type = "experience", experience = 20000 },
    

}

return item_config