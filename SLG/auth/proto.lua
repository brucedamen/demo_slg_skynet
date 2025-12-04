local sprotoparser = require "sprotoparser"

local proto = {}

proto.c2s = sprotoparser.parse [[
.package {
	type 0 : integer
	session 1 : integer
}


handshake 1 {
	response {
		msg 0  : string
	}
}

quit 2 {}

login 3 {
	request {
		user 0 : string
		password 1 : string
		device_id 2 : string
	}
	response {
		success 0 : integer
		token 1 : string
		message 2 : string
	}
}

get_game_token 4 {
	request {
		token 0 : string
		device_id 1 : string
		game_id 2 : integer
	}
	response {
		success 0 : integer
		token 1 : string
		message 2 : string
	}
}
]]

proto.s2c = sprotoparser.parse [[
.package {
	type 0 : integer
	session 1 : integer
}


heartbeat 1 {}



]]

return proto
