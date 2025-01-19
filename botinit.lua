-- Initialization of functions and variables used by the other .lua files. --

local discordia = require("discordia")
local env = require("env")
local fs = require("fs")
local json = require("json")
local default_log_level = "INFO" -- The logging level used by default before the .env file is read, or if LOG_LEVEL is absent in the file.

local function parse(input)
	local s1, s2 = string.match(input, "(.*)=%s*(.*)") -- matches "NAME = VALUE"
	if s2 and string.sub(s2, #s2) == "\r" then s2 = string.sub(s2, 1, #s2-1) end
	if not s1 or not s2 then return false end
	s1 = string.sub(s1, 1, (string.find(s1, "%s+$") or #s1+1)-1)
	return s1, s2
end


return function(lua_env)
	setfenv(1, lua_env) -- Connects the main environment from botmain.lua into this file.


	-- Custom Output Handling --

	log_levels = {["DEBUG"] = 1, ["INFO"] = 2, ["WARN"] = 3, ["CRITICAL"] = 4}
	log_level_names = {"DEBUG", "INFO", "WARN", "CRITICAL"}
	local current_log_level = log_levels[default_log_level]

	output = function(level, string)
		if type(level) == "string" then
			level = log_levels[level]
		end
		if type(level) == "number" and level >= current_log_level then
			print("[" .. log_level_names[level] .. "] " .. tostring(string))
		end
	end


	-- Environment Variables --

	-- Manually processes our .env file if the bot isn't ran through a .env handler.
	-- http://lua-users.org/wiki/FileInputOutput
	local variables = {}
	local file = fs.existsSync(".env")
	if file then
		for line in io.lines(".env") do
			local key, value = parse(line)
			if key ~= false then
				variables[key] = value
				output(log_levels.DEBUG, "Successfully parsed key \"" .. tostring(key) .. "\".")
				env.unset(key)
			end
		end
	else
		output(log_levels.WARN, "Could not find a .env file in the bot's directory.")
	end
	if variables.VERSION == nil then
		output(log_levels.WARN, "Could not retrieve environment variables. The bot will most likely be unable to continue operating from this point.")
	end

	-- Returns the corresponding value to our variable name.
	local bot_token_retrieved = false
	variable_overrides = {}
	getVar = function(env_name, json_data)
		local env_variable = variable_overrides[env_name] or variables[env_name]
		if type(env_variable) == "string" and env_variable ~= "" then
			if env_name == "BOT_TOKEN" then
				if bot_token_retrieved then
					output(log_levels.WARN, "An attempt to access the environment variable \"" .. tostring(env_name) .. "\" was blocked. If you're seeing this message, please ensure that the bot does not have any backdoors added in.")
					return nil
				else
					bot_token_retrieved = true
					return env_variable
				end
			elseif json_data == true then
				local decoded
				xpcall(function()
					decoded = json.decode(env_variable)
				end, function(error)
					output(log_levels.WARN, "An error occurred while decoding environment variable \"" .. tostring(env_name) .. "\" from JSON. -- " .. error)
				end)
				return decoded or nil
			else
				return env_variable
			end
		else
			output(log_levels.WARN, "The environment variable \"" .. tostring(env_name) .. "\" was not found or properly declared. This may cause issues with the bot while it is operating.")
			return nil
		end
	end

	local bypass_overrides = getVar("BYPASS_OVERRIDES") == "true"
	-- TODO: Override variables after reading from JSON data file


	-- Variables --

	client = discordia.Client()
	client:enableAllIntents()
	enums = discordia.enums

	current_log_level = log_levels[getVar("LOG_LEVEL")] or default_log_level
	bot_name = getVar("BOT_NAME") or "Discord Bot"
	prefix = getVar("PREFIX") or "!"
	commands = require("./botcmds.lua")(lua_env) -- Loads in the commands into the table so that it can get loaded into the main environment later.

	whitelist_only = getVar("WHITELIST_ONLY") == "true"
	invisible_mode = getVar("INVISIBLE") == "true"
	silent_startup = getVar("SILENT_STARTUP") == "true"
	status = getVar("STATUS")

	channels = {}

	owner_override = getVar("OWNER_OVERRIDE")
	owner_override = owner_override ~= "OWNER_ID" and owner_override or nil
	admins = getVar("ADMINS", true) or {}
	whitelisted = getVar("WHITELISTED", true) or {}
	blacklisted = getVar("BLACKLISTED", true) or {}
	rank_levels = {["BLACKLISTED"] = 0, ["REGULAR"] = 1, ["WHITELISTED"] = 2, ["ADMIN"] = 3, ["OWNER"] = 4}


	-- Functions --

	sleep = function(n) -- in seconds
		local t0 = os.clock()
		while os.clock() - t0 <= n do end
		return true -- for while-loops
	end

	secureSend = function(channel, content)
		local ran, error = pcall(function()
			channel:send(content)
		end)
		if not ran then
			message:reply("```~~~ AN INTERNAL ERROR HAS OCCURRED ~~~```")
			output(log_levels.CRITICAL, error)
		end
	end

	getWebhook = function(channel, webhook_name)
		if channel then
			local ran, returned = pcall(function()
				for _, webhook in pairs(channel:getWebhooks():toArray()) do
					if webhook.name == webhook_name and webhook.user.id == client.user.id then
						return webhook
					end
				end
			end)
			if ran then
				return returned
			else
				output(log_levels.CRITICAL, "An error occurred while retrieving a webhook from this channel: <#" .. tostring(channel and channel.id) ">\n" .. returned)
			end
		else
			output(log_levels.WARN, "Channel argument for getWebhook was not given.")
			return nil
		end
		return nil
	end

	checkList = function(list, value)
		for int, element in pairs(list) do
			if element == value then
				return true, int
			end
		end
	end

	getTag = function(id)
		local ran, returned = pcall(function()
			return client:getUser(id).tag
		end)
		if ran then
			return returned
		else
			return "Invalid user"
		end
	end

	getLevel = function(userid)
		local level = rank_levels.REGULAR
		if checkList(whitelisted, userid) then
			level = rank_levels.WHITELISTED
		end
		if checkList(blacklisted, userid) then
			level = rank_levels.BLACKLISTED
		end
		if checkList(admins, userid) then
			level = rank_levels.ADMIN
		end
		if owner == userid then
			level = rank_levels.OWNER
		end
		--[[
		if message.member:getPermissions():has("administrator", "manageGuild", "manageChannels") then
			-- TODO: (add message argument in order to) handle server admins being able to run admin-only commands (for changing server-specifc settings)
		end
		--]]
		return level
	end

	checkPermissions = function(self, single, multiple)
		if tonumber(single) then
			return getLevel(self) > getLevel(single), getTag(single)
		end

		if multiple then
			multiple = multiple:toArray()
			if #multiple ~= 0 then
				local successful = true
				local list1 = ""
				local list2 = ""
				for _, item in pairs(multiple) do
					if getLevel(self) <= getLevel(item.id) then
						successful = false
						list2 = list2 .. getTag(item.id) .. ", "
					else
						list1 = list1 .. getTag(item.id) .. ", "
					end
				end
				if list1 == "" then
					list1 = "No one.."
				end
				return successful, {string.sub(list1, 1, #list1 - 2), string.sub(list2, 1, #list2 - 2)}
			end
		end
		return false, "Invalid user"
	end

	returnListString = function(table_name)
		local full_string = ""
		for _, item in pairs(table_name) do
			full_string = full_string .. getTag(item) .. " - [" .. item .. "]\n"
		end
		return full_string
	end

	modifyList = function(self, single, multiple, table_name, adding)
		if tonumber(single) then
			if checkPermissions(self, single) then
				if adding then
					table.insert(table_name, single)
					return getTag(single)
				else
					local found, int = checkList(table_name, single)
					if found then
						table.remove(table_name, int)
						return getTag(single)
					end
				end
			end
			return false
		end

		if multiple then
			multiple = multiple:toArray()
			if #multiple ~= 0 then
				local full_string = ""
				for _, item in pairs(multiple) do
					if checkPermissions(self, item.id) then
						if adding then
							table.insert(table_name, item.id)
							full_string = full_string .. getTag(item.id) .. ", "
						else
							local found, int = checkList(table_name, item.id)
							if found then
								table.remove(table_name, int)
								full_string = full_string .. getTag(item.id) .. ", "
							end
						end
					end
				end
				return string.sub(full_string, 1, #full_string - 2)
			end
		end
	end


	-- Modules --
	-- (Intentionally loaded after the variable initializations)

	modules = {} -- Loads in any additional modules that may exist in the modules folder.

	fs.readdir("./modules", function(_, files)
		if files then
			for _, name in pairs(files) do
				local basename = string.sub(name, 1, string.len(name) - 3)
				local extension = string.sub(name, math.max(0, string.len(name) - 3))
				local disabled = string.sub(name, math.max(0, string.len(name) - 12))
				if extension == ".lua" and disabled ~= ".disabled.lua" then
					xpcall(function()
						modules[basename] = require("./modules/" .. name)(lua_env)
						output(log_levels.DEBUG, "Successfully initialized ./modules/" .. name .. ".")
					end, function(error)
						output(log_levels.WARN, "Failed to initialize ./modules/" .. name .. ". -- " .. error)
					end)
				else
					output(log_levels.DEBUG, "Skipped disabled/non-script file ./modules/" .. name .. ".")
				end
			end
		end
	end)
end;
