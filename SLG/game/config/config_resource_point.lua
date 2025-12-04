local config_resource_point = {
  -- 资源点类型: 木材
  wood = {
    [1] = { production_speed = 10, capacity = 100, defense = { troops = 5, level = 1 } },
    [2] = { production_speed = 20, capacity = 200, defense = { troops = 10, level = 2 } },
    [3] = { production_speed = 30, capacity = 300, defense = { troops = 20, level = 3 } },
    -- ...更多等级配置...
  },
  -- 资源点类型: 石材
  stone = {
    [1] = { production_speed = 8, capacity = 80, defense = { troops = 4, level = 1 } },
    [2] = { production_speed = 16, capacity = 160, defense = { troops = 8, level = 2 } },
    [3] = { production_speed = 24, capacity = 240, defense = { troops = 16, level = 3 } },
    -- ...更多等级配置...
  },
  -- 资源点类型: 铁矿
  iron = {
    [1] = { production_speed = 5, capacity = 50, defense = { troops = 3, level = 1 } },
    [2] = { production_speed = 10, capacity = 100, defense = { troops = 6, level = 2 } },
    [3] = { production_speed = 15, capacity = 150, defense = { troops = 12, level = 3 } },
    -- ...更多等级配置...
  },
  -- 资源点类型: 粮食
  food = {
    [1] = { production_speed = 12, capacity = 120, defense = { troops = 6, level = 1 } },
    [2] = { production_speed = 24, capacity = 240, defense = { troops = 12, level = 2 } },
    [3] = { production_speed = 36, capacity = 360, defense = { troops = 24, level = 3 } },
    -- ...更多等级配置...
  },
}

return config_resource_point
