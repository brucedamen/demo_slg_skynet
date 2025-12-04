local skynet = require "skynet"
local handler = require "handler"


local REQUEST = {}
local CMD = {}
local user
handler = handler.new (REQUEST, nil, CMD)

handler:init (function (u)
	user = u
end)


--邮件相关请求处理
function REQUEST.mail_query(args)
    --查询邮件列表
    CMD.check_expired_mails()
    local mails = {}
    for id, mail in pairs(user.mails) do
        table.insert(mails, mail)
    end
    return { success = true, mails = mails }
end



--删除邮件
function REQUEST.mail_delete(args)
    if not args.mail_id then
        return { success = false, error = "invalid_arguments" }
    end

    local mail = assert(user.mails[args.mail_id])

    --附件未领取不可删除
    if mail.attachment and not mail.attachment_claimed then
        return { success = false, error = "attachment_not_claimed" }
    end

    --删除邮件
    user.mails[args.mail_id] = nil
    return { success = true }
end


--领取邮件附件
function REQUEST.mail_claim_attachment(args)
    if not args.mail_id then
        return { success = false, error = "invalid_arguments" }
    end

    local mail = assert(user.mails[args.mail_id])
    if not mail.attachment then
        return { success = false, error = "no_attachment" }
    end
    if mail.attachment_claimed then
        return { success = false, error = "attachment_already_claimed" }
    end

    --发放附件奖励
    if mail.attachment.resources then
        user.CMD.add_resources( mail.attachment.resources )
    end
    for item_id, count in pairs(mail.attachment.items or {}) do
        user.CMD.add_item(item_id, count)
    end

    -- 领取附件
    mail.attachment_claimed = true
    return { success = true, attachment = mail.attachment }
end

--检查过期邮件，删除过期邮件
function CMD.check_expired_mails()
    local current_time = os.time()
    local mails_to_delete = {}
    for id, mail in pairs(user.mails) do
        if mail.expiry_time and mail.expiry_time < current_time then
            mails_to_delete[#mails_to_delete + 1] = id
        end
    end
    for _, id in ipairs(mails_to_delete) do
        user.mails[id] = nil
    end
end

--奖励发放接口
function CMD.receive_reward(rewards)
    --可以 生成 邮件，然后使用邮件领取， 这里简化直接增加资源
    --假设奖励格式为 { type = "resource", resource = { gold = 100, wood = 50 } }
    rewards = { resource = { gold = 100, wood = 50 }, item = { id = 1, amount = 2 } } -- 示例奖励数据
    if rewards.resource then
        user.CMD.add_resources(rewards.resource)
    end
    -- 处理物品奖励等其他类型奖励
    if rewards.item then
        -- 这里可以调用物品管理模块来添加物品到玩家背包
        user.CMD.add_item(rewards.item.id, rewards.item.amount)
    end
    return true
end


--邮件添加接口
function CMD.add_mail(mail)
    --生成唯一邮件ID
    local mail_id = skynet.call(user.id_service, "lua", "next_id")
    mail.id = mail_id
    mail.received_time = os.time()
    --设置过期时间，假设邮件有效期为7天
    mail.expiry_time = mail.received_time + 7 * 24 * 3600
    mail.attachment_claimed = false

    -- 具体邮件内容可以根据需求设置
    user.mails[mail_id] = mail

    --
    user.CMD.request_msg( "new_mail", { mail = mail } )
end



return handler