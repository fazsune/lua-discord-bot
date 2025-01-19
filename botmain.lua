-- This is the main environment for the Discord Bot. --


-- Injects our external variables and functions into the main environment.
require("./botinit.lua")(getfenv(1))
output(log_levels.INFO, "Successfully initialized the bot!")


-- Client Initialization --

client:on("ready", function()
	--output(log_levels.DEBUG, "Starting bot..")
	owner = ((owner_override ~= "OWNER_ID" and client:getUser(owner_override)) or client.owner).id
	table.insert(admins, owner)
	channels.main = client:getChannel(getVar("MAIN_CHANNEL"))
	output(log_levels.INFO, "Client is ready. Initializing startup process..")
	output(log_levels.INFO, "Prefix: \"" .. prefix .. "\"")
	output(log_levels.INFO, "Main channel: " .. channels.main.id .. " (" .. channels.main.guild.name .. " - #" .. channels.main.name .. ")")

	if not invisible_mode then
		if not silent_startup then
			if channels.main then
				message = secureSend(channels.main, "```*** {!} " .. bot_name .. " has been activated {!} ***```")
			else
				local private_channel = client:getUser(owner):getPrivateChannel()
				message = secureSend(private_channel, "```*** {!} " .. bot_name .. " has been activated {!} ***```")
			end
		end
		client:setStatus("online")
		if string.lower(status) ~= "none" then
			client:setActivity(status)
		else
			client:setActivity(nil)
		end
	else
		client:setStatus("invisible") -- Bravo Six, going dark.
		client:setActivity(nil)
		output(log_levels.INFO, "Invisible mode is active..")
	end

	output(log_levels.INFO, "*** {!} " .. bot_name .. " has been activated {!} ***")
end)


-- Message Handling --

client:on("messageCreate", function(message)
	if message.author.id == client.user.id or message.author.bot == true or message.author.discriminator == 0000 then return end
	if not message.guild then return end -- TODO: Allow commands inside DMs in the future

	local ran, error = pcall(function()
		local cmdstr = string.lower(message.content)
		if string.sub(cmdstr, 1, string.len(prefix)) == prefix then
			local level = getLevel(message.author.id)
			if whitelist_only and level < rank_levels.WHITELISTED then
				level = 0
			end
			for _, command in pairs(commands) do -- Runs through our list of commands and connects them to our messageCreate connection.
				local command_length = string.len(prefix) + string.len(command.name)
				local next_character = string.sub(cmdstr, (command_length + 1), (command_length + 1))
				if string.sub(cmdstr, 1, command_length) == string.lower(prefix .. command.name) and (next_character == "" or next_character == " ") then
					if command.level <= level then
						local ran, error = pcall(function()
							command:run(message)
						end)
						if not ran then
							message:reply("```~~~ AN INTERNAL ERROR HAS OCCURRED DURING COMMAND EXECUTION. ~~~```")
							output(log_levels.CRITICAL, error)
						end
					else
						message:reply("```~~~ You do not have permissions to run this command! ~~~```")
					end
				break end
			end
		end
	end)
	if not ran then
		message:reply("```~~~ AN INTERNAL ERROR HAS OCCURRED DURING COMMAND PARSING. ~~~```")
		output(log_levels.CRITICAL, error)
	end
end)


-- Bot Activation --

local BOT_TOKEN = getVar("BOT_TOKEN")
-- Make sure that your BOT_TOKEN is always secure!

if BOT_TOKEN then
	client:run("Bot " .. BOT_TOKEN)
else
	output(log_levels.WARN, "Could not initialize the bot because the BOT_TOKEN variable was not found! Please make sure that your .env file is present and not corrupted.")
end;
