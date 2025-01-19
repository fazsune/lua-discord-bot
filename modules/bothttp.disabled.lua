-- Initialization of the HTTP webserver used for retrieving messages remotely. --

local http = require("http")
--local https = require("https")
local json = require("json")
--local timer = require("timer")


return function(ENV)
	setfenv(1, ENV) -- Connects the main environment from botmain.lua into this file.

	local http_table = {}
	local active = false
	server = http_table -- Loads in the webserver module into the main environment.

	function http_table:init()
		if active then output(log_levels.INFO, "[HTTP] The webserver is already initialized! Ignoring :init() call..") return end
		active = true
		local password = getVar("PASSWORD")
		self.content = ""
		self.webhook = ""
		self.server = http.createServer(function(req, res)
			output(log_levels.DEBUG, "[HTTP] Someone has accessed a webpage!")
			local function getHeader(name)
				name = string.lower(name)
				for _, data in pairs(req.headers) do
					if string.lower(data[1]) == name then
						return tostring(data[2])
					end
				end
			end
			local body = ""
			local passed = getHeader("password") == password

			local path = req.url
			res:setHeader("Content-Type", "text/plain")
			if path == "/" or path == "/messages" then
				if passed == true then
					res:setHeader("Content-Type", "text/plain")
					res:setHeader("Webhook-URL", self.webhook)
					body = json.encode(self.content)
				else
					if path == "/" then
						body = "Welcome! This webserver is functioning properly."
					else
						body = "Bad password"
					end
				end
			else
				body = "Invalid request"
			end
			res:setHeader("Content-Length", #body)
			res:finish(body)
		end)

		self.server:listen(getVar("PORT"))
		output(log_levels.INFO, "[HTTP] The webserver is now running!")

		if server_url and server_url ~= "" and server_url ~= "https://example.com" then
			output(log_levels.INFO, "[HTTP] The webserver will be periodically sent self-wake requests in order to keep the instance awake.")
			timer.setInterval(60000, function() -- Self-wake loop
				local req = https.get(server_url, function(res)
					local body = {}
					res:on("data", function(s)
						body[#body+1] = s
					end)
					res:on("end", function()
						res.body = table.concat(body)
						output(log_levels.DEBUG, "[HTTP] Pinging server..")
						output(log_levels.DEBUG, "[HTTP] Response:", res.body)
					end)
					res:on("error", function(err)
						output(log_levels.DEBUG, "[HTTP] An error occurred while pinging the server..")
						output(log_levels.DEBUG, "[HTTP] Response:", res)
						output(log_levels.DEBUG, "[HTTP] Error:", err)
					end)
				end)
				req:on("error", function(err)
					output(log_levels.DEBUG, "[HTTP] An error occurred while pinging the server..")
					output(log_levels.DEBUG, "[HTTP] Error:", err)
				end)
			end)
		end
	end

	return http_table
end;
