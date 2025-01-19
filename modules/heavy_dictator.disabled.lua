-- Ported functionality specific to Heavy Dictator. --


return function(lua_env)
	setfenv(1, lua_env) -- Connects the main environment from botmain.lua into this file.

	status_list = {}

	client:on("ready", function()
		channels.broadcast = client:getChannel(getVar("BROADCAST_CHANNEL")) or client:getChannel(getVar("MAIN_CHANNEL"))
		channels.destination = client:getChannel(getVar("DESTINATION_CHANNEL"))
		if datastore then
			datastore:init() -- Initalize our database module.
			if datastore.active then
				if message then
					message:setContent(message.content .. "\n***Initializing database sync.. (Retrieving data from database)***")
				end
				datastore:sync() -- Build our data cache by calling the sync function.
			end
		end
		output(log_levels.INFO, "*** {!} The Heavy Dictator module has been started. Gulag Mode is enabled. {!} ***")
	end)

	client:on("messageCreate", function(message)
		if message.author.id == client.user.id or message.author.bot == true or message.author.discriminator == 0000 then return end
		if string.sub(string.lower(message.content), 1, string.len(prefix)) == prefix then return end
		local allowed = not whitelist_only
		for _, id in pairs(whitelisted) do
			if message.author.id == id then
				allowed = true
			end
		end
		for _, id in pairs(blacklisted) do
			if message.author.id == id then
				allowed = false
			end
		end
		for _, id in pairs(admins) do
			if message.author.id == id then
				allowed = true
			end
		end
		if channels.broadcast and channels.destination and message.channel.id == channels.broadcast.id and allowed then
			if message.attachment then
				channels.destination:send{content = message.content, embed = {image = {url = message.attachment.url}}}
			else
				channels.destination:send(message.content)
			end
		end
	end)

	waitForNextMessage = function(message)
		local author = message.author.id
		local channel = message.channel.id
		local returned
		repeat
			local _, newmsg = client:waitFor("messageCreate")
			if newmsg.author.id == author and newmsg.channel.id == channel then
				returned = newmsg
			end
		until returned ~= nil
		return returned
	end

	dataCheck = function(id, datatype)
		local returns = datastore.cache[id]
		if returns ~= nil then
			return returns
		elseif datatype ~= nil then
			return datastore:save(id, {}, datatype)
		else
			output(log_levels.WARN, "Attempt to data-check a new ID without providing a datatype!")
			return false
		end
	end

	getBalance = function(userId)
		local data = dataCheck(userId, "userdata")
		if data ~= nil then
			return data.balance
		else
			return 0
		end
	end

	addBalance = function(userId, amount)
		local data = dataCheck(userId, "userdata")
		datastore:save(userId, {balance = data.balance + amount})
	end

	coalOperation = function(serverId)
		local data = dataCheck(serverId, "serverdata")
		status_list[serverId] = {
			reached = false,
			workers = {},
			coal = 0,
			goal = math.random(data.mingoal, data.maxgoal)
		}
	end

	isCoalMine = function(message)
		local data = dataCheck(message.guild.id, "serverdata")
		if message.channel.id == data.coalmine then
			return true
		elseif data.coalmine ~= "" then
			message:reply("Invalid channel! Go-to: <#" .. tostring(data.coalmine) .. ">.")
			message:addReaction("❌")
			return false
		else
			message:reply("No coalmine channel has been set on this server yet!")
			message:addReaction("❌")
			return false
		end
	end

	getCoal = function(message)
		local data = status_list[message.guild.id]
		if data ~= nil then
			local worker = data.workers[message.author.id]
			if worker ~= nil then
				return worker.mined
			else
				return 0
			end
		else
			output(log_levels.WARN, "Attempt to GET coal value from a non-initalized server!")
			return 0
		end
	end

	addCoal = function(message, amount)
		local data = status_list[message.guild.id]
		if data ~= nil then
			local worker = data.workers[message.author.id]
			if worker ~= nil then
				worker.mined = worker.mined + amount
			else
				data.workers[message.author.id] = {
					mined = amount,
					paid = false
				}
			end
		else
			output(log_levels.WARN, "Attempt to ADD coal value from a non-initalized server!")
		end
	end
end;
