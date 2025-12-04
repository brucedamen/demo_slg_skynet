local skynet = require "skynet"
local socket = require "skynet.socket"
local sproto = require "sproto"
local sprotoloader = require "sprotoloader"
local datacenter = require "skynet.datacenter"


--登录服务
local LOGIN

--鉴权服务
local AUTH

--当前连接的区域
local region = "default"


local WATCHDOG
local host
local send_request




local CMD = {}
local REQUEST = {}
local client_fd


--从IP获取地理位置
local function get_ip_region(ip)
	--这里简单返回一个默认区域，实际应用中可以调用第三方IP库或者服务
	return "default"
end


local function request(name, args, response)
	print("REQUEST name is", name)
	local f = assert(REQUEST[name])
	local r = f(args)
	if response then
		for k,v in pairs(r) do
			print("response k,v", k,v)
		end
		return response(r)
	end
end

local function send_package(pack)
	local package = string.pack(">s2", pack)
	socket.write(client_fd, package)
end





function REQUEST:handshake()
	return { msg = "Welcome to skynet, I will send heartbeat every 5 sec." }
end

function REQUEST:quit()
	skynet.call(WATCHDOG, "lua", "close", client_fd)
end

--登录 返回token
function REQUEST:login()
	print("login---------", self.user, self.password)
	-- 这里需要验证用户信息 如果成功，绑定用户token 机器码 IP区域（目前简化，只单纯记录IP）等信息 以方便后续更换临时token 用于短期登录游戏
	local device_id = self.device_id or "unknown"
	return skynet.call(LOGIN, "lua", "login", self.user, self.password, region, device_id)
end


--登出
function REQUEST:logout()
	print("logout---------", self.token)
	--调用鉴权服务，销毁该用户的长期token
	return skynet.call(AUTH, "lua", "logout", self.user, self.token)
end

--获取游戏token  这里会验证token是否合法,分配游戏服务器，返回该游戏的token
function REQUEST:get_game_token()
	print("get_game_token---------by access_token：", self.token)
	--使用长期token验证用户信息 如果成功，鉴权服务创建游戏token,并返回
	local device_id = self.device_id or "unknown"
	local game_token = skynet.call(AUTH, "lua", "issue_short_token", self.token, region, device_id, self.game_id)
	if not game_token then
		return { success = 0, message = "Invalid token" }
	end



	--测试发送数据更新请求
	--send_package( send_request( "data_update" , {power = 999} ) )


	print("get_game_token success:", game_token)
	return { success = 1, token = game_token }
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
			error "This example doesn't support request client"
		end
	end
}

function CMD.start(conf)
	local fd = conf.client
	local gate = conf.gate
	WATCHDOG = conf.watchdog
	region = get_ip_region(conf.address)

	AUTH = datacenter.get("auth")
	LOGIN = datacenter.get("login")

	-- slot 1,2 set at main.lua
	host = sprotoloader.load(1):host "package"
	send_request = host:attach(sprotoloader.load(2))
	skynet.fork(function()
		while true do
			send_package(send_request "heartbeat")

			

			skynet.sleep(500)
		end
	end)

	client_fd = fd
	skynet.call(gate, "lua", "forward", fd)
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
