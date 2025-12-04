local skynet = require "skynet"
local socket = require "skynet.socket"
local sproto = require "sproto"
local sprotoloader = require "sprotoloader"
local datacenter = require "skynet.datacenter"





local WATCHDOG
local host
local send_request

local CMD = {}
local REQUEST = {}
local client_fd
local gate



function REQUEST:handshake()
	return { msg = "Welcome to skynet, I will send heartbeat every 5 sec." }
end

function REQUEST:quit()
	skynet.call(WATCHDOG, "lua", "close", client_fd)
end

--登录游戏  
function REQUEST:login_game()
	--校验下登录信息
	if not self.user_id or not self.token or not self.machine_id then
		return { success = false, message = "Invalid login parameters" }
	end

	--让gamelogin服务 处理登录请求
	local ok = skynet.call(datacenter.get("gamelogin"), "lua", "login", self.user_id, self.token, self.machine_id, skynet.self())
	if not ok then
		return {success = false,  message = "Failed to login, token invalid" }
	end

	--登录成功，向citymanager注册玩家在线状态和获取城市服务
	city = skynet.call(datacenter.get("city_manager"), "lua", "get_city_service", self.user_id)

	if not city then
		city = skynet.call(datacenter.get("city_manager"), "lua", "create_city_service", self.user_id)
	end

	-- 通知city服务玩家上线
	skynet.call(city, "lua", "player_login", {fd = client_fd, gate = gate, watchdog = WATCHDOG} )

	return { success = true }

end


-- rquest任务
local function request(name, args, response)
	local f = assert(REQUEST[name])
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



function CMD.start(conf)
	print("game_agent start")
	local fd = conf.client
	gate = conf.gate
	WATCHDOG = conf.watchdog
	-- slot 1,2 set at main.lua
	host = sprotoloader.load(1):host "package"
	send_request = host:attach(sprotoloader.load(2))
	--skynet.fork(function()
	--	while true do
	--		send_package(send_request "heartbeat")
	--		skynet.sleep(500)
	--	end
	--end)

	client_fd = fd
	skynet.call(gate, "lua", "forward", fd)
end

function CMD.kick()
	skynet.call(WATCHDOG, "lua", "close", client_fd)
end


function CMD.disconnect()
	-- todo: do something before exit
	skynet.exit()
end




skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		skynet.trace()
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
