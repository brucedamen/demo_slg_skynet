local skynet = require "skynet"
local service = require "skynet.service"
local event_map = {}  -- 存储事件订阅者: { id = { [service_address] = { event_set = {event1, event2, ...} }, ... }, ... }

local M = {}

-- 订阅指定 ID 的事件
-- id 是事件的主键，service_address 是订阅者的地址，event_set 是订阅的事件集合
function M.subscribe(id, service_address, event_set)
  event_map[id] = event_map[id] or {}
  event_map[id][service_address] = event_map[id][service_address] or { event_set = {} }
  local existing_set = event_map[id][service_address].event_set

  -- 累加事件集合
  for event_name, _ in pairs(event_set) do
    existing_set[event_name] = true
  end
end

-- 取消订阅指定 ID 的事件
-- id 是事件的主键，service_address 是订阅者的地址，event_set 是要取消订阅的事件集合
function M.unsubscribe(id, service_address, event_set)
  local subscribers = event_map[id]
  if not subscribers or not subscribers[service_address] then return end

  local existing_set = subscribers[service_address].event_set
  if event_set then
    -- 移除指定的事件集合
    for event_name, _ in pairs(event_set) do
      existing_set[event_name] = nil
    end
    -- 如果事件集合为空，移除订阅者
    if next(existing_set) == nil then
      subscribers[service_address] = nil
    end
  else
    -- 如果未指定事件集合，移除订阅者
    subscribers[service_address] = nil
  end

  -- 如果没有订阅者，清理该 ID 的记录
  if next(subscribers) == nil then
    event_map[id] = nil
  end
end

-- 广播事件到指定 ID 的所有订阅者
-- id 是事件的主键，event_name 是事件名称，data 是事件数据
function M.broadcast(id, event_name, data)
  local subscribers = event_map[id]
  if not subscribers then return end

  for service_address, subscription in pairs(subscribers) do
    local event_set = subscription.event_set
    -- 如果订阅者的事件集合包含 event_name，则发送事件
    if not event_set or event_set[event_name] then
      skynet.send(service_address, "lua", event_name, data)
    end
  end
end

-- Skynet 服务启动
skynet.start(function()
  skynet.dispatch("lua", function(_, source, cmd, ...)
    if cmd == "subscribe" then
      local id, service_address, event_set = ...
      M.subscribe(id, service_address, event_set)
      skynet.ret(skynet.pack(true))
    elseif cmd == "unsubscribe" then
      local id, service_address, event_set = ...
      M.unsubscribe(id, service_address, event_set)
      skynet.ret(skynet.pack(true))
    elseif cmd == "broadcast" then
      local id, event_name, data = ...
      M.broadcast(id, event_name, data)
      skynet.ret(skynet.pack(true))
    else
      skynet.ret(skynet.pack(false, "Unknown command"))
    end
  end)
end)
