local skynet = require "skynet"
local handler = require "handler"
local config = require "config_quests"


local REQUEST = {}
local CMD = {}
local user
handler = handler.new (REQUEST, nil, CMD)
local question_event = {}

handler:init (function (u)
	user = u
end)


function CMD.load_quest(user_id)
    --加载用户任务数据
    user[user_id].quests = user[user_id].quests or {}
    user[user_id].CompletedQuests = user[user_id].CompletedQuests or {}

    --注册现有任务的监听器
    for quest_id, quest in pairs(user[user_id].quests) do
        for _, obj in pairs(quest.mission_obj) do
            if not question_event[obj.type] then
                question_event[obj.type] = 0
            end
            question_event[obj.type] = question_event[obj.type] + 1
        end
    end
end

--任务注册器
local function quest_register( user_id, quest_id)
    --依据任务，初始化任务数据
    local quest_conf = config[quest_id]
    if not quest_conf then
        return false
    end

    --初始化任务数据
    user[user_id].quests[quest_id] = {
        id = quest_id,
        status = "progressing",
        mission_obj = quest_conf.mission_obj,---因为需要记录每个目标的完成状态，所以直接引用配置中的目标
        
    }
    --去除 description 字段,这是客户端使用的字段，减少服务器存储负担
    for _,t in pairs(user[user_id].quests[quest_id].mission_obj) do
        t.description = nil
    end

    --注册任务监听器
    --遍历任务目标，注册监听器
    for _, obj in pairs(quest_conf.mission_obj) do
        if not question_event[obj.type] then
            question_event[obj.type] = 0
        end
        question_event[obj.type] = question_event[obj.type] + 1
    end

    --检查任务表是否有目标已完成的任务（目前涉及只有建筑等级和科技等级任务可提前完成，其他任务一般需要玩家操作才会完成）
    for _, t in pairs(user[user_id].quests[quest_id].mission_obj) do
        if t.type == "building" then
            --检查建筑等级任务
            local building = nil
            for _, building in pairs(user[user_id].buildings) do
                if building.type == t.target then
                    if building and building.level >= t.level then
                        t.status = "completed"
                    end
                end
            end
        elseif t.type == "technology" then
            --检查科技研发任务
            local tech_level = user[user_id].technologies[t.target] or 0
            if tech_level >= t.level then
                t.status = "completed"
            end
        end
    end
    --检查任务是否全部完成
    local all_completed = true
    for _, t in pairs(user[user_id].quests[quest_id].mission_obj) do
        if t.status ~= "completed" then
            all_completed = false
            break
        end
    end
    if all_completed then
        user[user_id].quests[quest_id].status = "completed"
    end

    --向客户端推送任务更新
    user.send_package(user_id, user.request("quest_update", { quest = user[user_id].quests[quest_id] } ))

    return true
end

--检查是否有任务可接受
local function check_available_quests(user_id)
    -- 可能有多个任务可接受
    local quest = {}
    for quest_id, quest_conf in pairs(config) do
        --检查任务是否已存在或已完成
        if not user[user_id].CompletedQuests[quest_id] and not user[user_id].quests[quest_id] then
            --检查任务接受条件
            local can_accept = true
            if quest_conf.accept_conditions then
                for condition, value in pairs(quest_conf.accept_conditions) do
                    if condition == "level" then
                        if user[user_id].level < value then
                            can_accept = false
                            break
                        end
                    elseif condition == "quest_completed" then
                        local prev_quest = user[user_id].CompletedQuests[value]
                        if not prev_quest  then
                            can_accept = false
                            break
                        end
                    end
                end
            end
            if can_accept then
                table.insert(quest, quest_conf.id)
            end
        end
    end
    return quest
end


--任务接受
local function quest_accept(user_id, quest_id)
    --检查任务是否已存在
    if user[user_id].quests[quest_id] then
        return false
    end
    --检查任务是否已经完成
    if user[user_id].CompletedQuests[quest_id] then
        return false
    end

    --检查任务接受条件（比如初始任务没有限制，直接接受）
    local quest_conf = config[quest_id]
    if not quest_conf.accept_conditions then
        return quest_register(user_id, quest_id)
    end
    for condition, value in pairs(quest_conf.accept_conditions) do
        if condition == "level" then
            if user.level < value then
                return false
            end
        elseif condition == "quest_completed" then
            local prev_quest = user.CompletedQuests[value]
            if not prev_quest  then
                return false
            end
        end
    end
    --注册任务
    quest_register(user_id, quest_id)
    

    return true
end

--完成任务
local function complete_quest(user_id, quest_id)
    local quest = user[user_id].quests[quest_id]
    if not quest then
        return false
    end

    --取消任务监听器
    for _, obj in pairs(quest.mission_obj) do
        if question_event[obj.type] then
            question_event[obj.type] = question_event[obj.type] - 1
            if question_event[obj.type] <= 0 then
                question_event[obj.type] = nil
            end
        end
    end

    --移除任务数据
    user[user_id].quests[quest_id] = nil
    user[user_id].CompletedQuests[quest_id] = true

    
    --向客户端推送任务更新
    user.send_msg( user.request("quest_complete", { quest_id = quest_id } ))

    --检查是否有后续任务可接受
    local quest = check_available_quests(user_id)
    if quest then
        for _, quest in pairs(quest) do
            quest_accept(user_id, quest.id)
        end
    end

    return true
end




--任务完成检测
local function quest_complete_checker(quest_obj, event_data)

    if event_data.type == quest_obj.target and event_data.level >= quest_obj.level then
        quest_obj.progress = (quest_obj.progress or 0) + event_data.count
        if quest_obj.progress >= quest_obj.amount then
            return true
        end 
    end
   
    return false
end
--事件检测器
function CMD.event_check(event_type, event_data)
    --过滤无关事件
    if not question_event[event_type] then
        return
    end

    --遍历所有任务，检查是否有任务与该事件相关
    for quest_id, quest in pairs (user.quests) do
        for _, obj in pairs(quest.mission_obj) do
            if obj.type == event_type and obj.status ~= "completed" then
                --进行任务完成检测
                if quest_complete_checker(obj, event_data) then
                    --标记任务为可完成状态
                    obj.status = "completed"
                    --检测所有目标是否完成
                    local all_completed = true
                    for _, t in pairs(quest.mission_obj) do
                        if t.status ~= "completed" then
                            all_completed = false
                            break
                        end
                    end
                    if all_completed then
                        quest.status = "completed"
                    end
                    --推送任务更新
                    user[event_data.user_id].send_package( user.request("quest_update", { quest = quest } ))
                    return
                end
            end
        end
    end
end


--任务相关请求处理

--查询任务列表
function REQUEST.quest_query( user_id, args)
    --任务不连续，需要格式化到列表
    local quests = {}
    for id, quest in pairs(user[user_id].quests) do
        table.insert(quests, quest)
    end
    return { success = true, quests = quests }
end

--任务完成
function REQUEST.quest_complete(user_id, args)
    local quest_id = args.quest_id
    local quest = user[user_id].quests[quest_id]
    if not quest then
        return false
    end

    -- 处理任务完成逻辑
    --检测任务状态
    if quest.status == "progressing" then
        return false
    end

    --发放奖励 资源和物品
    local rewards = config[quest_id].rewards
    if rewards.resources then
        user.CMD.add_resources(rewards.resources)
    end
    if rewards.items then
        for _, item in pairs(rewards.items) do
            if type(item) == "table" then
                user.CMD.add_item(item.id, item.count)
            else
                user.CMD.add_item(item, 1)
            end
        end
    end
    --标记任务为已完成
    user.CompletedQuests[quest_id] = true
    --移除任务数据
    complete_quest(user_id, quest_id)
    

    return true
end









--

return handler