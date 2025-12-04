local skynet = require "skynet"
local M = {}
local task_map = {}
local id_counter = 0


local function start_ticker()
  skynet.fork(function()
    while true do
      M.tick(0.1)  -- 每 0.1s 推进一次
      skynet.sleep(10)     -- sleep 100 = 1000ms
      if next(task_map) == nil then
        break
      end
    end
  end)
end



function M.create(id, delay, func)
  task_map[id] = {
    remain = delay,
    func = func,
    active = true,
  }
  if #(task_map) >= 1 then
    start_ticker()
  end
  return id
end

function M.reduce(id, delta)
  local task = task_map[id]
  if task and task.active then
    task.remain = task.remain - delta
    return true
  end
  return false
end

function M.trigger(id)
  local task = task_map[id]
  if task and task.active then
    task.active = false
    task_map[id] = nil
    pcall(task.func, id)  
    return true
  end
  return false
end

function M.cancel(id)
  local task = task_map[id]
  if task then
    task.active = false
    task_map[id] = nil
    return true
  end
  return false
end

function M.tick(delta)
  for id, task in pairs(task_map) do
    if task.active then
      task.remain = task.remain - delta
      if task.remain <= 0 then
        task.active = false
        task_map[id] = nil
        pcall(task.func, id)  
      end
    end
  end
end

return M