local skynet = require "skynet"
local handler = require "handler"
local timewheel = require "time_wheel"
local datacenter = require "datacenter"
local alliance_service = datacenter.get("alliance_service")


local REQUEST = {}
local CMD = {}
local user




handler = handler.new (REQUEST, nil, CMD)

handler:init (function (u)
	user = u
end)


--task
-- {
--     id = 123,                 -- 任务ID
--     target_id = 101,          -- 目标ID（建筑ID/科技ID等）
--     target_type = "building", -- 类型：building/technology
--     status = "producing",     -- 状态：upgrading/producing/researching
--     start_time = 1234567890,  -- 开始时间
--     duration = 300,           -- 持续时间（秒）
--     savetime = 60,            -- 已节省时间（秒）

--     soldier = { type = "infantry", level = 2, count = 50 }, --生产士兵信息  --building任务特有
--     on_task_complete = cb1, --完成回调
--     on_task_cancel = cb2 --取消回调
-- }


--定时器回调
local function time_callback(id)
    local task = user.tasks[id]
    if task then
        --调用任务完成回调(给自己发送消息)
        skynet.send( skynet.self(), "lua", task.on_task_complete, task)
    end
end


-- 载入任务数据
function CMD.load_tasks(task_list)
    user.tasks = task_list or {}

    --在这里初始化定时器
    return true
end

--任务查询请求处理
function REQUEST.task_query(args)
    local tasks = {}
    for id, task in pairs(user.tasks) do
        table.insert(tasks, task)
    end

    --返回任务列表
    return { success = true, tasks = tasks }
end

--任务信息查询
function REQUEST.task_info(args)
    --参数检查
    if not args.task_id then
        return { success = false, error = "invalid_arguments" }
    end
    local task = user.tasks[args.task_id]
    if not task then
        return { success = false, error = "task_not_found" }
    end

    return { success = true, task = task }
end

--任务取消请求处理
function REQUEST.task_cancel(user_id, args)
    --参数检查
    if not args.task_id then
        return { success = false, error = "invalid_arguments" }
    end
    local task = user[user_id].tasks[args.task_id]

    if not task then
        return { success = false, error = "task_not_found" }
    end

    --调用取消回调
    skynet.call( skynet.self(), "lua", task.on_task_cancel, task)

    -- 联盟互助任务注销
    skynet.call( alliance_service, "lua", "unregister_assist_task", task.id)


    --取消只有操作成功，后续的清理工作由回调处理（如删除任务，变为返回任务等）
    return { success = true }
end


--任务载入
function CMD.task_load()
    for _, task in pairs(user.tasks) do
        --注册定时器
        local elapsed = os.time() - task.start_time
        local remaining = math.max(0, task.duration - elapsed)
        if remaining > 0 then
            timewheel.create_timer(task.id, remaining, time_callback)
        else
            --任务时间已到 直接调用回调处理
            skynet.send( skynet.self(), "lua", task.on_task_complete, task)
        end
    end

end

--任务创建
function CMD.task_create(task)
    --参数检查
    if not task.target_id then
        return { success = false, error = "invalid_arguments" }
    end

    --如果有每种类型任务的限制，可以在这里检查，比如VIP多几条队列


    -- 保存任务到表
    user.tasks[task.id] = task

    --创建定时器
    if( task.duration  ~= nil) then
        timewheel.create_timer(task.id, task.duration, time_callback)
    end

    --联盟互助任务注册 让联盟成员可以帮助加速
    skynet.call( alliance_service, "lua", "register_assist_task", task)


    return true
end




--任务完成
function CMD.task_complete(task_id)
    --参数检查
    local task = user.tasks[task_id]
    if not task then
        return false
    end

    --由回调处理任务状态 完成任务--使用此消息 触发特效之类的
    user.CMD.request_msg( "task_complete", { task_id = task_id })

    user.tasks[task_id] = nil
    return
end
--任务关闭
function CMD.task_close(task_id)
    --参数检查
    local task = user.tasks[task_id]
    if not task then
        return false
    end
    --由回调处理任务状态 关闭任务--用于区别完成任务
    user.CMD.request_msg( "task_close", { task_id = task_id })

    user.tasks[task_id] = nil
    return
end

--任务加速
function CMD.task_speedup(task_id, amount, limit_type)
    --参数检查
    if not task_id or not amount then
        return false
    end
    local task = user.tasks[task_id]
    if not task then
        return false
    end

    if limit_type then
        --检查加速是否符合限制类型
        if task.target_type ~= limit_type then
            return false
        end
    end

    --假设任务加速成功
    task.savetime = task.savetime + amount

    --调用时间服务减少时间
    timewheel.reduce_timer(task_id, amount)

    -- 通知客户端 任务加速更新
    user.CMD.send_msg( "task_update", { task_id = task_id, savetime = task.savetime } )

    return true
end


--任务帮助加速
function CMD.task_help( task_id)
    --参数检查
    if not task_id  then
        return false
    end
    local task =  user.tasks[task_id]
    if not task then
        return false
    end

    --计算加速量
    local amount = 30 --每次帮助加速30秒(实际中可根据某个建筑等级来定)

    --减少时间
    CMD.task_speedup(task_id, amount)


    return true
end

--任务查询
function CMD.task_query(type)
    local tasks = {}
    for id, task in pairs(user.tasks) do
        if type ~= nil and task.type == type then
            table.insert(tasks, task)
        else
            table.insert(tasks, task)
        end
    end
    return tasks
end

return handler