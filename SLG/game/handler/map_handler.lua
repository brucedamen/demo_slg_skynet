local skynet = require "skynet"
local handler = require "handler"
local block = require "block"
local datacenter = require "skynet.datacenter"
local mapconfig = require "config_map"

local REQUEST = {}
local CMD = {}
local user
handler = handler.new (REQUEST, nil, CMD)


local world_service = nil
local subscribe = nil

handler:init (function (u)
	user = u
    world_service = datacenter.get("world_service")
    subscribe = datacenter.get("subscribe")
	block:init( mapconfig )
end)






-- 查看地图信息
function REQUEST:view_map(args)
	-- 检查参数
	if not args.x or not args.y then
		return { success = false, error = "invalid_parameters" }
	end

	--订阅区域信息
	local block_list  = block:get_block_id_list(args.x, args.y)

	skynet.call( subscribe, "lua", "unsubscribe", user.agent, user.current_view_blocks )
	skynet.call( subscribe, "lua", "subscription", user.agent, block_list )

	-- 与旧列表比对 获取新增加的区域列表(防止重复请求)
	local new_list = {}
	for _, block_id in ipairs(user.current_view_blocks or {}) do
		local found = false
		for _, new_block_id in ipairs(block_list) do
			if block_id == new_block_id then
				found = true
				break
			end
		end
		if not found then
			new_list[#new_list + 1] = block_id
		end
	end
	--保存当前查看的区域列表
	user.current_view_blocks = block_list

	--向世界服务器查询新增节点信息
	local map_info = skynet.call(world_service, "lua", "get_blocks_info", new_list)
	

	return { success = true, {entity_info = map_info} }
end

-- 查询编队信息 地图移动的编队全部显示
function REQUEST:query_formation()
	local formation_info  = skynet.call(world_service, "lua", "get_formation_info")
	return { success = true, formation_info = formation_info }
end

-- 退出地图查看
function REQUEST:exit_map(args)
	-- 移除观察者
	skynet.call( subscribe, "lua", "clear_viewer", user.agent)
	user.current_view_blocks = nil
end