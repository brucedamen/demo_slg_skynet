local skynet = require "skynet"
local math = math

local movement_map = {}  -- 存储移动任务: { id = { service, source_pos, target_pos, speed, progress }, ... }
local tick_center = nil  -- 中心 tick 服务地址

local M = {}

-- 启动移动任务
-- id: 唯一标识符
-- service: 回调的服务地址
-- source_pos: 起始位置 { x, y }
-- target_pos: 目标位置 { x, y }
-- speed: 移动速度（单位距离/秒）
function M.start(id, service, source_pos, target_pos, speed)
  if movement_map[id] then
    skynet.error("Movement already exists for id:", id)
    return false
  end

  movement_map[id] = {
    service = service,
    source_pos = source_pos,
    target_pos = target_pos,
    speed = speed,
    progress = 0,  -- 初始进度为 0
    current_pos = { x = source_pos.x, y = source_pos.y }
  }
  return true
end

-- 停止移动任务
-- id: 唯一标识符
function M.stop(id)
  if not movement_map[id] then
    skynet.error("No movement found for id:", id)
    return nil
  end

  local movement = movement_map[id]
  movement_map[id] = nil
  return movement.x, movement.y
end

-- 加速移动任务
-- id: 唯一标识符
-- time_reduction: 减少的时间（秒）
function M.accelerate(id, time_reduction)
  local movement = movement_map[id]
  if not movement then
    skynet.error("No movement found for id:", id)
    return false
  end

  local source = movement.source_pos
  local target = movement.target_pos
  local total_distance = math.sqrt((target.x - source.x)^2 + (target.y - source.y)^2)
  local remaining_distance = (1 - movement.progress) * total_distance
  local reduced_distance = movement.speed * time_reduction

  -- 更新进度
  movement.progress = math.min(movement.progress + reduced_distance / total_distance, 1)
  -- 更新当前位置
  movement.current_pos.x = source.x + (target.x - source.x) * movement.progress
  movement.current_pos.y = source.y + (target.y - source.y) * movement.progress

  -- 如果任务完成，立即触发回调
  if movement.progress >= 1 then
    skynet.send(movement.service, "lua", "movement_complete", id, target)
    movement_map[id] = nil  -- 移除已完成的任务
  end

  return true
end

-- 更新移动任务
-- delta_time: 时间增量（秒）
local function update_movements(delta_time)
  for id, movement in pairs(movement_map) do
    local source = movement.source_pos
    local target = movement.target_pos
    local speed = movement.speed

    -- 计算总距离和当前进度
    local total_distance = math.sqrt((target.x - source.x)^2 + (target.y - source.y)^2)
    local distance_covered = movement.progress * total_distance
    local step_distance = speed * delta_time

    -- 更新进度
    distance_covered = distance_covered + step_distance
    movement.progress = math.min(distance_covered / total_distance, 1)

    -- 如果需要，可以在这里通知服务当前进度
    --skynet.send(movement.service, "lua", "movement_progress", id, movement.progress)

    -- 检查是否到达目标
    if movement.progress >= 1 then
      skynet.send(movement.service, "lua", "movement_complete", id, target)
      movement_map[id] = nil  -- 移除已完成的任务
    end
  end
end

-- Skynet 服务启动
skynet.start(function()
  skynet.dispatch("lua", function(_, source, cmd, ...)
    if cmd == "start" then
      local id, service, source_pos, target_pos, speed = ...
      local result = M.start(id, service, source_pos, target_pos, speed)
      skynet.ret(skynet.pack(result))
    elseif cmd == "stop" then
      local id = ...
      local result = M.stop(id)
      skynet.ret(skynet.pack(result))
    elseif cmd == "accelerate" then
      local id, time_reduction = ...
      local result = M.accelerate(id, time_reduction)
      skynet.ret(skynet.pack(result))
    elseif cmd == "tick" then
      -- 接收中心 tick 服务的驱动
      update_movements(0.1)  -- 每次 tick 更新 0.1 秒
    else
      skynet.ret(skynet.pack(false, "Unknown command"))
    end
  end)

  -- 注册到中心 tick 服务
  skynet.init(function()
    tick_center = skynet.uniqueservice("game/tick_center")  -- 获取中心 tick 服务
    skynet.send(tick_center, "lua", "register", skynet.self())
  end)
end)
