local skynet = require "skynet"
local sprotoloader = require "sprotoloader"
local datacenter = require "datacenter"

local max_client = 64

skynet.start(function()
	skynet.error("Server start")
	--启动协议服务
	skynet.uniqueservice("protoloader")
	if not skynet.getenv "daemon" then
		local console = skynet.newservice("console")
	end

	--启动数据库服务
	local mysql = skynet.newservice("db_mysql")
	assert(mysql)
	datacenter.set("mysql", mysql)
	--启动鉴权服务
	local auth = skynet.newservice("auth")
	assert(auth)
	datacenter.set("auth", auth)
	--启动登录服务
	local login = skynet.newservice("login")
	assert(login)
	datacenter.set("login", login)

	

	--启动调试服务
	skynet.newservice("debug_console",8000)
	--启动网关服务
	local watchdog = skynet.newservice("watchdog")
	local addr,port = skynet.call(watchdog, "lua", "start", {
		port = 8888,
		maxclient = max_client,
		nodelay = true,
	})
	skynet.error("Watchdog listen on " .. addr .. ":" .. port)
	skynet.exit()
end)
