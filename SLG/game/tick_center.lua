local skynet = require "skynet"

local tick_services = {}  -- 存储注册的服务: { [service_address] = true, ... }

local M = {}

-- 注册服务到 tick 中心
function M.register(service_address)
  tick_services[service_address] = true
end

-- 取消注册服务
function M.unregister(service_address)
  tick_services[service_address] = nil
end

-- 定时驱动所有注册的服务
local function tick()
  for service_address, _ in pairs(tick_services) do
    skynet.send(service_address, "lua", "tick")  -- 通知服务执行 tick
  end
end

-- Skynet 服务启动
skynet.start(function()
  skynet.dispatch("lua", function(_, source, cmd, ...)
    if cmd == "register" then
      local service_address = ...
      M.register(service_address)
      skynet.ret(skynet.pack(true))
    elseif cmd == "unregister" then
      local service_address = ...
      M.unregister(service_address)
      skynet.ret(skynet.pack(true))
    else
      skynet.ret(skynet.pack(false, "Unknown command"))
    end
  end)

  -- 定时驱动
  skynet.fork(function()
    while true do
      tick()
      skynet.sleep(10)  -- 每 0.1 秒执行一次 (skynet.sleep 的单位是 0.01 秒)
    end
  end)
end)
