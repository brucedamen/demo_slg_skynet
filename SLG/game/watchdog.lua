local skynet = require "skynet"
local sproto = require "sproto"
local sprotoloader = require "sprotoloader"


local CMD = {}
local SOCKET = {}
local gate
local agent = {}




function SOCKET.open(fd, addr)
	skynet.error("New client from : " .. addr)
	agent[fd] = skynet.newservice("agent")
	skynet.call(agent[fd], "lua", "start", { gate = gate, client = fd, watchdog = skynet.self() })
end

local function close_agent(fd)
	local a = agent[fd]
	agent[fd] = nil
	if a then
		skynet.call(gate, "lua", "kick", fd)
		-- disconnect never return
		skynet.send(a, "lua", "disconnect")
	end
end

function SOCKET.close(fd)
	print("socket close",fd)
	close_agent(fd)
end

function SOCKET.error(fd, msg)
	print("socket error",fd, msg)
	close_agent(fd)
end

function SOCKET.warning(fd, size)
	-- size K bytes havn't send out in fd
	print("socket warning", fd, size)
end

function SOCKET.data(fd, msg)
	-- 正常不会走这里，除非在第一个消息包没有回应完成的情况下继续发消息过来
	print("socket data", fd, msg)
end

function CMD.start(conf)
	return skynet.call(gate, "lua", "open" , conf)
end

function CMD.close(fd)
	close_agent(fd)
end


function CMD.rebind(fd, newservice)
	local a = agent[fd]
	agent[fd] = newservice
	-- forward the new fd
	skynet.call(gate, "lua", "forward", fd, newservice)
	skynet.send(a, "lua", "disconnect")
end

skynet.start(function()
	
	skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
		if cmd == "socket" then
			local f = SOCKET[subcmd]
			if f then
				f(...)-- socket api don't need return
			end
		else
			local f = assert(CMD[cmd])
			skynet.ret(skynet.pack(f(subcmd, ...)))
		end
	end)

	gate = skynet.newservice("gate")
end)
