-- Initializes all database-related functions and variables. --
-- (This script was ported from Heavy Dictator)
-- TODO: Deprecate old data saving method in favor of JSON-based saving

local json = require("json")

local function markPin(channel)
	channel:send("-------------------- (100 Messages)"):pin()
	channel:getMessages(1):toArray()[1]:delete() -- Yes I know, this looks hacky.. (It's to remove the message that's created when you pin a new message)
end


return function(ENV)
	setfenv(1, ENV) -- Connects the main environment from botmain.lua into this file.

	local data_table = {}
	data_channel = getVar("DATA_CHANNEL")
	datastore = data_table -- Loads in the botdata module into the main environment.

	function data_table:init()
		self.data_channel = client:getChannel(data_channel) -- Converts our channel ID from data_channel into a GuildTextChannel object.
		self.active = (self.data_channel ~= nil) -- Whether or not we can save persistent data.
		self.synced = false -- Whether or not our cache is ready yet.
		self.cache = {} -- Our local table of data for the bot to quickly reference from.
		self.msg_pairs = {} -- A table of user/server IDs linked to their corresponding message IDs in the persistent data channel.
		self.metadata = { -- A table of ID lists for organizing our different types of data.
			["userdata"] = {};
			["serverdata"] = {};
		}

		self.order = {
			["userdata"] = {"type", "id", "name", "balance", "mined", "equipped", "inventory"};
			["serverdata"] = {"type", "id", "name", "coalmine", "paytype", "mingoal", "maxgoal", "minpay", "maxpay", "usrate", "ctrate", "gtrate"};
		}

		self.userdata = { -- Template
			["type"] = "userdata",
			["id"] = "",
			["name"] = "",
			["balance"] = 0,
			["mined"] = 0,
			["equipped"] = "default",
			["inventory"] = {}
		}

		self.serverdata = { -- Template
			["type"] = "serverdata",
			["id"] = "",
			["name"] = "",
			["coalmine"] = "",
			["paytype"] = "ratio", -- random, ratio, static
			["mingoal"] = 100,
			["maxgoal"] = 300,
			["minpay"] = 750, -- Used only if the paytype == "random" (minimum random value)
			["maxpay"] = 1000, -- Used only if the paytype == "random" (maximum random value)
			["usrate"] = (967/62500), -- Converting RUB into USD
			["ctrate"] = 8, -- Used only if the paytype == "ratio" (coal to RUB ratio)
			["gtrate"] = 4 -- Used only if the paytype == "static" (statically based on goal amount)
		}
	end

	function data_table:sync()
		if self.active == false or self.synced == true then return end
		output(log_levels.INFO, "[DATA] Initializing database sync.. (Retrieving data from the database)")
		local pin_pool = self.data_channel:getPinnedMessages()
		if #pin_pool == 0 then
			markPin(self.data_channel)
		else
			for _, pin in pairs(pin_pool) do
				local msg_pool = self.data_channel:getMessagesAfter(pin.id, 100)
				output(log_levels.DEBUG, "[DATA] Loading " .. tostring(#msg_pool) .. " stored datatables into cache.")
				for _, msg in pairs(msg_pool) do
					if msg.author.id == client.user.id then
						local decoded = json.decode(msg.content:gsub("```json\n", ""):gsub("```",""))
						if type(decoded) == "table" and decoded.id ~= nil and decoded.type ~= nil then
							output(log_levels.DEBUG, "[DATA] Loading data of " .. tostring(decoded.id) .. ".")
							decoded = self:serialize(decoded, self[decoded.type])
							self.cache[decoded.id] = decoded
							self.msg_pairs[decoded.id] = msg.id
							self.metadata[decoded.type][decoded.id] = true
						end
					end
				end
			end
		end
		self.synced = true
	end

	function data_table:serialize(main, base) -- If new values are ever added, this serialize function will add them to our currently existing datatables.
		assert(type(main) == "table", "Inputted data is either invalid or malformed!")
		local template = {}
		for i,v in pairs(base) do
			template[i] = v
		end
		for key, value in pairs(main) do
			template[key] = value
		end
		return template
	end

	function data_table:getName(id, datatype) -- Retrieves the name of a guild or user from the given ID and datatype.
		if type(id) == "number" then id = tostring(id) end
		assert(type(id) == "string", "An invalid ID was provided!")
		assert(type(datatype) == "string", "DataType is nil! A datatype must be provided when retrieving the name of a given ID.")
		if datatype == "userdata" then
			local user = client:getUser(id)
			if user ~= nil then
				return user.name .. "#" .. tostring(user.discriminator)
			else
				output(log_levels.DEBUG, "[DATA-WARN] Attempt to data-check the ID of a nonexistant USER!")
				return nil
			end
		elseif datatype == "serverdata" then
			local guild = client:getGuild(id)
			if guild ~= nil then
				return guild.name
			else
				output(log_levels.DEBUG, "[DATA-WARN] Attempt to data-check the ID of a nonexistant GUILD!")
				return nil
			end
		end
	end

	function data_table:encode(data, datatype) -- Decided to make my own JSON encode function because the order of keys isn't persistent in the native function.
		assert(type(data) == "table", "Inputted data is either invalid or malformed!")
		if datatype == nil then output(log_levels.DEBUG, "[DATA-WARN] In encode function: Passed datatype is nil or invalid! Resorting to 'userdata' to encode data.") end
		local ordered = self.order[datatype] or self.order["userdata"]
		local encoded = "{\n"
		for _, key in pairs(ordered) do
			if data[key] ~= nil then
				local value = data[key]
				if type(value) == "string" then
					value = "\"" .. value .. "\""
				elseif type(value) == "number" then
					value = value
				elseif type(value) == "table" then
					value = json.encode(value) -- Use native function since order of regular arrays doesn't matter
				end
				encoded = encoded .. "	\"" .. tostring(key) .. "\": " .. tostring(value) .. ",\n"
			end
		end
		return encoded .. "}"
	end

	function data_table:save(id, data, datatype) -- Writes new data into our cache, and into our datastores.
		-- TODO: catch error if msg_pairs[id] == nil
		-- (If for whatever reason, a data message gets deleted out of the blue, create a new one based on the existing data stored in the local cache)
		if not self.synced then output(log_levels.DEBUG, "[DATA-WARN] Data syncing is currently not avaliable! Please make sure your DATA_CHANNEL variable is correctly set-up!") return false end
		if type(id) == "number" then id = tostring(id) end
		assert(type(id) == "string", "An invalid ID was provided!")
		assert(type(data) == "table", "Inputted data is either invalid or malformed!")
		datatype = datatype or data.type
		local old = self.cache[id]
		if old ~= nil then
			data = self:serialize(data, old)
			datatype = datatype or old.type
		end
		assert(type(datatype) == "string", "DataType is nil! A datatype must be provided when constructing a new data entry.")
		data = self:serialize(data, self[datatype])
		data.id = id
		data.name = self:getName(id, datatype)
		self.cache[id] = data
		local encoded = self:encode(data, datatype)--:gsub(",", ",\n	"):gsub("{","{\n	"):gsub("}","\n}")
		local message = self.msg_pairs[id]
		if message ~= nil then
			message = self.data_channel:getMessage(message)
			if message ~= nil and message.author.id == client.user.id then
				message:setContent("```json\n" .. encoded .. "\n```") -- Since data already exists for this ID, simply overwrite it
			else
				output(log_levels.DEBUG, "[DATA-WARN] Attempt to locate data ID: " .. tostring(id) .. " - msg_pairs ID is invalid or does not exist!")
			end
		else
			message = self.data_channel:send{content = encoded, code = "json"} -- Create new data for our unique ID
			if message ~= nil then
				self.msg_pairs[id] = message.id
				self.metadata[data.type][id] = true
				output(log_levels.DEBUG, "[DATA] Checking if we have reached the data chunk limit..") -- Check if we've reached our data chunk limit
				local check = false
				local msg_pool = self.data_channel:getMessages(100)
				for _, msg in pairs(msg_pool) do
					for _, pin in pairs(msg_pool) do
						if msg.id == pin.id then
							check = true
						end
					end
				end
				if check == true then
					output(log_levels.DEBUG, "[DATA] Chunk limit has not been reached yet..")
				else
					output(log_levels.DEBUG, "[DATA] Chunk limit reached. Creating new chunk separator..")
					markPin(self.data_channel)
				end
			else
				output(log_levels.DEBUG, "[DATA-WARN] Attempt to create new data message: " .. tostring(id) .. " - Message to DATA_CHANNEL failed to send!")
				return false
			end
		end
		output(log_levels.INFO, "[DATA] Saved data ID \"" .. id .. "\" into cache.")
		return self.cache[id]
	end

	function data_table:modify(id, key, value) -- A method of calling data_table:save(), but supports resetting values to nil (or to their defaults)
		if not self.synced then output(log_levels.DEBUG, "[DATA-WARN] Data syncing is currently not avaliable! Please make sure your DATA_CHANNEL variable is correctly set-up!") return false end
		assert(type(id) == "string", "An invalid ID was provided!")
		assert(type(key) == "string", "No data KEY was provided!")
		--assert(type(value) == "string", "No data VALUE was provided!")
		if type(value) == nil then
			local data = self.cache[id]
			if data ~= nil then
				data[key] = value
				return self:save(id, data)
			else
				output(log_levels.DEBUG, "[DATA-WARN] Attempt to set key '" .. tostring(key) .. "' to nil from ID: " .. tostring(id) .. " - ID does not exist in cache!")
				return false
			end
		else
			return self:save(id, {[key] = value})
		end
	end

	function data_table:delete(id) -- Deletes data from both our cache and the datastores if we ever need to.
		if not self.synced then output(log_levels.DEBUG, "[DATA-WARN] Data syncing is currently not avaliable! Please make sure your DATA_CHANNEL variable is correctly set-up!") return false end
		assert(type(id) == "string", "An invalid ID was provided!")
		local message = self.msg_pairs[id]
		if message ~= nil then
			message = self.data_channel:getMessage(message)
			if message ~= nil then
				local type = self.cache[id].type
				message:delete() -- This is irreversible
				self.cache[id] = nil
				self.msg_pairs[id] = nil
				self.metadata[type][id] = nil
			end
		else
			output(log_levels.DEBUG, "[DATA-WARN] Attempt to delete data ID: " .. tostring(id) .. " - ID does not exist in cache!")
			return false
		end
	end

	return data_table
end;
