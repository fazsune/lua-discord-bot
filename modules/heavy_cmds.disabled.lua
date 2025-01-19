-- Ported commands specific to Heavy Dictator. --


return function(lua_env)
	setfenv(1, lua_env) -- Connects the main environment from botmain.lua into this file.
	local cmd_table = { -- Table of commands (from normal to owner-only commands)

		["minecoal"] = {
			level = 1;
			description = "Mines a piece of coal.";
			args = "";
			run = function(self, message)
				if not isCoalMine(message) then return end
				local data = status_list[message.guild.id]
				if data == nil then
					message:addReaction("❌")
					message:reply("Coal operation is not active at this time.")
				elseif not data.reached then
					local mined = math.random(1,3)
					addCoal(message, mined)
					message:reply("Mined `" .. tostring(mined) .. "` piece(s) of coal.")
					--[[
					if mined == 1 then
						message:addReaction("⛏")
					elseif mined == 2 then
						message:addReaction("🛠")
					elseif mined == 3 then
						message:addReaction("⚒")
					end
					--]]
					data.coal = data.coal + mined
					if data.coal >= data.goal and not data.reached then
						data.reached = true
						data.coal = data.goal
						local reply = message:reply({content = "**We have reached our goal of `" .. tostring(data.goal) .. "` pieces of coal.** ***Thank you for supporting the Soviet Union!***\n```Do \"" .. tostring(prefix) .. "paycheck\" to get your Soviet government paychecks.```", tts = true})
						reply:pin()
					end
				else
					message:addReaction("❌")
					message:reply("WE HAVE ALREADY REACHED OUR GOAL OF `" .. tostring(data.goal) .. "` PIECES OF COAL!!")
					--// Quick fix because people don't understand what ❌ is.
				end
			end;
		};

		["goal"] = {
			level = 1;
			description = "Shows the total amount of coal needed to be mined.";
			args = "";
			run = function(self, message)
				if not isCoalMine(message) then return end
				local data = status_list[message.guild.id]
				if data ~= nil then
					message:reply("About `" .. tostring(data.goal - data.coal) .. "` out of `" .. tostring(data.goal) .. "` pieces of coal still needs to be mined. NOW BACK TO WORK!!")
				else
					message:addReaction("❌")
					message:reply("Coal operation is not active at this time.")
				end
			end;
		};

		["total"] = {
			level = 1;
			description = "Shows the total amount of coal that has already been mined.";
			args = "";
			run = function(self, message)
				if not isCoalMine(message) then return end
				local data = status_list[message.guild.id]
				if data ~= nil then
					message:reply("A total of `" .. tostring(data.coal) .. "` pieces coal has been mined. NOW BACK TO WORK!!")
				else
					message:addReaction("❌")
					message:reply("Coal operation is not active at this time.")
				end
			end;
		};

		["paycheck"] = {
			level = 1;
			description = "Gives your government paycheck.";
			args = "";
			run = function(self, message)
				if not isCoalMine(message) then return end
				local sData = dataCheck(message.guild.id, "serverdata") -- Server Data
				local cData = status_list[message.guild.id] -- Coal Operation Data
				if cData == nil then
					message:addReaction("❌")
					message:reply("Coal operation is not active at this time.")
				elseif cData.reached then
					local worker = cData.workers[message.author.id]
					if worker == nil then -- Did not find worker in contribution or paid list
						message:addReaction("❌")
						message:reply("You DID NOT CONTRIBUTE TO WORK!! NO PAY FOR YOU!!!!!!!!")
					elseif worker.paid == true then -- Found worker in paid list
						message:addReaction("❌")
						message:reply("You already RECIEVED YOUR PAYCHECK!!")
					else -- Found worker in contribution list, not in paid list
						worker.paid = true
						local owed
						if sData.paytype == "random" then
							owed = math.random(sData.minpay, sData.maxpay)
						elseif sData.paytype == "ratio" then
							owed = getCoal(message) * sData.ctrate
						elseif sData.paytype == "static" then
							owed = cData.goal * sData.gtrate
						else
							output(log_levels.WARN, "Server " .. tostring(sData.id) .. " has an invalid paytype! Assuming paytype == 'ratio'.")
							owed = getCoal(message) * sData.ctrate
						end
						addBalance(message.author.id, owed)
						local foreign = math.floor((owed * sData.usrate) * 100) / 100
						message:addReaction("💰")
						message:reply("Here is your paycheck of `" .. tostring(owed) .. " RUB`. (About `$" .. tostring(foreign) .. "` in CAPITALIST DOLLARS!!)")
					end
				else
					message:addReaction("❌")
					message:reply("OUR GOAL OF `" .. tostring(goal - coal) .. "` MORE PIECES OF COAL HASN'T BEEN REACHED YET. NOW BACK TO WORK!!")
				end
			end;
		};

		["balance"] = {
			level = 1;
			description = "Shows your current government balance.";
			args = "";
			run = function(self, message)
				local balance = getBalance(message.author.id)
				if balance > 0 then
					message:reply("You have a total balance of `" .. tostring(balance) .. " RUB` in your account.")
				elseif balance == 0 then
					message:addReaction("❌")
					message:reply("You have NO total balance in your account. GET WORKING IF YOU WANT TO GET A PAYCHECK!!")
				elseif balance < 0 then
					message:addReaction("❌")
					message:reply("You are IN DEBT BY `" .. tostring(math.abs(balance)) .. " RUB`. GET BACK TO WORK AND PAY IT OFF!!")
				end
			end;
		};


		-- Admin-only commands (Server admins, and bot operators)

		["setmine"] = {
			level = 3;
			description = "Changes the coal mining channel.";
			args = "<channel-id>";
			run = function(self, message)
				local serverId = message.guild.id
				local target = string.sub(message.content, string.len(prefix) + string.len(self.name) + 2)
				if target ~= nil and target ~= "" then
					local channel = client:getChannel(target)
					if channel ~= nil then
						serverId = channel.guild.id
						local data = datastore:save(serverId, {coalmine = target}, "serverdata")
						message:reply("`Successfully changed the 'coalmine' channel!` - <#" .. tostring(data.coalmine) .. ">")
						coalOperation(serverId)
						client:getChannel(data.coalmine):send("**```We are now aiming for '" .. tostring(status_list[serverId].goal) .. "' pieces of coal.```**")
					else
						message:reply("`Could not find the channel of the provided ID!`")
					end
				else
					local data = datastore:save(serverId, {coalmine = message.channel.id}, "serverdata")
					message:reply("`Successfully changed the 'coalmine' channel!` - <#" .. tostring(data.coalmine) .. ">")
					coalOperation(serverId)
					client:getChannel(data.coalmine):send("**```We are now aiming for '" .. tostring(status_list[serverId].goal) .. "' pieces of coal.```**")
				end
			end;
		};

		["reset"] = {
			level = 3;
			description = "Resets the mined coal quota.";
			args = "";
			run = function(self, message)
				local serverId = message.guild.id
				local data = dataCheck(serverId, "serverdata")
				if data.coalmine ~= nil then
					coalOperation(serverId)
					message:reply("```Successfully restarted the coal mine operation!```")
					client:getChannel(data.coalmine):send("**```We are now aiming for '" .. tostring(status_list[serverId].goal) .. "' pieces of coal.```**")
				else
					local main = message:reply("`No coalmine channel currently exists for this server! Would you like to set THIS channel as the coalmine channel?`")
					local content = waitForNextMessage(message).content:lower()
					if content == "yes" then
						datastore:save(serverId, {coalmine = message.channel.id}, "serverdata")
						main:setContent("`Set coalmine channel for this server to: ` <#" .. tostring(message.channel.id) .. ">.")
					else
						main:setContent("```Cancelled the procedure.```")
					end
				end
			end;
		};

		["setgoal"] = {
			level = 3;
			description = "Sets the minimum and maximum range goal.";
			args = "<min,max>";
			run = function(self, message)
				local serverId = message.guild.id
				local data = dataCheck(serverId, "serverdata")
				local args = string.sub(message.content, string.len(prefix) + string.len(self.name) + 2)
				if args == nil or args == "" then
					message:addReaction("❌")
					message:reply("```Unable to change 'Goal range' (Range is currently: " .. tostring(data.mingoal) .. "-" .. tostring(data.maxgoal) .. ") - No arguments were provided.```")
				return end
				local split = string.find(args, ",")
				if split == nil then
					message:addReaction("❌")
					message:reply("```Unable to change 'Goal range' - The arguments provided are invalid.\n(They must be formatted: number,number)```")
				return end
				local min = tonumber(string.sub(args, 1, split-1))
				local max = tonumber(string.sub(args, split+1, string.len(args)))
				if min ~= nil and max ~= nil then
					datastore:save(serverId, {mingoal = min, maxgoal = max}, "serverdata")
					message:reply("```Successfully made the following changes:\nMinimum goal: " .. tostring(min) .. "\nMaximum goal: " .. tostring(max) .. "```")
				else
					message:addReaction("❌")
					message:reply("```Unable to change 'Goal range' - The arguments provided are invalid.\n(They must be formatted: number,number)```")
				end
			end;
		};

		["paytype"] = {
			level = 3;
			description = "Sets the way paychecks are given out on a specific server.";
			args = "<random/ratio/static>";
			run = function(self, message)
				local serverId = message.guild.id
				local data = dataCheck(serverId, "serverdata")
				local args = string.sub(message.content, string.len(prefix) + string.len(self.name) + 2)
				if args == nil or args == "" then
					message:addReaction("❌")
					message:reply("```Unable to change 'Pay type' (Currently set to: " .. tostring(data.paytype) .. ") - No arguments were provided.```")
				else
					args = string.lower(args)
					if args == "random" or args == "ratio" or args == "static" then
						datastore:save(serverId, {paytype = args}, "serverdata")
						message:reply("```Successfully made the following changes:\nNew pay type: " .. tostring(args) .. "```")
					else
						message:addReaction("❌")
						message:reply("```Unable to change 'Pay type' (" .. tostring(prefix) .. tostring(self.name) .. ") - The arguments provided are invalid.\n(Must be 'random', 'ratio', or 'static')```")
					end
				end
			end;
		};


		-- I'm restricting these commands to owner-only for now while I figure out how to keep the paycheck system balanced (so people cannot get tons of money easily).

		["setpay"] = {
			level = 4;
			description = "Sets the minimum and maximum range of pay. (Only used when the paytype is 'random')";
			args = "<min,max>";
			run = function(self, message)
				local serverId = message.guild.id
				local data = dataCheck(serverId, "serverdata")
				local args = string.sub(message.content, string.len(prefix) + string.len(self.name) + 2)
				if args == nil or args == "" then
					message:addReaction("❌")
					message:reply("```Unable to change 'Pay range' (Range is currently: " .. tostring(data.minpay) .. "-" .. tostring(data.maxpay) .. ") - No arguments were provided.```")
				return end
				local split = string.find(args, ",")
				if split == nil then
					message:addReaction("❌")
					message:reply("```Unable to change 'Pay range' - The arguments provided are invalid.\n(They must be formatted: number,number)```")
				return end
				local min = tonumber(string.sub(args, 1, split-1))
				local max = tonumber(string.sub(args, split+1, string.len(args)))
				if min ~= nil and max ~= nil then
					datastore:save(serverId, {minpay = min, maxpay = max}, "serverdata")
					message:reply("```Successfully made the following changes:\nMinimum pay (in RUB): " .. tostring(min) .. "\nMaximum pay (in RUB): " .. tostring(max) .. "```")
				else
					message:addReaction("❌")
					message:reply("```Unable to change 'Pay range' - The arguments provided are invalid.\n(They must be formatted: number,number)```")
				end
			end;
		};

		["usrate"] = {
			level = 4;
			description = "Sets the conversion rate for USD --> RUB.";
			args = "<usd-rate>";
			run = function(self, message)
				local serverId = message.guild.id
				local data = dataCheck(serverId, "serverdata")
				local args = string.sub(message.content, string.len(prefix) + string.len(self.name) + 2)
				if args == nil or args == "" then
					message:addReaction("❌")
					message:reply("```Unable to change 'Conversion rate' (Currently set to: " .. tostring(data.usrate) .. ") - No arguments were provided.```")
				elseif tonumber(args) then
					datastore:save(serverId, {usrate = tonumber(args)}, "serverdata")
					message:reply("```Successfully made the following changes:\nConversion rate: 1 USD == " .. tostring(1 / args) .. " RUB```")
				else
					message:addReaction("❌")
					message:reply("```Unable to change 'Conversion rate' (" .. tostring(prefix) .. tostring(self.name) .. ") - The arguments provided are invalid.\n(Must be a number)```")
				end
			end;
		};

		["ctrate"] = {
			level = 4;
			description = "Sets the pay rate for coal --> RUB. (Only used when the paytype is 'ratio')";
			args = "<coal-rate>";
			run = function(self, message)
				local serverId = message.guild.id
				local data = dataCheck(serverId, "serverdata")
				local args = string.sub(message.content, string.len(prefix) + string.len(self.name) + 2)
				if args == nil or args == "" then
					message:addReaction("❌")
					message:reply("```Unable to change 'Ratio payrate' (Currently set to: " .. tostring(data.ctrate) .. ") - No arguments were provided.```")
				elseif tonumber(args) then
					datastore:save(serverId, {ctrate = tonumber(args)}, "serverdata")
					message:reply("```Successfully made the following changes:\nNew 'ratio' payrate: 1 Coal (mined) == " .. tostring(args) .. " RUB```")
				else
					message:addReaction("❌")
					message:reply("```Unable to change 'Ratio payrate' (" .. tostring(prefix) .. tostring(self.name) .. ") - The arguments provided are invalid.\n(Must be a number)```")
				end
			end;
		};

		["gtrate"] = {
			level = 4;
			description = "Sets the pay rate for goal --> RUB. (Only used when the paytype is 'static')";
			args = "<goal-rate>";
			run = function(self, message)
				local serverId = message.guild.id
				local data = dataCheck(serverId, "serverdata")
				local args = string.sub(message.content, string.len(prefix) + string.len(self.name) + 2)
				if args == nil or args == "" then
					message:addReaction("❌")
					message:reply("```Unable to change 'Static payrate' (Currently set to: " .. tostring(data.gtrate) .. ") - No arguments were provided.```")
				elseif tonumber(args) then
					datastore:save(serverId, {gtrate = tonumber(args)}, "serverdata")
					message:reply("```Successfully made the following changes:\nNew 'static' payrate: 1 Coal (total) == " .. tostring(args) .. " RUB```")
				else
					message:addReaction("❌")
					message:reply("```Unable to change 'Static payrate' (" .. tostring(prefix) .. tostring(self.name) .. ") - The arguments provided are invalid.\n(Must be a number)```")
				end
			end;
		};


		-- Owner-only commands (Owner of the bot, or the user specified in OWNER_OVERRIDE)

		["pay"] = {
			level = 4;
			description = "Gives the target user an amount of money (Use only for compensation)";
			args = "<target-user> <amount>";
			run = function(self, message)
				local sData = dataCheck(message.guild.id, "serverdata") -- Server Data
				local args = string.sub(message.content, string.len(prefix) + string.len(self.name) + 2)
				if args == nil or args == "" then
					message:addReaction("❌")
					message:reply("```Unable to change give out paycheck - No arguments were provided.```")
				return end
				local split = string.find(args, " ")
				if split == nil then
					message:addReaction("❌")
					message:reply("```Unable to change give out paycheck - The arguments provided are invalid.\n(They must be formatted: <target-user> <amount>)```")
				return end
				local userid = string.sub(args, 1, split-1)
				local amount = tonumber(string.sub(args, split+1, string.len(args)))
				if userid ~= nil and amount ~= nil then
					local user = client:getUser(userid)
					if user ~= nil then
						addBalance(userid, amount)
						local foreign = math.floor((amount * sData.usrate) * 100) / 100
						message:addReaction("💰")
						message:reply("`@" .. user.username .. "` has been paid `" .. tostring(amount) .. " RUB`. (About `$" .. tostring(foreign) .. "` in CAPITALIST DOLLARS!!)")
					else
						message:addReaction("❌")
						message:reply("```Unable to change give out paycheck - User ID <@" .. tostring(userid) .. "> does not exist.```")
					end
				else
					message:addReaction("❌")
					message:reply("```Unable to change give out paycheck - Some arguments are missing.\n(They must be formatted: <target-user> <amount>)```")
				end
			end;
		};

		["datamod"] = { -- TODO: Refactor
			level = 4;
			description = "An interactive command for editing datatables.";
			args = "";
			run = function(self, message)
				--if message.author.id ~= owner then return end
				local content, option
				local main = message:reply("```Please specify the function you are trying to access:\nModify value (mod)\nClear value (clr)\nDelete entire data table (del)```")
				local newmsg = waitForNextMessage(message)
				content = newmsg.content:lower()
				newmsg:delete()
				if content == "add" or content == "clr" or content == "mod" or content == "del" then
					option = content
				else
					main:setContent("```Invalid option. Cancelling the procedure .. ```")
					return
				end
				main:setContent("```Specify the ID (server or user) of the datatable you wish to modify.```")
				newmsg = waitForNextMessage(message)
				content = newmsg.content:lower()
				newmsg:delete()
				if content == "type" or content == "id" then
					main:setContent("```Sorry! This key value is protected in order to keep the integrity of the stored data. Cancelling the procedure .. ```")
				end
				local datatable = datastore.cache[content]
				if datatable ~= nil then
					if option == "del" then
						main:setContent("```ARE YOU SURE YOU WISH TO DELETE ALL THE DATA FOR " .. tostring(datatable.id) .. " (" .. tostring(datatable.name) .. ")?```")
						newmsg = waitForNextMessage(message)
						content = newmsg.content:lower()
						newmsg:delete()
						if content == "yes" then
							datastore.cache[content] = nil
							datastore:delete(datatable.id)
							main:setContent("```Successfully deleted the data of " .. tostring(datatable.id) .. " (" .. tostring(datatable.name) .. ").```")
						else
							main:setContent("```Cancelled the procedure.```")
						end
					else
						main:setContent("```Specify the name of the data key you wish to modify.```")
						newmsg = waitForNextMessage(message)
						content = newmsg.content:lower()
						newmsg:delete()
						local keyname, found = content, datatable[content]
						if found ~= nil then
							if option == "clr" then
								main:setContent("```ARE YOU SURE YOU WISH TO CLEAR THE KEY '" .. tostring(keyname) .. "' FOR THE DATA OF " .. tostring(datatable.id) .. " (" .. tostring(datatable.name) .. ")?```")
								newmsg = waitForNextMessage(message)
								content = newmsg.content:lower()
								newmsg:delete()
								if content == "yes" then
									datastore:modify(datatable.id, keyname, nil)
									main:setContent("```Successfully cleared the '" .. tostring(keyname) .. "' key from the data of " .. tostring(datatable.id) .. " (" .. tostring(datatable.name) .. ").```")
								else
									main:setContent("```Cancelled the procedure.```")
								end
							elseif option == "mod" then
								main:setContent("```Specify the value that you wish to set the key '" .. tostring(keyname) .. "' to.```")
								newmsg = waitForNextMessage(message)
								local newvalue = newmsg.content
								local json = require("json")
								if tonumber(newvalue) ~= nil then
									newvalue = tonumber(newvalue)
								elseif json.decode(newvalue) ~= nil then
									newvalue = json.decode(newvalue)
								end
								newmsg:delete()
								main:setContent("```ARE YOU SURE YOU WISH TO OVERWRITE THE KEY '" .. tostring(keyname) .. "' TO \"" .. tostring(newvalue) .. "\" FOR THE DATA OF " .. tostring(datatable.id) .. " (" .. tostring(datatable.name) .. ")?```")
								newmsg = waitForNextMessage(message)
								content = newmsg.content:lower()
								newmsg:delete()
								if content == "yes" then
									datastore:modify(datatable.id, keyname, newvalue)
									main:setContent("```Successfully overwritten the key '" .. tostring(keyname) .. "' key to \"" .. tostring(newvalue) .. "\" for the data of " .. tostring(datatable.id) .. " (" .. tostring(datatable.name) .. ").```")
								else
									main:setContent("```Cancelled the procedure.```")
								end
							end
						else
							main:setContent("```Invalid key name. Cancelling the procedure .. ```")
						end
					end
				else
					main:setContent("```The datatable of that ID does not exist. Cancelling the procedure .. ```")
				end
			end;
		};

		["setmain"] = {
			level = 4;
			description = "Changes the broadcast channel.";
			args = "<channel-id>";
			run = function(self, message)
				--if message.author.id ~= owner then return end
				local target = string.sub(message.content, string.len(prefix) + string.len(self.name) + 2)
				if target ~= nil and target ~= "" then
					target = client:getChannel(target)
					if target ~= nil then
						channels.broadcast = target
						message:reply("`Successfully changed the 'broadcast' channel!` - <#" .. tostring(target.id) .. ">")
					else
						message:reply("`Could not find the channel of the provided ID!`")
					end
				else
					channels.broadcast = message.channel
					message:reply("`Successfully changed the 'broadcast' channel!` - <#" .. tostring(channels.broadcast.id) .. ">")
				end
			end;
		};

		["setdest"] = {
			level = 4;
			description = "Changes the destination channel.";
			args = "<channel-id>";
			run = function(self, message)
				--if message.author.id ~= owner then return end
				local target = string.sub(message.content, string.len(prefix) + string.len(self.name) + 2)
				if target ~= nil and target ~= "" then
					target = client:getChannel(target)
					if target ~= nil then
						channels.destination = target
						message:reply("`Successfully changed the 'destination' channel!` - <#" .. tostring(target.id) .. ">")
					else
						message:reply("`Could not find the channel of the provided ID!`")
					end
				else
					channels.destination = message.channel
					message:reply("`Successfully changed the 'destination' channel!` - <#" .. tostring(channels.destination.id) .. ">")
				end
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
		if data.args and data.args ~= "" then
			append = append .. " " .. tostring(data.args)
		end
		if type(metadata) == "string" then
			commands_metadata[data.level] = metadata .. "`" .. append .. "` - " .. data.description .. "\n"
		else
			commands_metadata[data.level] = "`" .. append .. "` - " .. data.description .. "\n"
		end
	end
end;
