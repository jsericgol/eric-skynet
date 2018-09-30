local skynet = require "skynet"
local sprotoloader = require "sprotoloader"

local max_client = 64

skynet.start(function()
	skynet.error("====main.lua=> skynet.start")
	skynet.uniqueservice("protoloader")
	if not skynet.getenv "daemon" then
		local console = skynet.newservice("console")
	end
	skynet.newservice("debug_console",8000)
	skynet.newservice("simpledb")
	skynet.error("===== main.lua=> before launch watchdog")
	local watchdog = skynet.newservice("watchdog")
	skynet.error("===== main.lua=> skynet.start: begin skynet.call to watchdog")
	skynet.call(watchdog, "lua", "start", {
		port = 8888,
		maxclient = max_client,
		nodelay = true,
	})

	skynet.error("=========== main.lua=>server start success =========")

    skynet.exit()
end)
