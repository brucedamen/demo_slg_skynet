local skynet = require "skynet"
local datacenter = require "datacenter"

local rdb = nil

local CMD = {}

local alliance_list = {}
--[[
-- 联盟数据结构示例
{
    初始数据
    id = nil,
    name = "",
    level = 1,
    member_count = 0, -- 成员数量
    leader_id = nil,

    后续载入数据
    members = {id = {id= "", name = "", role = ""}，}, -- 成员列表
    max_members = 50, -- 最大成员数量,依据等级或者科技可提升
    applied_members = {{id = "", name = ""}，}, -- 申请加入成员列表
    assist_tasks = {}, -- 互助任务列表
}
--]]

-- 玩家的申请列表，这里保存就可以在同意申请时直接移除其他申请
local apply_list = {}
--[[
-- 申请列表结构示例
{
    user_id = { alliance_id1, alliance_id2, ... }
}
--]]

-- 用户服务表(用于发送消息等)
local  user_service = {} -- user_id -> service_handle



--载入联盟数据
local function load_all_alliance_data()
    skynet.error("Loading all alliance data")

    --优先使用redis缓存 --- IGNORE ---
    local data = skynet.call( rdb, "lua", "rdb_get_all_alliance")
    if data then
        --redis存在数据，直接加载
        alliance_list = data
        return
    end

    -- 加载所有联盟基本信息 redis无数据，从数据库加载
    local alliance_data = skynet.call( sql, "lua", "get_all_alliance")
    for _, alliance in ipairs(alliance_data) do
        alliance_list[alliance.id] = alliance
    end

    -- 测试数据
    alliance_list[003] = {id= 1, name= "Alpha", level= 5, leader_id= 1001, member_count= 10, max_members= 50, members= {}, applied_members= {}, assist_tasks= {}}


    if( next(alliance_list) == nil ) then
        skynet.error("No alliance data found")
        return
    end
    -- 遍历联盟
    for _, alliance in pairs(alliance_list) do
        -- 查询成员列表
        skynet.error("Members for alliance id:", alliance.id)

        local res = skynet.call( sql, "lua", "get_alliance_members", alliance.id)
        alliance.members = {}
        for _, member in ipairs(res) do
            alliance.members[member.user_id] = {id = member.user_id, name = member.user_name, role = member.role}
        end

        -- 查询成员申请列表
        local member_res = skynet.call( sql, "lua", "get_alliance_applied_members", alliance.id)
        alliance.applied_members = {}
        if #member_res ~= 0 then
            for _, member in ipairs(member_res) do
                alliance.applied_members[member.user_id] = {id = member.user_id, name = member.user_name}
            end
        end

        -- 查询互助任务列表
        local task_res = skynet.call( sql, "lua", "get_alliance_aid_tasks", alliance.id)
        alliance.assist_tasks = task_res

    end

end



-- 广播
local function broadcast_alliance_event(alliance, event_name, data)
    -- 广播给所有成员
    for member_id, _ in pairs(alliance.members) do
        local user_svc = user_service[member_id]
        if user_svc then
            skynet.send(user_svc, "lua", event_name, data)
        end
    end
end


-- 服务初始化
function CMD.start(conf)

    rdb = skynet.newservice("rdb_alliance")
	assert(rdb)
    sql = skynet.newservice("db_alliance")
    assert(sql)
    -- 初始化逻辑
    load_all_alliance_data()
end


-- 创建联盟
function CMD.create_alliance(alliance_name, user_id, user_name)
    skynet.error("Creating alliance:", alliance_name, "Leader ID:", user_id)
    -- 创建联盟逻辑
    local alliance_id = skynet.call( datacenter.get("idgen_service"), "lua", "next_id")
    local new_alliance = {
        alliance_id = alliance_id,
        name = alliance_name,
        level = 1,
        leader_id = user_id,
        member_count = 1,

        max_members = 50,
        members = {},
        applied_members = {},
        assist_tasks = {},
    }
    -- 添加创建者为成员
    new_alliance.members[user_id] = {id = user_id, name = user_name, role = "leader"}
    -- 保存到内存
    alliance_list[new_alliance.alliance_id] = new_alliance

    -- 保存到redis
    skynet.call( rdb, "lua", "rdb_save_alliance", new_alliance)

    -- 保存到数据库
    skynet.send( sql, "lua", "save_alliance_basic_info", new_alliance)
    skynet.send( sql, "lua", "save_alliance_member", new_alliance.alliance_id, new_alliance.members[user_id])

    return alliance_id
end

--注销联盟
function CMD.dismiss_alliance(alliance_id, user_id)
    skynet.error("Dismissing alliance:", alliance_id, "by player:", user_id)
    local alliance = alliance_list[alliance_id]
    if not alliance then
        return { success = false, error = "Alliance not found" }
    end


    -- 只有联盟创建者才能解散联盟
    if alliance.leader_id ~= user_id then
        return { success = false, error = "Only leader can dismiss alliance" }
    end

    --联盟解散


    -- 取消所有申请记录
    local members = alliance.applied_members
    for k,v in pairs(members) do
        apply_list[v.id][alliance_id] = nil
        if next(apply_list[v.id]) == nil then
            apply_list[v.id] = nil
        end
    end

    -- 从数据库删除联盟数据
    skynet.call( rdb, "lua", "rdb_remove_alliance", alliance_id)
    skynet.send( sql, "lua", "remove_alliance", alliance_id)
    
    alliance_list[alliance_id] = nil


    return { success = true }
end

-- 获取联盟信息
function CMD.get_alliance_info(alliance_id, user_id)
    skynet.error("Fetching alliance info for ID:", alliance_id)
    -- 获取联盟信息逻辑
    local alliance = alliance_list[alliance_id]
    if not alliance then
        return { success = false, error = "Alliance not found" }
    end

    local data = {}

    data.alliance_id = alliance.alliance_id
    data.name = alliance.name
    data.level = alliance.level
    data.leader_id = alliance.leader_id
    data.member_count = alliance.member_count
    data.max_members = alliance.max_members

    return { success = true, alliance = data }
end

-- 获取联盟成员列表
function CMD.get_alliance_members(alliance_id)
    skynet.error("Fetching alliance members for ID:", alliance_id)
    -- 获取联盟成员列表逻辑
    local alliance = assert(alliance_list[alliance_id])
    return { success = true, members = alliance.members }
end
-- 获取互助任务列表
function CMD.get_alliance_assist_tasks(alliance_id)
    skynet.error("Fetching alliance assist tasks for ID:", alliance_id)
    -- 获取联盟互助任务列表逻辑
    local alliance = assert(alliance_list[alliance_id])
    return { success = true, assist_tasks = alliance.assist_tasks }
end



-- 获取联盟科技信息 待实现
function CMD.get_alliance_tech_info(alliance_id)
    skynet.error("Fetching alliance tech info for ID:", alliance_id)
    -- 获取联盟科技信息逻辑
    local alliance = assert(alliance_list[alliance_id])

    --这里简单返回一个示例科技信息
    local tech_info = alliance.tech_info or {
        tech_id = 1,
        tech_level = 1,
    }
    return { success = true, tech_info = tech_info }
end


-- 获取联盟列表（申请时用到）
function CMD.get_alliance_list()
    skynet.error("Fetching alliance list")
    --后续优化可以使用单独的排行服务获取表，这里只是简单返回所有联盟
    local alliances = {}
    for _, alliance in pairs(alliance_list) do
        table.insert(alliances, {
            alliance_id = alliance.alliance_id,
            name = alliance.name,
            level = alliance.level,
            member_count = alliance.member_count,
            max_members = alliance.max_members,
        })
    end
    return { success = true, alliances = alliances }
end




-- 申请加入联盟
function CMD.apply_to_alliance(alliance_id, user_id, player_name)
    skynet.error("Player", user_id, "applying to alliance:", alliance_id)
    local alliance = alliance_list[alliance_id]
    if not alliance then
        return { success = false, error = "Alliance not found" }
    end
    -- 加入联盟的申请逻辑

    --检查是否已经申请过
    if (alliance.applied_members[user_id]) then
        return { success = false, error = "Already applied" }
    end
    --添加到申请列表
    alliance.applied_members[user_id] = { id = user_id, name = player_name }

    --记录玩家申请的联盟
    apply_list[user_id] = apply_list[user_id] or {}
    apply_list[user_id][alliance_id] = true

    
    -- redis
    skynet.call( rdb, "lua", "rdb_save_alliance_applied_member", alliance_id, {id = user_id, name = player_name})
    -- database
    skynet.send( sql, "lua", "save_alliance_applied_member", alliance_id, {id = user_id, name = player_name})

    return { success = true }
end
--取消申请加入联盟
function CMD.cancel_alliance_apply(alliance_id, user_id)
    skynet.error("Player", user_id, "cancelling application to alliance:", alliance_id)
    local alliance = alliance_list[alliance_id]
    if not alliance then
        return { success = false, error = "Alliance not found" }
    end

    -- 移除申请记录
    alliance.applied_members[user_id] = nil
    
    -- 移除玩家申请的联盟记录
    apply_list[user_id][alliance_id] = nil
    if next(apply_list[user_id]) == nil then
        apply_list[user_id] = nil
    end


    -- redis_db
    skynet.call( rdb, "lua", "rdb_remove_alliance_applied_member", alliance_id, user_id)
    -- database
    skynet.send( sql, "lua", "remove_alliance_applied_member", alliance_id, user_id)

    return { success = true }
end

--同意加入联盟申请
function CMD.approve_application(alliance_id, approver_id, user_id)
    local alliance = alliance_list[alliance_id]
    if not alliance then
        return { success = false, error = "Alliance not found" }
    end

    --权限检查，只有联盟领导者或管理员可以批准
    local approver = alliance.members[approver_id]
    if not approver or (approver.role ~= "leader" and approver.role ~= "admin") then
        return { success = false, error = "Insufficient permissions" }
    end

    -- 添加成员到联盟
    local member = alliance.applied_members[user_id]
    alliance.members[user_id] = {id = user_id,name = member.name, role = "member"}
    alliance.member_count = alliance.member_count + 1


    -- 保存到redis  新增成员
    skynet.call( rdb, "lua", "rdb_save_alliance_member", alliance_id, alliance.members[user_id])
    -- 保存到数据库
    skynet.send( sql, "lua", "save_alliance_member", alliance_id, alliance.members[user_id])

    -- 通知成员 加入联盟成功 （ 申请记录由玩家服务主动清除）
    broadcast_alliance_event(alliance, "event_member_joined", {
        alliance_id = alliance_id,
        user_id = user_id,
        user_name = member.name,
    })

    return { success = true }
end
--拒绝加入联盟申请
function CMD.reject_apply(alliance_id, approver_id, user_id)
    skynet.error("Player", approver_id, "rejecting application of player", user_id, "to alliance:", alliance_id)
    local alliance = alliance_list[alliance_id]
    if not alliance then
        return { success = false, error = "Alliance not found" }
    end

    --权限检查，只有联盟领导者或管理员可以批准
    local approver = alliance.members[approver_id]
    if not approver or (approver.role ~= "leader" and approver.role ~= "officer") then
        return { success = false, error = "Insufficient permissions" }
    end

    -- 移除申请记录
    alliance.applied_members[user_id] = nil
    
    -- 移除玩家的记录
    apply_list[user_id][alliance_id] = nil
    if next(apply_list[user_id]) == nil then
        apply_list[user_id] = nil
    end


    -- redis_db
    skynet.call( rdb, "lua", "rdb_remove_alliance_applied_member", alliance_id, user_id)
    -- database
    skynet.send( sql, "lua", "remove_alliance_applied_member", alliance_id, user_id)


    -- 通知玩家 申请被拒绝（也许不需要）
    --skynet.send(user_service[user_id], "lua","event_apply_rejected", alliance_id)

    return { success = true }
end

-- 加入联盟成功
function CMD.alliance_joined(user_id)
    -- 清除玩家所有的申请
        -- 移除玩家所有申请记录
    if apply_list[user_id] then
        for alliance_id, _ in pairs(apply_list[user_id]) do
            local alliance = alliance_list[alliance_id]
            if alliance then
                alliance.applied_members[user_id] = nil
            end
        end
        apply_list[user_id] = nil
    end
end


--注册用户服务
function CMD.user_register(user_id, user_svc)
    user_service[user_id] = user_svc
end
-- 注销用户服务
function CMD.user_unregister(user_id)
    user_service[user_id] = nil
end



--注册互助任务
function CMD.register_assist_task(alliance_id, task_id, task_name)
    skynet.trace("Registering assist task for alliance:"..tostring( alliance_id))

    local alliance = alliance_list[alliance_id]
    if not alliance then
        return { success = false, error = "Alliance not found" }
    end

    --保存任务到表
    local task = {}
    task.id = task_id
    task.name = task_name
    task.helpers = {}
    table.insert(alliance.assist_tasks, task)

    skynet.call( rdb, "lua", "rdb_save_alliance_aid_task", alliance_id, task)
    skynet.send( sql, "lua", "save_alliance_aid_task", alliance_id, task)

    broadcast_alliance_event(alliance, "event_aid_registered", {
        task_id = task_id,
        task_name = task_name
    })

    return { success = true }
end

-- 取消互助任务
function CMD.unregister_assist_task(alliance_id, task_id)
    skynet.trace("Unregistering assist task"..tostring(task_id).." for alliance:"..tostring(alliance_id))
    -- 取消互助任务逻辑
    local alliance = alliance_list[alliance_id]
    if not alliance then
        return { success = false, error = "Alliance not found" }
    end
    --从任务列表中移除
    for i, task in ipairs(alliance.assist_tasks) do
        if task.id == task_id then
            table.remove(alliance.assist_tasks, i)
            break
        end
    end

    skynet.call( rdb, "lua", "rdb_remove_alliance_aid_task", alliance_id, task_id)
    skynet.send( sql, "lua", "remove_alliance_aid_task", alliance_id, task_id)


    broadcast_alliance_event(alliance, "event_aid_removed", {
        task_id = task_id,
    })

    return { success = true }
end

--帮助完成互助任务
function CMD.assist_task(alliance_id, task_id, helper_id)
    skynet.error("Helper", helper_id, "assisting task", task_id, "in alliance", alliance_id)
    -- 帮助完成任务逻辑
    local alliance = alliance_list[alliance_id]
    if not alliance then
        return { success = false, error = "Alliance not found" }
    end

    --获取帮助者名称
    local helper_name = alliance.members[helper_id] and alliance.members[helper_id].name or nil


    --查找任务
    for i, task in ipairs(alliance.assist_tasks) do
        if task.id == task_id then
            --最多只能帮助10次
            if #task.helpers >= 10 then
                return { success = false, error = "Max helpers reached" }
            end
            --记录帮助者ID
            task.helpers = task.helpers or {}
            --一个人只能帮助一次
            for _, hid in ipairs(task.helpers) do
                if hid == helper_id then
                    return { success = false, error = "Already helped" }
                end
            end
            --添加帮助者
            table.insert(task.helpers, helper_id)

            if #task.helpers >= config.max_helpers then
                --任务完成，移除任务
                table.remove(alliance.assist_tasks, i)
                skynet.call( rdb, "lua", "rdb_remove_alliance_aid_task", alliance_id, task_id)
                skynet.send( sql, "lua", "remove_alliance_aid_task", alliance_id, task_id)
            else
                skynet.call( rdb, "lua", "rdb_add_alliance_aid_task_helper", alliance_id, task_id, helper_id)
                skynet.send( sql, "lua", "add_alliance_aid_task_helper", alliance_id, task_id, helper_id)   
            end

            -- 广播帮助事件 
            broadcast_alliance_event(alliance, "event_aid_helped", {
                task_id = task_id,
                helper_id = helper_id,
                helper_name = helper_name,
                current_helpers = #task.helpers,
            })

            if #task.helpers >= config.max_helpers then
                -- 广播任务移除事件
                broadcast_alliance_event(alliance, "event_aid_removed", {
                task_id = task_id,
            })
            end

            return { success = true }
        end
    end



    return { success = false, error = "Task not found" }
end

-- 服务入口
skynet.start(function()

    dao = datacenter.get("alliance_db")

    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            skynet.error("Unknown command:", cmd)
        end
    end)
end)