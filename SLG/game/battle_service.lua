local skynet = require "skynet"
local datacenter = require "skynet.datacenter"


---- 战斗处理模块


-- 战斗编队集合
local battle_units = {}
-- 战斗处理模块
local battle_datas = {}



-- 战斗结束检测
local function check_battle_over(source_data, target_data)  
    if source_data.hp <= 0 then
        source_data.victory = false
        target_data.victory = true
        return true
    end
    if target_data.hp <= 0 then
        target_data.victory = false
        source_data.victory = true
        return true
    end

    return false
end


--战斗处理，简单模拟战斗过程
local function tick()
    for id, attack_info in pairs(battle_datas) do
        --简单模拟战斗结果
        local attack_unit = battle_units[attack_info.source_id]
        local target_unit = battle_units[attack_info.target_id]
        if not attack_unit or not target_unit then
            --数据异常，移除战斗数据
            battle_datas[id] = nil
            goto continue
        end


        --简单的互相攻击扣除血量
        attack_unit.hp =  attack_unit.hp -  (target_unit.attack - attack_unit.defense)
        target_unit.hp =  target_unit.hp -  (attack_unit.attack - target_unit.defense)


        if( check_battle_over(attack_unit, target_unit) ) then
            --移除已结束的战斗数据
            battle_datas[id] = nil

            local battle_result = {
                source_id = attack_info.source_id,
                target_id = attack_info.target_id,
                victory = attack_unit.victory,
            }

            -- 消息通知 战斗结束
            skynet.send( event_service, "lua", attack_info.source_id, "battle_complete", battle_result )
            skynet.send( event_service, "lua", attack_info.target_id, "battle_complete", battle_result )
        end
        ::continue::
    end
end





local CMD = {}

-- 战斗结构注册
function CMD.battle_unit_register(id, battle_unit)
    if not id or not battle_unit then
        return false
    end

    if battle_units[id] then -- 已注册
        return false
    end

    battle_units[id] = battle_unit
    return true
end

--注册攻击事件
function CMD.register_attack( attack_info )
    if not attack_info.source_id  or not attack_info.target_id  then
        return false
    end

    -- 发布战斗开始事件(双方) 让双方推送战斗数据 准备战斗( 已经在战斗的不处理 )
    if( not battle_units[attack_info.source_id] ) then
        skynet.send( event_service, "lua",attack_info.source_id, "battle_start", attack_info )
    end
    if( not battle_units[attack_info.target_id] ) then
        skynet.send( event_service, "lua",attack_info.target_id, "battle_start", attack_info )
    end


    -- 创建战斗数据
    battle_datas[attack_info.id] = attack_info
    
    return true
end



-- 服务入口
skynet.start(function()
    --0.5stick 处理战斗
    skynet.fork(function()
        while true do
            skynet.sleep(50)  --0.5s
            tick()
        end
    end)

    event_service = datacenter.get("event_service")
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            skynet.error("Unknown command:", cmd)
        end
    end)
end)