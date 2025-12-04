local skynet = require "skynet"
local sprotoloader = require "sprotoloader"
local datacenter = require "datacenter"

local max_client = 6400


skynet.start(function()
	skynet.error("Server start ---game")
	--启动协议服务
	skynet.uniqueservice("protoloader")
	if not skynet.getenv "daemon" then
		local console = skynet.newservice("console")
	end

	--启动调试服务
	skynet.newservice("debug_console",8001)

	--启动ID生成服务
	local id_service = skynet.uniqueservice("id_service")
	assert(id_service)
	datacenter.set("id_service", id_service)

	--启动数据库服务
	local mysql = skynet.newservice("db_mysql")
	assert(mysql)
	datacenter.set("mysql_db", mysql)
	skynet.error("MySQL service started")

	--启动世界服务
	local world = skynet.newservice("world_service")
	assert(world)
	--把服务句柄放到datacenter中，方便全局访问
	datacenter.set("world_service", world)


	--启动城市管理服务
	local city_manager = skynet.newservice("city_manager")
	assert(city_manager)
	datacenter.set("city_manager", city_manager)
	skynet.error("City manager service started")

	-- 奖励发放服务
	local reward_service = skynet.newservice("reward_service")
	assert(reward_service)
	datacenter.set("reward_service", reward_service)
	skynet.error("Reward service started")

	--启动联盟服务
	local alliance = skynet.newservice("alliance_service")
	assert(alliance)
	skynet.call(alliance, "lua", "start", {})
	datacenter.set("alliance_service", alliance)
	skynet.error("Alliance service started")

	--启动怪物服务
	local monster = skynet.newservice("monster")
	assert(monster)
	skynet.call(monster, "lua", "start", {})
	datacenter.set("monster_service", monster)
	skynet.error("Monster service started")

	--启动战斗服务
	local battle = skynet.newservice("battle_service")
	assert(battle)
	datacenter.set("battle_service", battle)
	skynet.error("Battle service started")

	--启动资源服务
	local collection = skynet.newservice("collection_service")
	assert(collection)
	datacenter.set("collection_service", collection)
	skynet.error("Collection service started")


	--初始化玩家城市数据
	skynet.call(city_manager, "lua", "start", server_id)

	--启动游戏登录服务
	local login = skynet.newservice("game_login")
	assert(login)
	datacenter.set("game_login", login)

	--启动网关服务
	local watchdog = skynet.newservice("watchdog")
	local addr,port = skynet.call(watchdog, "lua", "start", {
		port = 8889,
		maxclient = max_client,
		nodelay = true,
	})
	skynet.error("Watchdog listen on " .. addr .. ":" .. port)
	skynet.exit()
end)
