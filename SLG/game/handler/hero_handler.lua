local skynet = require "skynet"
local handler = require "handler"
local config_hero = require "config.config_hero"

local REQUEST = {}
local CMD = {}
local user
handler = handler.new (REQUEST, nil, CMD)

handler:init (function (u)
	user = u
end)



--英雄相关请求处理
--查询已激活英雄列表
function REQUEST.hero_query(args)
    local heroes = {}
    for id, hero in pairs(user.heroes) do
        if hero.active then
            table.insert(heroes, hero)
        end
    end
    return { success = true, heroes = heroes }
end


--升级英雄
function CMD.hero_gain_experience(hero_id, exp)
    --参数检查
    if not hero_id or not exp then
        return false
    end
    local hero = user.heroes[hero_id]
    if not hero then
        return false
    end

    --升级逻辑
    local levelup = false
    local max_level = #config_hero.hero_levelup_exp
    if hero.level < max_level then
        hero.experience = hero.experience + exp
        --检查是否升级
        while hero.level < max_level and hero.experience >= config_hero.hero_levelup_exp[hero.level] do
            hero.experience = hero.experience - config_hero.hero_levelup_exp[hero.level]
            hero.level = hero.level + 1
        end
    end

    --推送更新
    user.CMD.request_msg("user_hero_update", { hero = hero })

    return true, levelup
end

--激活英雄(使其可用)
function CMD.hero_activate(args)
    --参数检查
    if not args.hero_id then
        return false
    end
    local hero = user.heroes[args.hero_id]
    if not hero then
        return false
    end
    if hero.active then
        return false
    end
    hero.active = true
    return true
end

--锁定英雄(防止被其他操作占用)
function CMD.hero_lock(hero_id)
    local hero = user.heroes[hero_id]
    if not hero then
        return false
    end
    if hero.locked then
        return false
    end
    if not hero.active then
        return false
    end
    hero.locked = true
    return true
end

--解锁英雄
function CMD.hero_unlock(hero_id)
    local hero = user.heroes[hero_id]
    if not hero then
        return false
    end
    hero.locked = false
    return true
end

--英雄升星
function CMD.hero_star_up(hero_id)
    local hero = user.heroes[hero_id]
    if not hero then
        return false
    end
    local max_star = #user.config.hero_star_up_requirements
    if hero.star >= max_star then
        return false
    end
    local req = user.config.hero_star_up_requirements[hero.star + 1]
    --检查材料是否足够
    for item_id, count in pairs(req.materials) do
        if (user.items[item_id] or 0) < count then
            return false
        end    
    end
    --扣除材料
    for item_id, count in pairs(req.materials) do
        user.items[item_id] = user.items[item_id] - count
    end
    --提升星级
    hero.star = hero.star + 1
    return true
end

-- 装备英雄
function CMD.hero_equip(hero_id, equipment)
    local hero = user.heroes[hero_id]
    if not hero then
        return false
    end
    if not hero.active then
        return false
    end
    hero.equipment = equipment
    return true
end

return handler