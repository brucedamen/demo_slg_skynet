--任务配置
local quest_config = {

    --任务ID
    [1001] = {
        id = 1001,
        name = "初级任务",
        description = "完成初级任务，获得奖励。",
        --接受限制
        accept_conditions = {
            level = 1,
        },
        --任务目标
        mission_obj = {
            [1] = {id = 1, description = "击杀1只哥布林", type = "kill_monster", target = "goblin", level = 1, amount = 1, progress = 0},
        },
        rewards = {
            resources = { wood = 200, stone = 100 },   --资源奖励
            items = { 1, 2 },--物品ID列表
        },
    },

    [1002] = {
        id = 1002,
        name = "采集任务",
        description = "完成采集任务，获得奖励。",
        accept_conditions = {
            level = 5,
            quest_completed = {1001},--前置任务ID,可能有多个
        },
        mission_obj = {
            [1] = {id = 1, description = "采集5个木材", type = "collect", target = "wood", level = 1, amount = 5, progress = 0},--采集任务等级是冗余字段为了统一处理而设置
        },
        rewards = {
            items = { {id = 3, count = 1}, {id = 4, count = 1} },--物品ID列表
        },
    },

    [1003] = {
        id = 1003,
        name = "新手建设任务",
        description = "完成建设1级兵营和一级市政厅，获得奖励。",
        mission_obj = {
            [1] = {id = 1 ,description = "建设1级兵营", type = "building", target = "barracks", level = 1, amount = 1, progress = 0},
            [2] = {id = 2 ,description = "建设1级市政厅", type = "building", target = "townhall", level = 1, amount = 1, progress = 0},
        },
        rewards = {
            resources = { wood = 500, stone = 300 },    --资源奖励
            items = { {id = 3, count = 1}, {id = 4, count = 1} },--物品ID列表
        },
    },
    [1004] = {
        id = 1004,
        name = "生产10个一级步兵",
        description = "完成生产10个一级步兵任务，获得奖励。",
        mission_obj = {
            [1] = {id = 1, description = "生产10个一级步兵", type = "produce", target = "infantry", level = 1, amount = 10, progress = 0},
        },
        rewards = {
            resources = { wood = 0, stone = 0, iron = 300, food = 200 },    --资源奖励
            items = { {id = 3, count = 1}, {id = 4, count = 1} },--物品ID列表
        },
    },
    [1005] = {
        id = 1005,
        name = "升级科技到2级采集",
        description = "完成升级科技到2级采集任务，获得奖励。",
        mission_obj = {
            [1] = {id = 1, description = "升级采集科技到2级", type = "technology", target = 101, level = 2, amount = 1, progress = 0},--假设101是采集科技ID
        },
        rewards = {
            resources = { wood = 1000, stone = 600, iron = 300, food = 200 },    --资源奖励
            items = { {id = 3, count = 1}, {id = 4, count = 1} },--物品ID列表
        },
    },
}


return quest_config