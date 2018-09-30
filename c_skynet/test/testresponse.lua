local skynet = require "skynet"

local mode = ...

if mode == "TICK" then
-- this service whould response the request every 1s.

local response_queue = {}

local function response()
	while true do
		skynet.sleep(100)	-- sleep 1s
		for k,v in ipairs(response_queue) do
			skynet.error("11111111=> response")
			v(true, skynet.now())		-- true means succ, false means error
			response_queue[k] = nil
		end
	end
end

skynet.start(function()
	skynet.error("1111111111")
	skynet.fork(response)
	skynet.dispatch("lua", function()
		skynet.error("11111111 => skynet.dispatch")
		table.insert(response_queue, skynet.response())
	end)
end)

else

local function request(tick, i)
	skynet.error(i, "call", skynet.now())
	skynet.error(i, "response", skynet.call(tick, "lua"))
	skynet.error(i, "end", skynet.now())
end

skynet.start(function()
	skynet.error("222222222")
	local tick = skynet.newservice(SERVICE_NAME, "TICK")

	for i=1,5 do
		skynet.fork(request, tick, i)
		skynet.sleep(10)
	end
end)

end