--科技配置
--technology_pre ()
--结构:
-- tech_config = {
--   [technology_id] = {
--       [level] = {
--           cost = { wood = X, stone = Y, ... }, --研发消耗资源
--           time = Z,                          --研发时间，单位秒
--           prerequisites = { {id = A, level = B}, ... }, --前置科技要求
--           building_level = C,                --科技建筑等级要求
--           effect = { atk = D, def = E, ... } --科技效果加成
--       },
--   },
-- }
-- }

tech_config = {
  [1] = {
    [1] = { cost = { wood = 100, stone = 50 }, time = 60, prerequisites = {}, building_level = 1, effect = { atk = 1 } },
    [2] = { cost = { wood = 200, stone = 100 }, time = 120, prerequisites = {}, building_level = 2, effect = { atk = 2 } },
    [3] = { cost = { wood = 300, stone = 150 }, time = 180, prerequisites = {}, building_level = 3, effect = { atk = 3 } },
  },
  [2] = {
    [1] = { cost = { wood = 150, stone = 80 }, time = 90, prerequisites = { {id = 1, level = 2} }, building_level = 1, effect = { def = 1 } },
    [2] = { cost = { wood = 250, stone = 120 }, time = 150, prerequisites = { {id = 1, level = 2} }, building_level = 2, effect = { def = 2 } },
    [3] = { cost = { wood = 350, stone = 180 }, time = 210, prerequisites = { {id = 1, level = 2} }, building_level = 3, effect = { def = 3 } },
  },
  [3] = {
    [1] = { cost = { wood = 200, stone = 100 }, time = 100, prerequisites = { {id = 2, level = 1} }, building_level = 1, effect = { hp = 1 } },
    [2] = { cost = { wood = 300, stone = 150 }, time = 150, prerequisites = { {id = 2, level = 2} }, building_level = 2, effect = { hp = 2 } },
    [3] = { cost = { wood = 400, stone = 200 }, time = 200, prerequisites = { {id = 2, level = 3} }, building_level = 3, effect = { hp = 3 } },
  },
  [4] = {
    [1] = { cost = { wood = 250, stone = 120 }, time = 110, prerequisites = { {id = 1, level = 3} }, building_level = 1, effect = { speed = 1 } },
    [2] = { cost = { wood = 350, stone = 170 }, time = 160, prerequisites = { {id = 1, level = 3} }, building_level = 2, effect = { speed = 2 } },
    [3] = { cost = { wood = 450, stone = 220 }, time = 210, prerequisites = { {id = 1, level = 3} }, building_level = 3, effect = { speed = 3 } },
  },
  [5] = {
    [1] = { cost = { wood = 300, stone = 150 }, time = 120, prerequisites = { {id = 3, level = 1} }, building_level = 1, effect = { carry_capacity = 1 } },
    [2] = { cost = { wood = 400, stone = 200 }, time = 170, prerequisites = { {id = 3, level = 2} }, building_level = 2, effect = { carry_capacity = 2 } },
    [3] = { cost = { wood = 500, stone = 250 }, time = 220, prerequisites = { {id = 3, level = 3} }, building_level = 3, effect = { carry_capacity = 3 } },
  },
  [6] = {
    [1] = { cost = { wood = 350, stone = 180 }, time = 130, prerequisites = { {id = 2, level = 3} }, building_level = 1, effect = { training_speed = 1 } },
    [2] = { cost = { wood = 450, stone = 230 }, time = 180, prerequisites = { {id = 2, level = 3} }, building_level = 2, effect = { training_speed = 2 } },
    [3] = { cost = { wood = 550, stone = 280 }, time = 230, prerequisites = { {id = 2, level = 3} }, building_level = 3, effect = { training_speed = 3 } },
  },
  [7] = {
    [1] = { cost = { wood = 400, stone = 200 }, time = 140, prerequisites = { {id = 4, level = 1} }, building_level = 1, effect = { march_size = 1 } },
    [2] = { cost = { wood = 500, stone = 250 }, time = 190, prerequisites = { {id = 4, level = 2} }, building_level = 2, effect = { march_size = 2 } },
    [3] = { cost = { wood = 600, stone = 300 }, time = 240, prerequisites = { {id = 4, level = 3} }, building_level = 3, effect = { march_size = 3 } },
  },
  [8] = {
    [1] = { cost = { wood = 450, stone = 220 }, time = 150, prerequisites = { {id = 5, level = 1} }, building_level = 1, effect = { resource_production = 1 } },
    [2] = { cost = { wood = 550, stone = 270 }, time = 200, prerequisites = { {id = 5, level = 2} }, building_level = 2, effect = { resource_production = 2 } },
    [3] = { cost = { wood = 650, stone = 320 }, time = 250, prerequisites = { {id = 5, level = 3} }, building_level = 3, effect = { resource_production = 3 } },
  },
  [9] = {
    [1] = { cost = { wood = 500, stone = 250 }, time = 160, prerequisites = { {id = 6, level = 1}, {id = 7, level = 1} }, building_level = 1, effect = { siege_damage = 1 } },
    [2] = { cost = { wood = 600, stone = 300 }, time = 210, prerequisites = { {id = 6, level = 2}, {id = 7, level = 2} }, building_level = 2, effect = { siege_damage = 2 } },
    [3] = { cost = { wood = 700, stone = 350 }, time = 260, prerequisites = { {id = 6, level = 3}, {id = 7, level = 3} }, building_level = 3, effect = { siege_damage = 3 } },
  }

}
