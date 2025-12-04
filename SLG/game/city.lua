local skynet = require "skynet"

local sprotoloader = require "sprotoloader"
local datacenter = require "datacenter"
local socket = require "skynet.socket"



local host = sprotoloader.load(1):host "package"
local request = host:attach(sprotoloader.load(2))


local building_handler = require "building_handler"
local item_handler = require "item_handler"
local resource_handler = require "resource_handler"
local task_handler = require "task_handler"
local alliance_handler = require "alliance_handler"
local formation_handler = require "formation_handler"
local technology_handler = require "technology_handler"
local chat_handler = require "chat_handler"
local hero_handler = require "hero_handler"
local mail_handler = require "mail_handler"


local CMD = {}
local REQUEST = {}
local RESPONSE = {}
local user = {}


local world = nil
local client_fd = nil

local WATCHDOG
local host
local send_request





-- 开始
function CMD.start()
    --世界服务器注册
    local world_data = {
        name = user.name,
        type = "city",
        id = user.id,
        level = user.level,

        alliance_id = user.alliance_id,
        city_skin_id = user.city_skin_id,
        defends = {}
    }
    if( user.position)then --这里时新建城市和旧城市注册的区别，新城市需要世界服务器分配位置，所以不能带入坐标
        world_data.x = user.position.x
        world_data.y = user.position.y
    end

    
    skynet.call(world, "lua", "register_entity", world_data)

    -- 启动各类监听
    if( user.alliance_id ~= nil )then
        --把服务句柄放到 联盟服务中，分辨通知玩家联盟消息
        local alliance_service = datacenter.get("alliance_service")
        skynet.send( alliance_service, "lua", "player_login", user.id, skynet.self())
    end

    
    return true
end



--city服务初始化
function CMD.initialize_city(data)
    print("Initializing city for user", data.id, data.name)


    user.id = data.id
    user.level = data.level
    user.name = data.name
    user.alliance_id = data.alliance_id or nil
    user.city_skin_id = data.city_skin_id or 1
    user.position = data.position or nil
    user.buildings = data.buildings or {}
    user.items = data.items or {}
    user.resources = data.resources or {}
    user.tasks = data.tasks or {}
    user.technologies = data.technologies or {}
    user.heroes = data.heroes or {}
    user.soldiers = data.soldiers or {}

    
    user.REQUEST = {}
    user.RESPONSE = {}
    user.CMD = {}

    --各类处理函数
    building_handler:register(user)
    item_handler:register(user)
    resource_handler:register(user)
    task_handler:register(user)
    alliance_handler:register(user)
    formation_handler:register(user)
    technology_handler:register(user)
    chat_handler:register(user)
    hero_handler:register(user)
    mail_handler:register(user)


    -- 协议初始化
    host = sprotoloader.load(1):host "package"
	send_request = host:attach(sprotoloader.load(2))


    user.CMD.start()
end



-- 载入士兵数据
function CMD.load_soldiers(soldier_list)
    user.soldiers = soldier_list or {}
    return true
end


-- login_game
function CMD.player_login( conf )
    if client_fd ~= nil then
        -- 重复登录
        skynet.call(conf.watchdog, "lua", "close", client_fd)
    end
    client_fd = conf.fd
    gate = conf.gate
    WATCHDOG = conf.watchdog
    print("Player", user.id, "logged in to city service.")
    
    skynet.call(WATCHDOG, "lua", "rebind", client_fd, skynet.self())
    skynet.call(gate, "lua", "forward", client_fd)


    --通知联盟服务 玩家上线
    if( user.alliance_id ~= nil )then
        local alliance_service = datacenter.get("alliance_service")
        skynet.send( alliance_service, "lua", "player_login", user.id)
    end

    return true
end


-- 发送消息给用户
function CMD.send_msg(event, msg)
    if not client_fd then
        return
    end
    send_package( send_request(event, msg) )
end

-- rquest任务
local function request(name, args, response)
	local f = assert(user.REQUEST[name]) 
	local r = f(args)
	if response then
		return response(r)
	end
end
-- 发送数据包给客户端
local function send_package(pack)
	local package = string.pack(">s2", pack)
	socket.write(client_fd, package)
end



-- 玩家断线处理
function CMD.disconnect()
	-- todo: do something before exit
	-- city服务只有在特殊情况下才会退出，这里只是状态改变
    print("City service for user", user.id, "is disconnecting.")
    client_fd = nil

    --通知联盟服务 玩家下线
    if( user.alliance_id ~= nil )then
        local alliance_service = datacenter.get("alliance_service")
        skynet.call( alliance_service, "lua", "player_logout", user.alliance_id, user.id)
    end
end


-- 城市服务退出(一般终身服务，不会退出，除非特殊情况，比如创建后初始化失败
function CMD.exit()
    -- 清理工作
    print("City service for user", user.id, "is exiting.")

end

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg, sz)
		return host:dispatch(msg, sz)
	end,
	dispatch = function (fd, _, type, ...)
		assert(fd == client_fd)	-- You can use fd to reply message
		skynet.ignoreret()	-- session is fd, don't call skynet.ret
		skynet.trace()
		if type == "REQUEST" then
			local ok, result  = pcall(request, ...)
			if ok then
				if result then
					send_package(result)
				end
			else
				skynet.error(result)
			end
		else 
			assert(type == "RESPONSE")
			skynet.error "This example doesn't support request client"
		end
	end
}


skynet.start(function()
    world = datacenter.get("world_service")
    skynet.dispatch("lua", function(session, address, cmd, ...)
        print("city receive cmd:", cmd)
        if cmd == "REQUEST" then
            local name, args = ...
            local f = user.REQUEST[name]
            if f then
                skynet.ret(skynet.pack(f(args)))
            else
                skynet.error(string.format("city Unknown REQUEST %s", tostring(name)))
            end
        else
            local f = CMD[cmd]
            if f then
                skynet.ret(skynet.pack(f(...)))
            else
                skynet.error(string.format("city Unknown command %s", tostring(cmd)))
            end
        end
	end)
end)



