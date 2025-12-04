--在这里处理联盟相关指令，需要转发给game/alliance.lua
local skynet = require "skynet"
local handler = require "handler"

local datacenter = require "datacenter"
local alliance_service

local REQUEST = {}
local CMD = {}
local user
handler = handler.new (REQUEST, nil, CMD)
handler:init (function (u)
    user = u
    alliance_service = datacenter.get("alliance_service")
end)

--联盟相关请求处理

-- 查询联盟信息
function REQUEST.alliance_query(args)
    --查询玩家所属联盟信息
    local alliance_id = user.alliance_id
    if not alliance_id then
        return { success = false, error = "not_in_alliance" }
    end
    --调用alliance服务查询联盟信息
    local alliance_info = skynet.call( alliance_service, "lua", "get_alliance_info", alliance_id, user.id)
    if not alliance_info then
        return { success = false, error = "alliance_not_found" }
    end
    return { success = true, alliance = alliance_info }
end

-- 查询互助任务列表
function REQUEST.alliance_assist_tasks(args)
    --查询玩家所属联盟信息
    local alliance_id = user.alliance_id
    if not alliance_id then
        return { success = false, error = "not_in_alliance" }
    end
    --调用alliance服务查询互助任务列表
    local res = skynet.call( alliance_service, "lua", "get_alliance_assist_tasks", alliance_id)
    return res
end

-- 查询成员列表
function REQUEST.alliance_members(args)
    --查询玩家所属联盟信息
    local alliance_id = user.alliance_id
    if not alliance_id then
        return { success = false, error = "not_in_alliance" }
    end
    --调用alliance服务查询成员列表
    local res = skynet.call( alliance_service, "lua", "get_alliance_members", alliance_id)
    return res
end

-- 创建联盟
function REQUEST.alliance_create(args)
    --参数检查
    if not args.alliance_name then
        return { success = false, error = "invalid_arguments" }
    end
    local alliance_id = skynet.call( alliance_service, "lua", "create_alliance", args.alliance_name, user.id, user.name)
    if not alliance_id then
        return { success = false, error = "create_alliance_failed" }
    end
    -- 保存 联盟ID
    user.alliance_id = alliance_id

    return { success = true, alliance_id = alliance_id }
end

-- 加入联盟 请求被同意
function CMD.join_alliance( alliance_id, alliance_name )
    -- 保存 联盟ID
    user.alliance_id = alliance_id


    -- 通知客户端 加入联盟成功
    user.CMD.send_msg( "alliance_joined", { alliance_id = alliance_id, alliance_name = alliance_name } )
end



--申请加入联盟
function REQUEST.alliance_apply(args)
    if not args.alliance_id then
        return { success = false, error = "invalid_arguments" }
    end
    if user.alliance_id then
        return { success = false, error = "already_in_alliance" }
    end
    local res = skynet.call( alliance_service, "lua", "apply_to_alliance", args.alliance_id, user.id, user.name)

    return res
end
-- 取消申请加入联盟
function REQUEST.alliance_cancel_apply(args)
    if not args.alliance_id then
        return { success = false, error = "invalid_arguments" }
    end
    local res = skynet.call( alliance_service, "lua", "cancel_alliance_apply", args.alliance_id, user.id)
    return res
end

--同意加入联盟申请
function REQUEST.alliance_approve_apply(args)
    --参数检查
    if not args.player_id then
        return { success = false, error = "invalid_arguments" } 
    end

    local alliance_id =  user.alliance_id
    if not alliance_id then
        return { success = false, error = "not_in_alliance" }
    end

    local res = skynet.call( alliance_service, "lua", "approve_apply", alliance_id, user.id, args.player_id)

    return res
end

--拒绝加入联盟申请
function REQUEST.alliance_reject_apply(args)
    --参数检查
    if not args.player_id then
        return { success = false, error = "invalid_arguments" }
    end

    local alliance_id =  user.alliance_id
    if not alliance_id then
        return { success = false, error = "not_in_alliance" }
    end


    local res = skynet.call( alliance_service, "lua", "reject_apply", alliance_id,user.id, args.player_id)
    return res
end

--联盟帮助请求
function REQUEST.alliance_assist_task(args)
    --参数检查
    if not args.task_id then
        return { success = false, error = "invalid_arguments" }
    end
    local alliance_id =  user.alliance_id
    if not alliance_id then
        return { success = false, error = "not_in_alliance" }
    end

    
    local res = skynet.call( alliance_service, "lua", "assist_task", alliance_id, args.task_id, user.id)
    return res
end


-- 联盟事件消息处理
-- 联盟互助 帮助 事件
function CMD.event_aid_helped(data)
    --玩家帮助
    user.CMD.task_help(data.task_id)
    --user.CMD.send_msg( "alliance_aid_helped", { task_id = data.task_id, helper_id = data.helper_id, helper_name = data.helper_name } )
end
-- 联盟互助 移除 事件
function CMD.event_aid_removed(data)
     user.CMD.send_msg( "alliance_aid_removed", { task_id = data.task_id} )
end
-- 联盟互助 注册 事件
function CMD.event_aid_registered(data)
    user.CMD.send_msg( "alliance_aid_registered", { task_id = data.task_id, task_name = data.task_name } )
end


-- 加入联盟成功
function CMD.event_alliance_joined(data)
    if( user.alliance_id ~= nil )then
        --已经有联盟了，忽略
        return
    end
    -- 保存 联盟ID
    user.alliance_id = data.alliance_id

    -- 通知联盟服务 玩家加入联盟 这里是为了防止玩家的新申请未处理(消息队列中)就被其他联盟允许加入了，这会导致一个悬空的申请记录
    -- 所以这里由玩家服务主动通知联盟服务 玩家已加入联盟，清除所有申请记录
    if data.user_id ~= user.id then
        skynet.call( alliance_service, "lua", "alliance_joined", user.id)
    end
    
    -- 通知客户端 加入联盟成功
    user.CMD.send_msg( "alliance_joined", data)
end

-- 联盟解散 事件
function CMD.event_alliance_dismissed(data)
    --清除玩家联盟ID
    user.alliance_id = nil

    -- 通知客户端 联盟解散
    user.CMD.send_msg( "alliance_dismissed", data)
end

return handler