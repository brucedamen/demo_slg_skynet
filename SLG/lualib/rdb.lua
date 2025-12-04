
local command = {}
local rdb = nil

------------------------------------------------------
-- 通用存储函数：把 Lua table 存到 Redis Hash
------------------------------------------------------
local function save_table(db, key, tbl)
    -- 使用hmset存储表字段
    local data = {}
    for field, value in pairs(tbl) do
        if( type(value) == "table" ) then
            --跳过table类型字段
            goto continue
        end
        -- 所有值转成字符串存储
        table.insert(data, field)
        table.insert(data, tostring(value))
        ::continue::
    end
    db:hmset(key, table.unpack(data))
end

------------------------------------------------------
-- 通用读取函数：把 Redis Hash 转换回 Lua table
-- 支持自动类型转换（数字转 number）
------------------------------------------------------
local function load_table(db, key)
    local raw = db:hgetall(key)
    local result = {}
    for field, value in pairs(raw) do
        -- 如果是纯数字字符串，转成 number
        local num = tonumber(value)
        if num ~= nil then
            result[field] = num
        else
            result[field] = value
        end
    end
    return result
end



-- 初始化 Redis 连接
function command.rdb_init(redis_db)
    rdb = redis_db
end

-- 获取所有联盟数据从redisdb
function command.rdb_get_all_alliance()
    -- alliance:ids  保存所有联盟ID的key set
    -- alliance:1001 {id= 1001, name= "Alliance1", level= 5, leader_id= 2001, member_count= 50}  -- 联盟基本信息  hash
    -- alliance:members:1001 {2001,2002, ...}      -- 联盟成员表  set
    -- alliance:applied_members:1001 {3001, 3002, ...}      -- 联盟申请成员表 set
    -- member:2001 {id= 2001, name= "Player1", role= "leader"}  -- 成员基本信息  hash
    -- applied_member:2001 {id= 2001, name= "Player1", role= "role"}  -- 申请成员基本信息  hash

    assert(rdb ~= nil, "Redis DB not initialized")

    local alliance_ids = rdb:smembers("alliance:ids")
    if alliance_ids then
        -- 从ID表中获取每个联盟的基本信息
        local alliances = {}
        for _, id in ipairs(alliance_ids) do
            local alliance_id = tonumber(id)
            -- 获取联盟基本信息
            local key = "alliance:" .. tostring(alliance_id)
            local alliance_data = load_table(rdb, key)
            alliances[alliance_id] = alliance_data

            -- 获取成员列表
            local members_key = "alliance:" .. tostring(alliance_id) .. ":members"
            local members_list = rdb:smembers(members_key)
            local member_entries = {}
            for _, id in ipairs(members_list) do  --必定有leader,无需判断空
                local member_key = "member:" .. tostring(id)
                local member_data = load_table(rdb, member_key)
                member_entries[member_data.id] = member_data
            end
            alliances[alliance_id].members = member_entries

            -- 获取申请成员列表
            local applied_members_key = "alliance:" .. tostring(alliance_id) .. ":applied_members"
            local applied_members_list = rdb:smembers(applied_members_key)
             alliances[alliance_id].applied_members = {}
            if( applied_members_list ~= nil ) then --- 可能无人申请
                for _, id in ipairs(applied_members_list) do
                    local member_key = "member:" .. tostring(id)
                    local member_data = load_table(rdb, member_key)
                    alliances[alliance_id].applied_members[member_data.id] = member_data
                end
            end

            -- 获取互助任务列表
            alliances[alliance_id].assist_tasks = {}
            local aid_tasks_key = "alliance:" .. tostring(alliance_id) .. ":aid_tasks"
            local aid_task_ids = rdb:smembers(aid_tasks_key)
            if ( aid_task_ids ~= nil ) then-- 可能无互助任务
                for _, task_id in ipairs(aid_task_ids) do
                    local task_key = "alliance:" .. tostring(alliance_id) .. ":aid_task:" .. tostring(task_id)
                    local helper_ids = rdb:smembers(task_key)
                    -- 构建任务对象
                    local task = {
                        id = tonumber(task_id),
                        helper_ids = {},
                    }
                    if( helper_ids ~= nil ) then -- 可能无人帮助
                        for _, hid in ipairs(helper_ids) do
                            table.insert(task.helper_ids, tonumber(hid))
                        end
                    end
                    table.insert(alliances[alliance_id].assist_tasks, task)
                end
            end

        end
        return alliances
    end
end

-- 保存单个联盟数据到redisdb
function command.rdb_save_alliance(alliance)

    assert(rdb ~= nil, "Redis DB not initialized")

    -- 更新 联盟存在表
    rdb:sadd("alliance:ids", alliance.id)


    -- 存 alliance 基本信息（save_table会过滤table，覆盖原有数据）
    save_table( rdb, "alliance:"..alliance.id, alliance)


    -- 存成员列表（成员table,单独处理）
    for _, m in ipairs(alliance.members) do
        rdb:sadd("alliance:"..alliance.id..":members", m.id)
        save_table(rdb, "member:"..m.id, m)
    end

    -- 存申请成员列表
    for id, m in ipairs(alliance.applied_members) do
        if( rdb:incr("applied_member:"..m.id..":ref_count") == 1) then 
            rdb:sadd("alliance:"..alliance.id..":applied_members", m.id)
            save_table(rdb, "applied_member:"..m.id, m)
        end
    end

    -- 保存联盟互助任务列表
    for _, task in ipairs(alliance.assist_tasks) do
        -- 任务id set
        rdb:sadd("alliance:"..alliance.id..":aid_tasks", task.id)
        -- 存储任务基本信息
        local task_key = "alliance:"..alliance.id..":aid_task:"..task.id
        rdb:sadd(task_key, tostring(task.id))
    end
end

-- 移除联盟
function command.rdb_remove_alliance(alliance_id)

    assert(rdb ~= nil, "Redis DB not initialized")

    -- 移除 联盟存在表
    rdb:srem("alliance:ids", alliance_id)

    -- 移除 联盟基本信息
    rdb:del("alliance:"..alliance_id)

    -- 移除 成员信息
    local members_key = "alliance:"..alliance_id..":members"
    local member_ids = rdb:smembers(members_key)
    for _, member_id in ipairs(member_ids) do
        rdb:del("member:"..member_id)
    end
    rdb:del(members_key)

    -- 移除 申请成员信息
    local applied_members_key = "alliance:"..alliance_id..":applied_members"
    local applied_member_ids = rdb:smembers(applied_members_key)

    for _, member_id in ipairs(applied_member_ids) do
        -- 引用校验，移除申请成员信息
        if( rdb:decr("applied_member:"..member_id..":ref_count") == 0) then
            rdb:del("applied_member:"..member_id)
        end
    end
    -- 删除申请成员列表
    rdb:del(applied_members_key)

    -- 移除 互助任务信息
    local aid_tasks_key = "alliance:"..alliance_id..":aid_tasks"
    local aid_task_ids = rdb:smembers(aid_tasks_key)
    for _, task_id in ipairs(aid_task_ids) do
        local task_key = "alliance:"..alliance_id..":aid_task:"..task_id
        rdb:del(task_key)
    end
    rdb:del(aid_tasks_key)

end

-- 联盟添加成员
function command.rdb_add_alliance_member(alliance_id, member)
    assert(rdb ~= nil, "Redis DB not initialized")
    -- 添加成员ID到成员列表
    rdb:sadd("alliance:"..alliance_id..":members", member.id)
    -- 保存成员基本信息
    save_table(rdb, "member:"..member.id, member)
end

-- 联盟移除成员
function command.rdb_remove_alliance_member(alliance_id, member_id)
    assert(rdb ~= nil, "Redis DB not initialized")
    -- 从成员列表移除成员ID
    rdb:srem("alliance:"..alliance_id..":members", member_id)
    -- 删除成员基本信息
    rdb:del("member:"..member_id)
end
-- 添加联盟申请成员
function command.rdb_add_alliance_applied_member(alliance_id, member)
    assert(rdb ~= nil, "Redis DB not initialized")
    -- 添加申请成员ID到申请成员列表
    rdb:sadd("alliance:"..alliance_id..":applied_members", member.id)
    -- 保存申请成员基本信息
    if( rdb:incr("applied_member:"..member.id..":ref_count") == 1 ) then
        save_table(rdb, "applied_member:"..member.id, member)
    end
end
-- 移除联盟申请成员
function command.rdb_remove_alliance_applied_member(alliance_id, member_id)
    assert(rdb ~= nil, "Redis DB not initialized")
    -- 从申请成员列表移除成员ID
    rdb:srem("alliance:"..alliance_id..":applied_members", member_id)
    -- 删除申请成员基本信息
    if( rdb:decr("applied_member:"..member_id..":ref_count") == 0 ) then
        rdb:del("applied_member:"..member_id)
    end
end
-- 添加联盟互助任务
function command.rdb_add_alliance_aid_task(alliance_id, task)
    assert(rdb ~= nil, "Redis DB not initialized")
    -- 任务id set
    rdb:sadd("alliance:"..alliance_id..":aid_tasks", task.id)
end
-- 移除联盟互助任务
function command.rdb_remove_alliance_aid_task(alliance_id, task_id)
    assert(rdb ~= nil, "Redis DB not initialized")
    -- 从任务id set移除
    rdb:srem("alliance:"..alliance_id..":aid_tasks", task_id)
    -- 删除任务基本信息
    local task_key = "alliance:"..alliance_id..":aid_task:"..task_id
    rdb:del(task_key)
end
-- 添加互助任务帮助者
function command.rdb_add_alliance_aid_task_helper(alliance_id, task_id, helper_id)
    assert(rdb ~= nil, "Redis DB not initialized")
    local task_key = "alliance:"..alliance_id..":aid_task:"..task_id
    rdb:sadd(task_key, tostring(helper_id))
end


return command