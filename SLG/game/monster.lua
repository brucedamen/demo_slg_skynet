--世界服务器，负责管理所有城市的状态和数据


local skynet = require "skynet"
local datacenter = require "datacenter"


local event_service = nil
local world_service = nil

--怪物实体列表
local monster_data = {}

local battle_service = nil
local id_service = nil


-- 获取战斗单位信息
local function get_battle_unit(monster)
    local battle_unit = {
        id = monster.id,
        type = monster.type,
        level = monster.level,
        name = monster.name,
        hp = monster.hp,
        attack = monster.attack,
        defense = monster.defense,
    }
    return battle_unit
end

-- 获取显示属性（用于世界显示）
local function get_display_attributes(monster)
    local display_attributes = {
        id = monster.id,
        type = monster.type,
        level = monster.level,
        name = monster.name,
    }
    return display_attributes
end


--创建怪物实体
local function create_monster(type, name, level)

    local id = skynet.call( id_service, "lua", "next_id")

    -- 事实上依据配置文件创建怪物属性
    local monster = {
        id = id,
        level = level,
        type = type,
        name = name or (type.. tostring(id)),
        hp = 100,  -- 默认生命值
        attack = 10,  -- 默认攻击力
        defense = 5,  -- 默认防御力
        refresh_time = os.time() + 6000, -- 默认6000秒后刷新
    }

    -- 订阅战斗事件
    local event_set = {
        "battle_start",
        "battle_complete",
    }
    skynet.call( event_service, "lua", "subscribe_event", monster.id, event_set )

    -- 注册显示属性到世界服务器
    skynet.call( world_service, "lua", "register_entity", get_display_attributes(monster) )

    return monster
end



local CMD = {}

function CMD.init(server_id)
    --数据库服务读取怪物数据
    local mysql_service = datacenter.get("mysql_service")

    local monsters = skynet.call( mysql_service, "lua", "load_monsters")
    monster_data = monsters

    for _, monster in ipairs(monster_data) do

        local display_data = get_display_attributes(monster)

        --向世界服务器注册怪物显示数据
        skynet.call( world_service, "lua", "register_entity", display_data )
    end
end

-- 保存怪物信息到数据库
function CMD.save_monsters()
    --数据库服务读取怪物数据
    local mysql_service = datacenter.get("mysql_service")

    local monsters = skynet.call( mysql_service, "lua", "save_monsters", monster_data )
end




--系统任务：定时刷新怪物
function CMD.refresh_monsters()
    --遍历怪物列表，检查是否需要刷新
    local clear_ids= {}
    for id, monster in pairs(monster_data) do
        --到时间刷新怪物
        --这里简单示例，实际可以根据游戏需求设计刷新条件
        if monster.refresh_time and os.time() >= monster.refresh_time then
            table.insert(clear_ids, id)
        end
    end

    --删除已刷新的怪物实体
    for _, id in ipairs(clear_ids) do
        CMD.remove_monster(id)
    end

    -- 依据配置文件生成 这里简单示例，实际可以根据游戏需求设计刷新条件
    --重新创建怪物实体
    local new_monster = create_monster("goblin","Goblin Warrior", 1)
    monster_data[new_monster.id] = new_monster


end


--删除怪物实体
function CMD.remove_monster(monster_id)
    local monster = monster_data[monster_id]
    if monster then
        monster_data[monster_id] = nil
        -- 取消订阅战斗事件
        skynet.call( event_service, "lua", "unsubscribe_event", monster.id )
        --通知世界服务器取消注册该怪物实体
        skynet.call( world_service, "lua", "unregister_entity", monster.id )
    end
end


--  战斗发生 
function CMD.battle_start( monster_id )
    local monster = monster_data[monster_id]
    if not monster then
        return nil, "Monster not found"
    end

    local battle_unit = get_battle_unit(monster)
    -- 向battle服务注册怪物战斗单位
    skynet.call( battle_service , "lua", "battle_unit_register", battle_unit )

    monster.status = "in_battle"

    return true
end

-- 战斗结束
function CMD.battle_complete( event_data )

    local monster = monster_data[event_data.target_id] --目前只处理怪物作为防御方的情况
    local victory = event_data.victory
    if not monster then
        return nil, "Monster not found"
    end

    monster.status = "idle"
    
    -- 根据战斗结果处理
    if event_data.victory then
        -- 怪物被击败，移除怪物实体
        CMD.remove_monster(monster.id)

        -- 发放奖励
        -- 读取配置文件,或者使用单独的奖励生成服务，生成奖励
        local reward = {
            gold = 100,
            items = { "sword", "shield" },
        }
        skynet.send( reward_service , "lua", "distribute_reward", event_data.attacker_id, reward )

    else
        -- 怪物获胜，可能进行其他处理
        -- 修改世界服务中的怪物状态等
        skynet.call( world_service, "lua", "update_entity", monster.id, { status = "idle"  } )

    end

    return true
end



skynet.start(function()
    event_service = datacenter.get("event_service")
    world_service = datacenter.get("world_service")
    reward_service = datacenter.get("reward_service")

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

