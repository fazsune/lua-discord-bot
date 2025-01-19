-- The table of commands that are registered on the Bot. --


return function(ENV)
	setfenv(1, ENV) -- Connects the main environment from botmain.lua into this file
	local cmd_table = { -- Table of commands (from normal to owner-only commands)

		["invite"] = {
			level = 1;
			description = "Sends an invite of the bot to add to a server.";
			args = "";
			run = function(self, message)
				message:reply("**`Invitation link:`** https://discord.com/oauth2/authorize?client_id=" .. tostring(client.user.id) .. "&scope=bot&permissions=8")
			end;
		};

		["setwhitelist"] = {
			level = 3;
			description = "Toggles the whitelist-only state for the bot. This will affect the ability for regular users to interact with the bot in any way.";
			args = "";
			run = function(self, message)
				whitelist_only = not whitelist_only
				if whitelist_only then
					message:reply("`Successfully **enabled** whitelisting restrictions.`")
				else
					message:reply("`Successfully *disabled* whitelisting restrictions.`")
				end
			end;
		};

		["whitelist"] = {
			level = 3;
			description = "Adds a user to the whitelist.";
			args = "<user-id/mentions>";
			run = function(self, message)
				local userid = string.sub(message.content, string.len(prefix) + string.len(self.name) + 2)
				local users = message.mentionedUsers
				local check, returned = checkPermissions(message.author.id, userid, users)
				local send = modifyList(message.author.id, userid, users, whitelisted, true)
				modifyList(message.author.id, userid, users, blacklisted, false)
				if check then
					message:reply("`Successfully whitelisted " .. send .. ".`")
				elseif type(returned) == "table" then
					message:reply("`Successfully whitelisted " .. returned[1] .. ".`\n`Could not whitelist " .. returned[2] .. " because they have the same permission level as you or higher.`")
				else
					message:reply("`Could not whitelist " .. returned .. " because they have the same permission level as you or higher.`")
				end
			end;
		};

		["unwhitelist"] = {
			level = 3;
			description = "Removes a user from the whitelist.";
			args = "<user-id/mentions>";
			run = function(self, message)
				local userid = string.sub(message.content, string.len(prefix) + string.len(self.name) + 2)
				local users = message.mentionedUsers
				local check, returned = checkPermissions(message.author.id, userid, users)
				local send = modifyList(message.author.id, userid, users, whitelisted, false)
				if check then
					message:reply("`Successfully unwhitelisted " .. send .. ".`")
				elseif type(returned) == "table" then
					message:reply("`Successfully unwhitelisted " .. returned[1] .. ".`\n`Could not unwhitelist " .. returned[2] .. " because they have the same permission level as you or higher.`")
				else
					message:reply("`Could not unwhitelist " .. returned .. " because they have the same permission level as you or higher.`")
				end
			end;
		};

		["blacklist"] = {
			level = 3;
			description = "Adds a user to the blacklist.";
			args = "<user-id/mentions>";
			run = function(self, message)
				local userid = string.sub(message.content, string.len(prefix) + string.len(self.name) + 2)
				local users = message.mentionedUsers
				local check, returned = checkPermissions(message.author.id, userid, users)
				local send = modifyList(message.author.id, userid, users, blacklisted, true)
				modifyList(message.author.id, userid, users, whitelisted, false)
				modifyList(message.author.id, userid, users, admins, false)
				if check then
					message:reply("`Successfully blacklisted " .. send .. ".`")
				elseif type(returned) == "table" then
					message:reply("`Successfully blacklisted " .. returned[1] .. ".`\n`Could not blacklist " .. returned[2] .. " because they have the same permission level as you or higher.`")
				else
					message:reply("`Could not blacklist " .. returned .. " because they have the same permission level as you or higher.`")
				end
			end;
		};

		["unblacklist"] = {
			level = 3;
			description = "Removes a user from the blacklist.";
			args = "<user-id/mentions>";
			run = function(self, message)
				local userid = string.sub(message.content, string.len(prefix) + string.len(self.name) + 2)
				local users = message.mentionedUsers
				local check, returned = checkPermissions(message.author.id, userid, users)
				local send = modifyList(message.author.id, userid, users, blacklisted, false)
				if check then
					message:reply("`Successfully unblacklisted " .. send .. ".`")
				elseif type(returned) == "table" then
					message:reply("`Successfully unblacklisted " .. returned[1] .. ".`\n`Could not unblacklist " .. returned[2] .. " because they have the same permission level as you or higher.`")
				else
					message:reply("`Could not unblacklist " .. returned .. " because they have the same permission level as you or higher.`")
				end
			end;
		};

		["admin"] = {
			level = 4;
			description = "Adds a user to the admin list.";
			args = "<user-id/mentions>";
			run = function(self, message)
				if message.author.id == owner then
					local userid = string.sub(message.content, string.len(prefix) + string.len(self.name) + 2)
					local users = message.mentionedUsers
					--local check, returned = checkPermissions(message.author.id, userid, users)
					local send = modifyList(message.author.id, userid, users, admins, true)
					modifyList(message.author.id, userid, users, blacklisted, false)
					if send then
						message:reply("`Successfully gave admin to " .. send .. ".`")
					else
						message:reply("`Failed to give admin to the target user(s) (couldn't be found or wasn't specified).`")
					end
				else
					message:reply("`You do not have permissions to run this command!`")
				end
			end;
		};

		["unadmin"] = {
			level = 4;
			description = "Removes a user from the admin list.";
			args = "<user-id/mentions>";
			run = function(self, message)
				if message.author.id == owner then
					local userid = string.sub(message.content, string.len(prefix) + string.len(self.name) + 2)
					local users = message.mentionedUsers
					--local check, returned = checkPermissions(message.author.id, userid, users)
					local send = modifyList(message.author.id, userid, users, admins, false)
					if send then
						message:reply("`Successfully removed admin from " .. send .. ".`")
					else
						message:reply("`Failed to remove admin from the target user(s) (couldn't be found or wasn't specified).`")
					end
				else
					message:reply("`You do not have permissions to run this command!`")
				end
			end;
		};

		["whitelisted"] = {
			level = 3;
			description = "Displays all users on the whitelist.";
			args = "";
			run = function(self, message)
				if #whitelisted ~= 0 then
					local send = returnListString(whitelisted)
					message:reply("```***These are the currently whitelisted users.***\n\n" .. send .. "```")
				else
					message:reply("```***There are no currently whitelisted users.***```")
				end
			end;
		};

		["blacklisted"] = {
			level = 3;
			description = "Displays all users on the blacklist.";
			args = "";
			run = function(self, message)
				if #blacklisted ~= 0 then
					local send = returnListString(blacklisted)
					message:reply("```***These are the currently blacklisted users.***\n\n" .. send .. "```")
				else
					message:reply("```***There are no currently blacklisted users.***```")
				end
			end;
		};

		["admins"] = {
			level = 4;
			description = "Displays all users on the admin list.";
			args = "";
			run = function(self, message)
				if message.author.id == owner then
					if #admins ~= 0 then
						local send = returnListString(admins)
						message:reply("```***These are the currently admined users.***\n\n" .. send .. "```")
					else
						message:reply("```***There are no currently admined users (except the owner).***```")
					end
				else
					message:reply("`You do not have permissions to run this command!`")
				end
			end;
		};

		["close"] = {
			level = 4;
			description = "Shuts down the bot.";
			args = "";
			run = function(self, message)
				if message.author.id == owner then
					message:reply("```***Stopping processes and disconnecting from all shards..***```")
					client:stop()
				else
					message:reply("`You do not have permissions to run this command!`")
				end
			end;
		};
	}


	-- Command Metadata Initialization --

	commands_metadata = {}
	for name, data in pairs(cmd_table) do
		data.name = name
		local metadata = commands_metadata[data.level]
		local append = prefix .. data.name
		if data.args and data.args ~= "" then
			append = append .. " " .. tostring(data.args)
		end
		if type(metadata) == "string" then
			commands_metadata[data.level] = metadata .. "`" .. append .. "` - " .. data.description .. "\n"
		else
			commands_metadata[data.level] = "`" .. append .. "` - " .. data.description .. "\n"
		end
	end

	cmd_table["help"] = {
		name = "help";
		level = 1;
		description = "Displays the available commands that the user can run.";
		run = function(self, message)
			local user_level = getLevel(message.author.id)
			local embeds = {
				title = "Commands List";
				description = "```~~~ This bot is in active development! ~~~\nIf you would like to make a contribution to the bot, feel free to stop by the GitHub repository linked here: https://github.com/fazsune/lua-discord-bot```\n**Prefix =** `" .. tostring(prefix) .. "`";
				color = 10747904;
				thumbnail = {url = client.user.avatarURL};
				author = {name = bot_name, icon_url = client.user.avatarURL};
				fields = {
					{name = "Public Commands", value = "`" .. prefix .. "help` - Displays the available commands that the user can run.\n" .. commands_metadata[1]};
				};
			}
			if user_level >= 2 and commands_metadata[2] then
				table.insert(embeds.fields, {name = "Whitelist-Only Commands", value = commands_metadata[2]})
			end
			if user_level >= 3 and commands_metadata[3] then
				table.insert(embeds.fields, {name = "Admin Commands", value = commands_metadata[3]})
			end
			if user_level >= 4 and commands_metadata[4] then
				table.insert(embeds.fields, {name = "Operator Commands", value = commands_metadata[4]})
			end
			message:reply{embed = embeds}
		end;
	}

	return cmd_table
end;
