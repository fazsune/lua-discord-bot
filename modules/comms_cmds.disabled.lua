-- Ported commands specific to the Communications Bot. --


return function(lua_env)
	setfenv(1, lua_env) -- Connects the main environment from botmain.lua into this file.
	local cmd_table = { -- Table of commands (admin-only)

		["enable"] = {
			level = 3;
			description = "Enables the two-way communications channel.";
			args = "";
			run = function(self, message)
				activated = true
				message:reply("`Successfully enabled the two-way transmission.`")
			end;
		};

		["disable"] = {
			level = 3;
			description = "Disables the two-way communications channel.";
			args = "";
			run = function(self, message)
				activated = false
				message:reply("`Successfully disabled the two-way transmission.`")
			end;
		};

		["send"] = {
			level = 3;
			description = "Posts a message (UNFILTERED) directly to the webserver.";
			args = "";
			run = function(self, message) -- Debug Command (No text filter)
				local msg_content = string.sub(message.content, string.len(prefix) + string.len(self.name) + 2)
				--postAsync(server_url, {username = message.member.name, content = msgcontent, level = 4})
				server.content = {username = message.member.name, content = msg_content, level = 4, id = randomString(7)}
			end;
		};

		["clear"] = {
			level = 3;
			description = "Clears the message currently set on the webserver.";
			args = "";
			run = function(self, message)
				activated = false
				--postAsync(server_url, {"Hello! Hello! Hello! Hello! How Low?"})
				server.content = ""
				message:reply("`Successfully cleared the server communications file.`")
			end;
		};

		["setchannel"] = {
			level = 3;
			description = "Changes the communications channel to the channel where the command was run.";
			args = "";
			run = function(self, message)
				local channel = message.channel
				local webhook = getWebhook(channel, webhook_name) or channel:createWebhook(webhook_name)
				channels.communications = channel
				--postAsync(server_url, {username = message.member.name, content = webhook_url, level = 4, command = "setwebhook"})
				server.webhook = "https://discordapp.com/api/webhooks/" .. webhook.id .. "/" .. webhook.token
				message:reply("`Successfully set current channel as communcations channel.`")
			end;
		};
	}


	-- Load this module's commands into the main commands table.
	for name, data in pairs(cmd_table) do
		data.name = name
		commands[name] = data
		-- Add this module's commands to the metadata.
		local metadata = commands_metadata[data.level]
		local append = prefix .. data.name
		if data.args then
			append = append .. " " .. tostring(data.args)
		end
		if type(metadata) == "string" then
			commands_metadata[data.level] = metadata .. "`" .. append .. "` - " .. data.description .. "\n"
		else
			commands_metadata[data.level] = "`" .. append .. "` - " .. data.description .. "\n"
		end
	end
end;
