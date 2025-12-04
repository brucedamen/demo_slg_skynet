local skynet = require "skynet"
local handler = require "handler"

local config = require "config_building"



local REQUEST = {}
local CMD = {}
local user
handler = handler.new (REQUEST, nil, CMD)

handler:init (function (u)
	user = u
end)

-- 载入建筑数据
function CMD.load_buildings(building_list)
    user.buildings = building_list or {}
    return true
end

--建筑完成升级回调
function CMD.building_upgrade_complete(task)
    local building = user[task.user_id].buildings[task.target_id]
    building.level = building.level + 1
    building.status = "idle"

    user.send_package(task.user_id, user.request("upgrade_complete", { building = building }))

    --完成任务
    user.CMD.task_complete(task.user_id, task.id)
    -- 事件触发
    user.CMD.event_check("building", { type = building.type, level = building.level })
end
--建筑取消升级回调
function CMD.building_cancel_upgrade(task)
    local building = user[task.user_id].buildings[task.target_id]
    building.status = "idle"

    --返还部分资源 给玩家补偿
    local refund = task.cost
    for res, amount in pairs(refund) do
        refund[res] = math.floor(amount / 2)
    end
    user.CMD.add_resources(task.user_id, refund)

    --关闭任务
    user.CMD.task_close(task.user_id, task.id)
end
--建筑完成生产回调
function CMD.building_produce_complete(task)
    local building = user[task.user_id].buildings[task.target_id]
    building.status = "idle"


    local soldier = building.producing_soldier
    building.producing_soldier = nil

    -- 通知客户端生产完成
    user.send_package(task.user_id, user.request("produce_complete", { building_id = building.id, soldier = soldier }))
    --完成任务
    user.CMD.task_complete(task.user_id, task.id)

    -- 事件触发 任务系统进度控制
    user.CMD.event_check("produce", {user_id = task.user_id, type = soldier.type, level = soldier.level, count = soldier.count })
end
--建筑取消生产回调
function CMD.building_cancel_produce(task)
    --建筑状态恢复空闲
    local building = user[task.user_id].buildings[task.target_id]
    building.status = "idle"

    --减半返还部分资源 给玩家补偿
    local refund = task.cost
    for res, amount in pairs(refund) do
        refund[res] = math.floor(amount / 2)
    end
    user.CMD.add_resources(task.user_id, refund)

    --关闭任务
    user.CMD.task_close(task.user_id, task.id)
end



--获取建筑列表请求处理
function REQUEST.building_query(args)
    print("building_query request received")
    local buildings = {}
    for id, building in pairs(user.buildings) do
        table.insert(buildings, building)
    end
    return { success = true, buildings = buildings }
end

--建筑相关请求处理
-- 创建建筑
function REQUEST.building_create(args)
    if not args.type or not args.pos_x or not args.pos_y then
        return { success = false }
    end
    --校验类型
    if not building_type_map[args.type] then
        return { success = false }
    end

    -- 在这里可以添加更多的校验逻辑，比如位置（如果是自由排布建筑的话）


    -- 如果有建筑类型数量限制，可以在这里进行校验


    --分配建筑ID
    local new_id = skynet.call(user.id_service, "lua", "next_id")

    -- 校验建造所需资源
    local cost = config.building_cost[args.type]
    -- 扣除资源
    if not user.CMD.deduct_resources(cost) then
        return { success = false }
    end
    --创建建筑
    local new_building = {
        id = new_id,
        level = 1,
        type = args.type,
        pos_x = args.pos_x or 0,
        pos_y = args.pos_y or 0,
        status = "idle",
    }
    --依据建筑类型设置建筑产出属性
    new_building.produce_type = produce_type_map[args.type]

    user.buildings[new_id] = new_building

    -- 事件触发,完成任务系统进度控制
    user.CMD.event_check("building", { type = new_building.type, level = new_building.level })

    return { success = true, cost = cost, building = new_building }
end

--建筑升级请求处理
function REQUEST.building_upgrade(user_id, args)
    --校验建筑是否存在
    local building = user[user_id].buildings[args.id]
    if not building then
        return { success = false }
    end
    --校验建筑是否已达最高等级
    if building.level >= 10 then
        return { success = false }
    end

    --校验建筑是否空闲
    if building.status ~= "idle" then
        return { success = false }
    end

    --校验建筑升级所需资源
    local cost = config.upgrade_cost[building.type][building.level]

    --扣除资源
    if not user.CMD.deduct_resources(user_id, cost) then
        return { success = false }
    end

    --设置建筑状态为升级中 仅仅作为标记，防止重复升级
    building.status = "upgrading"

    --开始升级建筑
    local task = {
        type = "building",
        status = "upgrading",
        target_id = building.id,
        duration = config.building_upgrade_time[building.type][building.level],
        start_time = os.time(),
        cost = cost,
        on_task_complete = user.CMD.building_upgrade_complete,
        on_task_cancel = user.CMD.building_cancel_upgrade,
    }
    --注册升级任务
    user.CMD.task_create( building.duration, task)


    return { success = true, cost = cost, building = user.buildings[args.id] }
end




--生产类建筑请求处理
function REQUEST.building_produce(args)
    --校验生产类型
    if not args.soldier or not args.soldier.type or not args.soldier.level or not args.soldier.count or not args.id then
        return { success = false }
    end

    --校验建筑是否存在
    local building = user.buildings[args.id]
    if not building then
        return { success = false }
    end

    --校验建筑是否空闲
    if building.status ~= "idle" then
        return { success = false }
    end

    --校验是否为合法兵种(比如非法让步兵营生产弓兵)
    if( building.produce_type ~= args.soldier.type) then
        return { success = false }
    end
    --校验等级
    if building.level < args.soldier.level then
        return { success = false }
    end

    --校验生产所需资源
    local cost = config.soldier_production_cost[args.soldier.type][args.soldier.level]
    cost.food = cost.food * args.soldier.count
    cost.wood = cost.wood * args.soldier.count
    cost.stone = cost.stone * args.soldier.count
    cost.iron = cost.iron * args.soldier.count

    --扣除资源
    if not user.CMD.deduct_resources(cost) then
        return { success = false }
    end

    local task = {
        type = "building",
        status = "producing",
        target_id = building.id,
        soldier = args.soldier,
        duration = config.building_upgrade_time[building.type][building.level],
        start_time = os.time(),
        cost = cost,
        on_task_complete = user.CMD.building_upgrade_complete,
        on_task_cancel = user.CMD.building_cancel_produce,
    }

    --注册生产完成任务
    user.CMD.task_create(task)
    --设置建筑生产信息
    building.status = "producing"

    return { success = true, cost = cost }
end




return handler