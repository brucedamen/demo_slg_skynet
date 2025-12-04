package.cpath = "luaclib/?.so"
package.path = "lualib/?.lua;SG_SLG/proto/?.lua"

if _VERSION ~= "Lua 5.4" then
	error "Use lua 5.4"
end

local socket = require "client.socket"
local proto = require "proto"
local sproto = require "sproto"

local host = sproto.new(proto.s2c):host "package"
local request = host:attach(sproto.new(proto.c2s))

local coder = sproto.new(proto.c2s)

local fd = assert(socket.connect("127.0.0.1", 8889))

local long_token = nil
local game_token = nil

local function send_package(fd, pack)
	local package = string.pack(">s2", pack)
	socket.send(fd, package)
end

local function unpack_package(text)
	local size = #text
	if size < 2 then
		return nil, text
	end
	local s = text:byte(1) * 256 + text:byte(2)
	if size < s+2 then
		return nil, text
	end

	return text:sub(3,2+s), text:sub(3+s)
end

local function recv_package(last)
	local result
	result, last = unpack_package(last)
	if result then
		return result, last
	end
	local r = socket.recv(fd)
	if not r then
		return nil, last
	end
	if r == "" then
		error "Server closed"
	end
	return recv_package(last .. r)
end

local session = 0

--session 发送ID获取
local function get_session()
	session = session + 1
	return session
end

local function send_request(session, name, args)
	local str = request(name, args, session)
	send_package(fd, str)
	print("Request:", session, name)
end

local last = ""
local resulthandler = {}


--处理登录返回
local function handle_login_response(args)
	if args.success == 1 and args.token then
		print("login success, long token:", args.token)
		long_token = args.token
	else
		if args.message then
			print("login failed:", args.message)
		else
			print("login failed")
		end
	end
end
--处理获取游戏token返回
local function handle_get_game_token_response(args)
	if args.success == 1 and args.token then
		print("get game token success:", args.token)
		game_token = args.token
	else
		if args.message then
			print("get game token failed:", args.message)
		else
			print("get game token failed")
		end
	end
end

--登录游戏返回
local function handle_login_game_response(args)
	if args.success then
		print("login game success:")

	else
		if args.message then
			print("login game failed:", args.message)
		else
			print("login game failed")
		end
	end
end


local function handle_get_response(args)
	for k,v in pairs(args) do
		print(k,v)
	end
end


local function print_request(name, args)
	print("REQUEST", name)
	if args then
		for k,v in pairs(args) do
			--如果是table，则打印子项
			if type(v) == "table" then
				print(" ",k)
				for k2,v2 in pairs(v) do
					if type(v2) == "table" then
						print("               ",k2)
						for k3,v3 in pairs(v2) do
							print("                  ",k3,v3)
						end
					else
						print("         ",k2,v2)
					end
				end
			else
				print(" ",k,v)
			end
		end
	end
end

local function print_response(session, args)
	print("RESPONSE", session)

	--处理分支
	if resulthandler[session] then
		resulthandler[session](args)
		resulthandler[session] = nil
	end

	--打印返回内容
	if args then
		for k,v in pairs(args) do
			if type(v) == "table" then
				print(" ",k)
				for k2,v2 in pairs(v) do
					if type(v2) == "table" then
						print("               ",k2)
						for k3,v3 in pairs(v2) do
							print("                  ",k3,v3)
						end
					else
						print("         ",k2,v2)
					end
				end
			else
				print(" ",k,v)
			end
		end
	end
end


local function print_package(t, ...)
	if t == "REQUEST" then
		print_request(...)
	else
		assert(t == "RESPONSE")
		print_response(...)
	end
end


local function test_auth()
		if(not long_token) then
			print("start login first")
			--注册登录返回处理函数
			local session_id = get_session()
			resulthandler[session_id] = handle_login_response
			--登录
			send_request(session_id, "login", { user = "testuser", password = "testpw", device_id = "machine_001" })
		end

		socket.usleep(10000)

		--测试登录和获取游戏token
		if long_token then
			print("start get game token")
			--注册获取游戏token返回处理函数
			local session_id = get_session()
			resulthandler[session_id] = handle_get_game_token_response
			send_request(session_id, "get_game_token", { token = long_token, device_id = "machine_001" })
			long_token = nil  --只测试一次登录和获取游戏token
		end

		socket.usleep(1000000)
end

local CMD = {}
function CMD.login( args )
		print("start login game")
		--注册登录游戏返回处理函数
		local session_id = get_session()
		resulthandler[session_id] = handle_login_game_response
		send_request(session_id, "login_game", { user_id = 1, token = args or game_token, device_id = "machine_001" })
		game_token = nil  --只测试一次登录游戏
end

function CMD.building_query( )
		--建筑数据
		local session_id = get_session()
		resulthandler[session_id] = handle_get_response
		send_request(session_id, "building_get", {})
end

function CMD.building_create( type )
		--创建建筑
		local session_id = get_session()
		resulthandler[session_id] = handle_get_response
		print("创建建筑:", session_id)
		send_request(session_id, "building_create", {type = type, position = {x = 0, y = 0}})
end

function CMD.building_upgrade( id )
		--升级建筑
		local session_id = get_session()
		resulthandler[session_id] = handle_get_response
		print("升级建筑:", session_id)
		send_request(session_id, "building_upgrade", {id = id})
end

function CMD.building_produce( id )
		--生产士兵
		local soldier = { type = "infantry", level = 1, quantity = 10 }
		local session_id = get_session()
		resulthandler[session_id] = handle_get_response
		print("生产士兵:", session_id)
		send_request(session_id, "building_produce", {id = id, soldier = soldier})
end

function CMD.task_query( )
		--查询任务
		local session_id = get_session()
		resulthandler[session_id] = handle_get_response
		print("查询任务:", session_id)
		send_request(session_id, "task_query", {})
end

function CMD.task_cancel(task_id)
		--取消任务
		local session_id = get_session()
		resulthandler[session_id] = handle_get_response
		print("取消任务:", session_id)
		send_request(session_id, "task_cancel", {id = task_id})
end

function CMD.formation_create( )
		--创建编队
		local soldier = { type = "infantry", level = 1, quantity = 10 }
		local session_id = get_session()
		resulthandler[session_id] = handle_get_response
		print("创建编队:", session_id)
		send_request(session_id, "formation_create", { soldier = soldier })
end

function CMD.formation_destroy( id )
		--解散编队
		local session_id = get_session()
		resulthandler[session_id] = handle_get_response
		print("解散编队:", session_id)
		send_request(session_id, "formation_destroy", { id = id })
end

function CMD.formation_query( )
		--查询编队
		local session_id = get_session()
		resulthandler[session_id] = handle_get_response
		print("查询编队:", session_id)
		send_request(session_id, "formation_query", {})
end

function CMD.technology_research( id )
		--科技研究
		local session_id = get_session()
		resulthandler[session_id] = handle_get_response
		print("科技研究:", session_id)
		send_request(session_id, "technology_research", { id = id })
end

function CMD.technology_query( )
		--查询科技
		local session_id = get_session()
		resulthandler[session_id] = handle_get_response
		print("查询科技:", session_id)
		send_request(session_id, "technology_query", {})
end


function CMD.help( )
	--显示当前可用命令
	print("Available commands:")
	print("  login [game_token]         -- login to game server")
	print("  building_query             -- query buildings")
	print("  building_create [type]     -- create building of given type")
	print("  building_upgrade [id]      -- upgrade building of given id")
	print("  building_produce [id]      -- produce soldiers in building of given id")
	print("  task_query                 -- query tasks")
	print("  task_cancel [task_id]      -- cancel task of given id")
	print("  formation_create           -- create a formation")
	print("  formation_destroy [id]     -- destroy formation of given id")
	print("  formation_query            -- query formations")
	print("  technology_research [id]   -- research technology of given id")
	print("  technology_query           -- query technologies")
	print("  help                       -- show this help message")
end


local function dispatch_package()
	while true do
		local v
		v, last = recv_package(last)
		if not v then
			break
		end
		print_package(host:dispatch(v))
	end
end



while true do
	dispatch_package()
	local cmd = socket.readstdin()
	if cmd then
		if cmd == "quit" then
			send_request(get_session(), "quit")
		else
			--分解命令和参数 空格分割
			local args = {}
			for word in cmd:gmatch("%S+") do
				table.insert(args, word)
			end
			local command = args[1]
			local f = CMD[command]
			if f then
				f(args)
			else
				print("Unknown command", cmd)
			end
		end
	end
end
