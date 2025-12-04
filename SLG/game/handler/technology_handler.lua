local skynet = require "skynet"
local handler = require "handler"
local config = require "config_technologies"


local REQUEST = {}
local CMD = {}
local user
handler = handler.new (REQUEST, nil, CMD)

handler:init (function (u)
	user = u
end)


--科技完成回调
local function technology_task_complete(task)
    local id = task.target_id
    local level= (user[task.user_id].technologies[id] or 0) + 1
    
    --科技效果应用
    for effect_name, effect_value in pairs(config[id][level].effect) do
        user.effect[effect_name] = (user.effect[effect_name] or 0) + effect_value
    end

    --加入科技表中
    user[task.user_id].technologies[id] = level

    --完成任务
    user.CMD.task_complete(task.user_id, task.id)

    --触发科技相关任务检查
    user.CMD.event_check("technology",{user_id = task.user_id, type = id, level = level, count  = 1} )
end

--科技取消回调
local function technology_task_cancel(task)
    local id = task.target_id
    local level= (user.technologies[id] or 0)+1  --目标等级

    --返还资源，减半返还
    local cost = config[id][level].cost
    for res, amount in pairs(cost) do
        cost[res] = math.floor(amount / 2)
    end
    user.CMD.add_resources(task.user_id, cost)
    --关闭任务
    user.CMD.task_close(task.user_id, task.id)
end


-- 载入科技数据
function CMD.load_technologies(technology_list)
    user.technologies = technology_list or {}
    return true
end


--查询科技信息
function REQUEST.technology_query(args)
    return { success = true, technologies = user[args.user_id].technologies }
end
--研发科技
function REQUEST.technology_research(user_id, args)
    --参数检查
    if not args.id then
        return { success = false, error = "invalid_arguments" }
    end
    --查询科技ID是否存在
    local technology = config.technologies[args.id]
    if not technology then
        return { success = false, error = "technology_not_found" }
    end

    --检查是否已有研发任务(目前设计只能一个研发任务，如果需求，可用以扩展为多个任务同时进行
    local tasks = user.CMD.task_query("technology")
    if #tasks > 0 then
        return { success = false, error = "technology_task_in_progress" }
    end
    
    local tech_config = config[args.id][args.level]
    if tech_config == nil then
        return { success = false, error = "technology_level_not_found" }
    end

    --检查科技建筑等级-----------------------
    --查询玩家科技建筑
    local technology_building = user.buildings[args.building_id]
    if not technology_building then
        return { success = false, error = "technology_building_not_found" }
    end
    if technology_building.level < tech_config.building_level then
        return { success = false, error = "invalid_level" }
    end


    --检查前置科技
    for _, pre in ipairs(tech_config.prerequisites) do--遍历检查所有前置科技
        local level = user.technologies[pre.id]--查询玩家当前科技
        if not level or level < pre.level then--检查玩家科技是否满足前置科技
            return { success = false, error = "prerequisite_technology_not_met" }
        end
    end

    --检查资源
    local resources = tech_config.cost
    for res, amount in pairs(resources) do
        if user.resources[res] < amount then
            return { success = false, error = "insufficient_resources" }
        end
    end

    --创建研发任务
    local task = {
        type = "technology",
        status = "researching",
        start_time = skynet.now(),
        duration = config[args.id][args.level].time,
        target_id = args.id,
        on_task_complete = technology_task_complete,
        on_task_cancel = technology_task_cancel,
    }


    user.CMD.task_create(task)


    return { success = true }
end

return handler