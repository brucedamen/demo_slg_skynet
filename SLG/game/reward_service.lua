-- 奖励发放服务
local skynet = require "skynet"
local datacenter = require "datacenter"

local city_manager = nil  -- City Manager 服务地址

local M = {}

-- 奖励发放函数
-- player_id: 玩家 ID
-- rewards: 奖励内容，格式为 { { type = "gold", amount = 100 }, { type = "item", id = 1, amount = 2 }, ... }
function M.distribute_reward(player_id, rewards)
  if not player_id or not rewards then
    skynet.error("Invalid reward distribution request")
    return false, "Invalid parameters"
  end

  -- 获取玩家的城市服务地址
  local city_service = skynet.call(city_manager, "lua", "get_city_service", player_id)
  if not city_service then
    skynet.error("Failed to get city service for player_id:", player_id)
    return false, "City service not found"
  end

  -- 发放奖励到城市服务
  local success, err = skynet.call(city_service, "lua", "receive_reward", rewards)
  if not success then
    skynet.error("Failed to distribute reward to city_service:", city_service, "Error:", err)
    return false, err
  end

  return true
end

-- Skynet 服务启动
skynet.start(function()
  city_manager = datacenter.get("city_manager")

  skynet.dispatch("lua", function(_, source, cmd, ...)
    if cmd == "distribute" then
      local player_id, rewards = ...
      local success, err = M.distribute_reward(player_id, rewards)
      skynet.ret(skynet.pack(success, err))
    else
      skynet.ret(skynet.pack(false, "Unknown command"))
    end
  end)
end)


