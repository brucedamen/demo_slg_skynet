local Config = {}




Config.building = {
    townhall = { type = "townhall", max_level = 10 },
    infantry = { type = "infantry", max_level = 10, produce_type = "infantry" },
    archery = { type = "archery", max_level = 10, produce_type = "archery" },
    stable = { type = "cavalry", max_level = 10, produce_type = "cavalry" },
    technology = { type = "technology", max_level = 10},
}


--每个等级的体力恢复速度
Config.power_recovery_speed = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10} -- 1-10级


--升级各个建筑所需时间（秒）
Config.upgrade_time = {
    townhall = {0, 60, 120, 180, 240, 300, 360, 420, 480, 540}, -- 主城升级时间
    infantry = {0, 30, 60, 90, 120, 150, 180, 210, 240, 270}, -- 步兵营升级时间
    archery = {0, 30, 60, 90, 120, 150, 180, 210, 240, 270}, -- 弓兵升级时间
    stable = {0, 30, 60, 90, 120, 150, 180, 210, 240, 270}, -- 骑兵升级时间
    technology = {0, 60, 120, 180, 240, 300, 360, 420, 480, 540} -- 科技升级时间
}

--升级各个建筑所需要资源
Config.upgrade_cost = {
    ["townhall"] = { 
       [1] = {wood = 50, stone = 30, iron = 20, food = 100 }, 
        [2] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [3] = {wood = 70, stone = 50, iron = 40, food = 140 },
        [4] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [5] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [6] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [7] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [8] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [9] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [10]= {wood = 60, stone = 40, iron = 30, food = 120 }
     },
    ["Infantry"] = { 
        [1] = {wood = 50, stone = 30, iron = 20, food = 100 }, 
        [2] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [3] = {wood = 70, stone = 50, iron = 40, food = 140 },
        [4] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [5] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [6] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [7] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [8] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [9] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [10]= {wood = 60, stone = 40, iron = 30, food = 120 }
     },
    ["archery"] = { 
        [1] = {wood = 50, stone = 30, iron = 20, food = 100 }, 
        [2] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [3] = {wood = 70, stone = 50, iron = 40, food = 140 },
        [4] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [5] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [6] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [7] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [8] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [9] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [10]= {wood = 60, stone = 40, iron = 30, food = 120 }
     },
    ["stable"] =  { 
        [1] = {wood = 50, stone = 30, iron = 20, food = 100 }, 
        [2] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [3] = {wood = 70, stone = 50, iron = 40, food = 140 },
        [4] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [5] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [6] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [7] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [8] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [9] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [10]= {wood = 60, stone = 40, iron = 30, food = 120 }
     },
    ["technology"] =  { 
        [1] = {wood = 50, stone = 30, iron = 20, food = 100 }, 
        [2] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [3] = {wood = 70, stone = 50, iron = 40, food = 140 },
        [4] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [5] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [6] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [7] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [8] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [9] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [10]= {wood = 60, stone = 40, iron = 30, food = 120 }
     },
}

--士兵训练时间（秒）
Config.soldier_training_time = {
    infantry = {30, 60, 90, 120, 150,180,200,220,250,300}, -- 步兵训练时间
    archery = {30, 60, 90, 120, 150,180,200,220,250,300}, -- 弓兵训练时间
    cavalry = {60, 120, 180, 240, 300,360,400,440,500,600} -- 骑兵训练时间
}
--士兵升级训练时间（秒）
Config.soldier_upgrade_time = {
    infantry = {15, 60, 90, 120, 150,180,200,220,250,300}, -- 步兵升级训练时间
    archery = {15, 60, 90, 120, 150,180,200,220,250,300}, -- 弓兵升级训练时间
    cavalry = {15, 120, 180, 240, 300,360,400,440,500,600} -- 骑兵升级训练时间
}


--士兵各个等级生产所需要的资源
Config.soldier_production_cost = {
    ["infantry"] = {
       [1] = {wood = 50, stone = 30, iron = 20, food = 100 }, 
        [2] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [3] = {wood = 70, stone = 50, iron = 40, food = 140 },
        [4] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [5] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [6] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [7] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [8] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [9] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [10]= {wood = 60, stone = 40, iron = 30, food = 120 }
     },
    ["archery"] = {
       [1] = {wood = 50, stone = 30, iron = 20, food = 100 }, 
        [2] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [3] = {wood = 70, stone = 50, iron = 40, food = 140 },
        [4] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [5] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [6] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [7] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [8] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [9] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [10]= {wood = 60, stone = 40, iron = 30, food = 120 }
     },
    ["cavalry"] = {
       [1] = {wood = 50, stone = 30, iron = 20, food = 100 }, 
        [2] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [3] = {wood = 70, stone = 50, iron = 40, food = 140 },
        [4] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [5] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [6] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [7] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [8] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [9] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [10]= {wood = 60, stone = 40, iron = 30, food = 120 }
     },
}

--士兵升级所需资源（相对上一级）
Config.soldier_upgrade_cost = {
    ["infantry"] = { 
        [1] = {wood = 50, stone = 30, iron = 20, food = 100 }, 
        [2] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [3] = {wood = 70, stone = 50, iron = 40, food = 140 },
        [4] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [5] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [6] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [7] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [8] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [9] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [10]= {wood = 60, stone = 40, iron = 30, food = 120 }
     },
    ["archery"] = { 
        [1] = {wood = 50, stone = 30, iron = 20, food = 100 }, 
        [2] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [3] = {wood = 70, stone = 50, iron = 40, food = 140 },
        [4] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [5] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [6] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [7] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [8] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [9] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [10]= {wood = 60, stone = 40, iron = 30, food = 120 }
     },
    ["cavalry"] = {
        [1] = {wood = 50, stone = 30, iron = 20, food = 100 }, 
        [2] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [3] = {wood = 70, stone = 50, iron = 40, food = 140 },
        [4] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [5] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [6] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [7] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [8] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [9] = {wood = 60, stone = 40, iron = 30, food = 120 },
        [10]= {wood = 60, stone = 40, iron = 30, food = 120 }
     },
}



return Config
