local skynet = require "skynet"
local handler = require "handler"
local datacenter = require "skynet.datacenter"



local REQUEST = {}
local CMD = {}
local user
handler = handler.new (REQUEST, nil, CMD)

local world_service = datacenter.get("world_service")
local id_service = datacenter.get("id_service")
local movement_service = datacenter.get("movement_service")
local battle_service = datacenter.get("battle_service")
local collection_service = datacenter.get("collection_service")

handler:init (function (u)
	user = u

end)




-- 获取显示属性（用于世界显示）
local function get_display_attributes(formation_id)
    local display_unit = {}

    local formation = user.formations[formation_id]
    if not formation then
        return nil
    end
    -- 基础属性
    display_unit.service = skynet.self()
    display_unit.id = formation.id

    display_unit.type = "formation"
    display_unit.position = user.position
    display_unit.status = formation.status
    display_unit.level = user.level
    

    return display_unit
end

-- 获取编队属性（用于战斗等）
local function get_battle_units(formation_id)
    local battle_unit = {}

    local formation = user.formations[formation_id]
    if not formation then
        return nil
    end


    -- 士兵
    battle_unit.soldiers = {}
    for _, soldier in pairs(formation.soldiers) do
        table.insert(battle_unit.soldiers, soldier)
    end
    battle_unit.heroes = {}
    for _, hero in pairs(formation.heroes) do
        table.insert(battle_unit.heroes, hero)
    end

    battle_unit.effects = user.effects
    battle_unit.service = skynet.self()
    battle_unit.id = formation.id

    return battle_unit
end


-- 载入部队编组数据
function CMD.load_formations(formation_list)
    user.formations = formation_list or {}
    return true
end


--编队攻击
function REQUEST.formation_attack(args)
    --检查参数
    if not args.formation_id or not args.target_id then
        return { success = false, error = "invalid_formation_id" }
    end
    local formation = user.formations[args.formation_id]
    if not formation then
        return { success = false, error = "formation_not_found" }
    end

    -- 向世界服务器注册编队信息，进行显示
    skynet.call( world_service, "lua", "register_formation", get_display_attributes(args.formation_id))


    --任务
    local task = {
        target_id = args.target_id,
        mission = "battle",
    }
    formation.task = task


    -- 使用movement系统发起移动到目标位置
    skynet.call( movement_service, "lua", "start", args.formation_id, skynet.self(), user.position, args.target_pos, 100)


    --返回成功
    return {success = true }
end

--编队采集
function REQUEST.formation_collect(args)
    --检查参数
    if not args.formation_id then
        return { success = false, error = "invalid_formation_id" }
    end

    -- 检查目标位置是否合法
    if not args.position or not args.position.x or not args.position.y then
        return { success = false, error = "invalid_position" }
    end

    -- 检查编队是否存在
    local formation = user.formations[args.formation_id]
    if not formation then
        return { success = false, error = "formation_not_found" }
    end

    --检查编队状态 是否可执行任务
    if formation.status ~= "idle" then
        return { success = false, error = "formation_busy" }
    end

    -- 向世界服务器注册编队信息，进行显示
    skynet.call( world_service, "lua", "register_formation", get_display_attributes(args.formation_id))

    --任务
    local task = {
        target_id = args.target_id,
        mission = "collect",
    }
    formation.task = task

    -- 使用movement系统发起移动到目标位置
    skynet.call( movement_service, "lua", "start", args.formation_id, skynet.self(), user.position, args.position, 100)


    return {success = true }
end


----编队创建
function REQUEST.formation_create(args)
    --检查参数
    --简化起见 目前只允许携带一种兵种 且单一等级
    if not args.soldier.type or not args.soldier.level or not args.soldier.count then
        return { success = false, error = "invalid_arguments" }
    end
    if not args.hero_id then
        return { success = false, error = "invalid_hero_id" }
    end

    --检查兵种和数量是否足够
    local total_available = 0
    for k, v in pairs(user.soldiers) do
        if v.type == args.soldier.type and v.level == args.soldier.level then
            total_available = total_available + v.count
        end
    end
    if total_available < args.soldier.count then
        return { success = false, error = "insufficient_soldiers" }
    end

    --向英雄模块锁定英雄
    if not user.CMD.hero_lock(args.hero_id) then
        return { success = false, error = "hero_lock_failed" }
    end

    --从用户的士兵中扣除相应数量的士兵
    for k, v in pairs(user.soldiers) do
        if v.type == args.soldier.type and v.level == args.soldier.level then
            v.count = v.count - args.soldier.count
        end
    end

    --执行创建编队逻辑
    -- 向id服务获取编队ID
    local formation_id = skynet.call( id_service, "lua", "next_id" )

    local formation = {
        id = formation_id,
        hero_id = args.hero_id,
        soldiers = args.soldier,
        status = "idle",
    }
    user.formations[formation_id] = formation




    return { success = true, formation = formation }
end

--编队解散
function REQUEST.formation_dissolve(args)
    --检查参数
    if not args.formation_id then
        return { success = false, error = "invalid_formation_id" }
    end
    local formation = user.formations[args.formation_id]
    if not formation then
        return { success = false, error = "formation_not_found" }
    end

    --检查编队状态 是否可解散
    if formation.status ~= "idle" then
        return { success = false, error = "formation_busy" }
    end

    --释放英雄锁定
    user.CMD.hero_unlock(formation.hero_id)

    --返还士兵
    local has_returned = false
    for k, v in pairs(user.soldiers) do
        if v.type == formation.soldiers.type and v.level == formation.soldiers.level then
            v.count = v.count + formation.soldiers.count
            has_returned = true
        end
    end
    --如果没有相应的士兵记录 则创建一条新的记录
    if not has_returned then
        user.soldiers[#user.soldiers + 1] = {
            type = formation.soldiers.type,
            level = formation.soldiers.level,
            count = formation.soldiers.count,
        }
    end

    --删除编队
    user.formations[args.formation_id] = nil

    --通知世界服务器删除编队显示
    skynet.call( world_service, "lua", "unregister_formation", args.formation_id)

    return { success = true }
end

--编队查询
function REQUEST.formation_query()
    local formations = {}
    for id, formation in pairs(user.formations) do
        table.insert(formations, formation)
    end
    return { success = true, formations = formations }
end




-- 中断任务
function REQUEST.interrupt_task(id)
    local formation = user.formations[id]
    if not formation then
        return
    end
    if formation.status == "moving" then
        -- 停止移动
        local pos = skynet.call( movement_service, "lua", "stop", formation.id)
        -- 启动返回移动
        skynet.call( movement_service, "lua", "start", formation.id, skynet.self(), pos, user.position, 100)

    elseif formation.status == "collecting" then
        -- 停止采集服务
        skynet.call( collection_service, "lua", "stop_collection", formation.id)
    elseif formation.status == "defending" then
        -- 停止防御任务( 需要等待战斗服务确认，否则可能这里返回，但是战斗服务正好触发战斗)
        local ok = skynet.call( battle_service, "lua", "stop_defense", formation.id)
        if not ok then
            return { success = false, error = "defense_task_not_found" }
        end
    end 
    return { success = true }
end

-- 移动开始
function CMD.movement_start( id, source_pos, target_pos)
    local formation = user.formations[id]
    if not formation then
        return
    end
    if formation.status ~= "idle" then -- 非空闲状态的移动都是返回
        formation.status = "returning"
    else
        formation.status = "moving"  -- 空闲状态的移动都是前往
    end
    
    notify_formation_status( formation.id )
end


-- 移动更新
function CMD.movement_update( id, current_pos)
    local formation = user.formations[id]
    if not formation then
        return
    end
    -- 更新编队位置
    formation.position = current_pos
    -- 更新世界显示的编队位置
    skynet.call( world_service, "lua", "update_formation", formation.id, {position = current_pos} )
end

-- 移动完成
function CMD.movement_complete( id, target_pos)
    local formation = user.formations[id]
    if not formation then
        return
    end
    if formation.status == "moving" then
        -- 查询目标
        local target_info = skynet.call( world_service, "lua", "get_entity", formation.task.target_id )

        --核对目标位置(目标移动了则任务失败 返回)
        if not target_info or not target_info.position or target_info.position.x ~= formation.position.x or target_info.position.y ~= formation.position.y then
            skynet.call( movement_service, "lua", "start", formation.id, skynet.self(), formation.position, user.position, 100)
            return
        end

        -- 到达目标位置 根据任务类型启动相应任务
        if formation.task.mission == "battle" then
            -- 启动战斗任务
            skynet.call( battle_service, "lua", "formation_register_attack", {source_id = formation.id, target_id = target_info.id} )

        elseif formation.task.mission == "collect" then
            -- 启动采集任务
            skynet.call( collection_service, "lua", "start_collection", skynet.self(), formation.id, target_info.id )
        end
    elseif formation.status == "returning" then
        -- 编队返回完成
        formation.position = target_pos
        formation.status = "idle"
        notify_formation_status( formation.id )
    end
end

-- 战斗开始
function CMD.battle_start(event_data)
    local formation = user.formations[event_data.source_id]
    if not formation then
        formation = user.formations[event_data.target_id]
    end
    if not formation then
        return
    end
    -- 更新编队状态
    formation.status = "in_battle"
    notify_formation_status( formation.id )
    -- 向战斗服务注册战斗单位
    skynet.send( battle_service, "lua", "battle_unit_register", formation.id, CMD.get_battle_units(formation.id) )

end

-- 战斗完成
function CMD.battle_complete(event_data)
    local formation = user.formations[event_data.formation_id]
    if not formation then
        return
    end
    -- 启动返回移动
    skynet.call( movement_service, "lua", "start", formation.id, skynet.self(), formation.position, user.position, 100)

end

-- 战役结束
function CMD.campaign_complete(event_data)
    local formation = user.formations[event_data.formation_id]
    if not formation then
        return
    end
    -- 更新编队状态
    formation.status = "defense"
    notify_formation_status( formation.id )
    
    -- 处理战役奖励等逻辑
    -- 这里可以添加发放奖励的逻辑
end
-- 采集开始
function CMD.collection_start(event_data)
    local formation = user.formations[event_data.formation_id]
    if not formation then
        return
    end
    -- 更新编队状态
    formation.status = "collecting"
    notify_formation_status( formation.id )
end
-- 采集完成
function CMD.collection_complete(event_data)
    local formation = user.formations[event_data.formation_id]
    if not formation then
        return
    end
    -- 启动返回移动
    skynet.call( movement_service, "lua", "start", formation.id, skynet.self(), formation.position, user.position, 100)

end
return handler