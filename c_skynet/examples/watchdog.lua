local skynet = require "skynet"

local CMD = {}
local SOCKET = {}
local gate
local agent = {}

function SOCKET.open(fd, addr)
	skynet.error(string.format("watchdog=>New Client from %s, fd:%d", addr, fd))
	agent[fd] = skynet.newservice("agent")
    skynet.error("watchdog.lua=>SOCKET.open: before skynet.call")
	skynet.call(agent[fd], "lua", "start", { gate = gate, client = fd, watchdog = skynet.self() })
    skynet.error("watchdog=> after call agent")
end

local function close_agent(fd)
	local a = agent[fd]
	agent[fd] = nil
	if a then
		skynet.call(gate, "lua", "kick", fd)
		-- disconnect never return
		skynet.send(a, "lua", "disconnect")
	end
end

function SOCKET.close(fd)
	print("socket close",fd)
	close_agent(fd)
end

function SOCKET.error(fd, msg)
	print("socket error",fd, msg)
	close_agent(fd)
end

function SOCKET.warning(fd, size)
	-- size K bytes havn't send out in fd
	print("socket warning", fd, size)
end

function SOCKET.data(fd, msg)
end

function CMD.start(conf)
    skynet.error("---watchdog.lua=>CMD.start 1111  conf:", conf)
	skynet.call(gate, "lua", "open" , conf)
    skynet.error("---watchdog.lua=>CMD.start 2222")
end

function CMD.close(fd)
	close_agent(fd)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        local str = string.format("session=%d, source=%s", session, source)
        skynet.error("====watchdog.lua=>skynet.dispatch:" .. str)
		if cmd == "socket" then
            skynet.error("-----watchdog.lua=>skynet.dispatch: subcmd=", subcmd)
			local f = SOCKET[subcmd]
			f(...)
			-- socket api don't need return
		else
            skynet.error("-----watchdog.lua=>skynet.dispatch: cmd=", cmd)
			local f = assert(CMD[cmd])
            f(subcmd, ...)

            ---- skynet.response  延迟回应
            local myret = skynet.response(skynet.pack)
            skynet.error("=====watchdog.lua=>skynet.dispatch: after skynet.response")
            myret(true)

            -- skynet.ret 立即回应
			--skynet.ret(skynet.pack(f(subcmd, ...)))
		end
	end)

	gate = skynet.newservice("gate")
end)
