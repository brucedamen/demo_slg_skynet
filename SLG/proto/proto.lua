local sprotoparser = require "sprotoparser"
local proto = {}

local types = [[

.package {
	type 0 : integer
	session 1 : integer
}

.soldier {
	type 0 : string
	level 1 : integer
	amount 2 : integer
}

.position {
	x 0 : integer
	y 1 : integer
}
.resource {
	food 0 : integer
	wood 1 : integer
	stone 2 : integer
	iron 3 : integer
}

.building {
	id 0 : integer
	type 1 : string
	level 2 : integer
	position 3 : position
	status 4 : string
	produce 5 : soldier
}
.formation {
	id 0 : integer
	soldiers 1 : *soldier
}
.technology {
	id 0 : integer
	level 1 : integer
}

.upgrade_task {
	building_id 0 : integer
	level 1 : integer
}
.production_task {
	building_id 0 : integer
	soldier 1 : soldier
}


.subquest {
	id 0 : integer
	status 1 : string
	progress 2 : integer
}
.quest {
	id 0 : integer
	status 1 : string
	subquest 2 : *subquest
}


.items{
	id 0 : integer
	count 1 : integer
}

.attachments {
	resource 0 : resource
	items 1 : *items
}

.mail {
	id 0 : integer
	sender 1 : string
	subject 2 : string
	content 3 : string
	attachments 4 : attachments
	sent_time 5 : integer
	read 6 : boolean
}

]]


local c2s = [[

handshake 1 {
	response {
		msg 0  : string
	}
}


quit 2 {}


login_game 3 {
	request {
		user_id 0 : integer
		token 1 : string
		device_id 2 : string
	}
	response {
		success 0 : boolean
		message 1 : string
	}
}

building_query 4 {
	response {
		success 0 : boolean
		buildings 1 : *building
	}
}

building_create 5 {
	request {
		type 0 : string
		position 1 : position
	}
	response {
		success 0 : boolean
		cost 1 : resource
		building 2 : building
	}
}
building_upgrade 6 {
	request {
		id 0 : integer
	}
	response {
		success 0 : boolean
		cost 1 : resource
		building 2 : building
	}
}

building_produce 7 {
	request {
		id 0 : integer
		soldier 1 : soldier
	}
	response {
		success 0 : boolean
		cost 1 : resource
	}
}
upgrade_cancel 8 {
	request {
		id 0 : integer
	}
	response {
		success 0 : boolean
	}
}
produce_cancel 9 {
	request {
		id 0 : integer
	}
	response {
		success 0 : boolean
	}
}


formation_query 10 {
	response {
		success 0 : boolean
		formations 1 : *formation
	}
}
formation_disband 11 {
	request {
		id 0 : integer
	}
	response {
		success 0 : boolean
	}
}

resource_query 12 {
	response {
		success 0 : boolean
		resources 1 : resource
	}
}

technology_query 14 {
	response {
		success 0 : boolean
		technologies 1 : *technology
	}
}
technology_research 15 {
	request {
		id 0 : integer
	}
	response {
		success 0 : boolean
	}
}
technology_cancel 16 {
	request {
		id 0 : integer
	}
	response {
		success 0 : boolean
	}
}

quest_query 17 {
	response {
		success 0 : boolean
		quests 1 : *quest
	}
}

quest_complete 18 {
	request {
		id 0 : integer
	}
	response {
		success 0 : boolean
	}
}

mail_query 19 {
	response {
		success 0 : boolean
		mails 1 : *mail
	}
}
mail_delete 20 {
	request {
		mail_id 0 : integer
	}
	response {
		success 0 : boolean
		error 1 : string
	}
}
mail_claim_attachment 21 {
	request {
		mail_id 0 : integer
	}
	response {
		success 0 : boolean
		error 1 : string
	}
}


]]

local s2c =  [[
heartbeat 1 {}

resource_update 2 {
	request {
		update 0 : resource
	}
}
soldier_update 3 {
	request {
		soldiers 0 : *soldier
	}
}


task_update 4 {
	request {
		id 0 : integer
	}
}

task_complete 5 {
	request {
		id 0 : integer
	}
}

task_building 6 {
	request {
		building 0 : building
	}
}




]]

proto.types = sprotoparser.parse (types)
proto.c2s = sprotoparser.parse (types .. c2s)
proto.s2c = sprotoparser.parse (types .. s2c)

return proto
