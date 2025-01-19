-- Ported functionality specific to the Communications Bot. --

local http = require("coro-http")
local query = require("querystring")

local charset = {} -- [0-9a-zA-Z]
for c = 48, 57 do table.insert(charset, string.char(c)) end
for c = 65, 90 do table.insert(charset, string.char(c)) end
for c = 97, 122 do table.insert(charset, string.char(c)) end


return function(lua_env)
	setfenv(1, lua_env) -- Connects the main environment from botmain.lua into this file.

	activated = true
	webhook_name = getVar("WEBHOOK_NAME")
	server_url = getVar("SERVER_URL")

	filterAsync = function(string)
		local base_url = "https://www.purgomalum.com/service/plain?text="
		local ran, filtered = pcall(function()
			local _, body = http.request("GET", base_url .. query.urlencode(string))
			return body
		end)
		return ran and filtered or "[Filter Error]"
	end

	randomString = function(length)
		if not length or length <= 0 then length = 5 end
		math.randomseed(os.clock()^5)
		local stringz = ""
		for _ = 1, length do
			stringz = stringz .. charset[math.random(1, #charset)]
		end
		return stringz
	end

	client:on("ready", function()
		channels.communications = client:getChannel(getVar("COMMUNICATIONS_CHANNEL")) or client:getChannel(getVar("MAIN_CHANNEL"))
		if server and channels.communications then
			server:init() -- Initalize the webserver.
			local webhook = getWebhook(channels.communications, webhook_name) or channels.communications:createWebhook(webhook_name)
			server.webhook = "https://discordapp.com/api/webhooks/" .. webhook.id .. "/" .. webhook.token
		end
		output(log_levels.INFO, "***{!} The Communications module has been activated {!}***")
	end)

	client:on("messageCreate", function(message)
		if message.author.id == client.user.id or message.author.bot == true or message.author.discriminator == 0000 then return end
		if string.sub(string.lower(message.content), 1, string.len(prefix)) == prefix then return end
		if activated and message.channel.id == channels.communications.id then
			if whitelist_only and not (checkList(admins, message.author.id) or checkList(whitelisted, message.author.id)) then
				return
			elseif checkList(blacklisted, message.author.id) then
				return
			end
			local username = filterAsync(message.member.name)
			local content = filterAsync(message.content)
			local level = getLevel(message.author.id)
			if string.lower(string.sub(message.content, 1, 3)) == "/e " then
				message:delete()
			end
			--postAsync(server_url, {username = username, content = content, level = level, id = randomString(7)})
			server.content = {username = username, content = content, level = level, id = randomString(7)}
		end
	end)
end;
