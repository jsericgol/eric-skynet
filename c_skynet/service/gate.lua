local skynet = require "skynet"
local gateserver = require "snax.gateserver"

local watchdog
local connection = {}	-- fd -> connection : { fd , client, agent , ip, mode }
local forwarding = {}	-- agent -> connection

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
}

local handler = {}

function handler.open(source, conf)
	skynet.error("--------gate.lua=>handler.open, source:", source)
    skynet.error("--------gate.lua=>handler.open, conf:", conf)
    local str = string.format("port=%d, maxclient=%d,nodelay=%s",
                              conf.port, conf.maxclient, conf.nodelay)
    skynet.error("--------gate.lua=>handler.open, " .. str)
	watchdog = conf.watchdog or source
end

function handler.message(fd, msg, sz)
    skynet.error("-------gate.lua=>handler.message,fd=", fd)
	-- recv a package, forward it
	local c = connection[fd]
	local agent = c.agent

    local str = string.format("client=%d, fd=%d,",
                              c.client, fd)

	if agent then
		-- It's safe to redirect msg directly , gateserver framework will not free msg.
        local str2 = string.format("agent=%d", agent)
        skynet.error("===== gate.lua=>handler.message: before skynet.redirect," .. str .. str2)
		skynet.redirect(agent, c.client, "client", fd, msg, sz)
	else
        skynet.error("xxxxxxxx gate.lua=>handler.message: before skynet.send")
		skynet.send(watchdog, "lua", "socket", "data", fd, skynet.tostring(msg, sz))
		-- skynet.tostring will copy msg to a string, so we must free msg here.
		skynet.trash(msg,sz)
	end
end

function handler.connect(fd, addr)
    skynet.error("-------gate.lua=>handler.connect: ",
                 string.format("fd=%d  ip=%s", fd, addr))
	local c = {
		fd = fd,
		ip = addr,
	}
	connection[fd] = c
	skynet.send(watchdog, "lua", "socket", "open", fd, addr)
end

local function unforward(c)
    skynet.error("--------gate.lua=> unforward")
	if c.agent then
		forwarding[c.agent] = nil
		c.agent = nil
		c.client = nil
	end
end

local function close_fd(fd)
    skynet.error("--------gate.lua=> close_fd, fd=", fd)
	local c = connection[fd]
	if c then
		unforward(c)
		connection[fd] = nil
	end
end

function handler.disconnect(fd)
    skynet.error("--------gate.lua=> handler.disconnect,fd=",fd)
	close_fd(fd)
	skynet.send(watchdog, "lua", "socket", "close", fd)
    skynet.error("--------gate.lua=> handler.disconnect: after send watchdog")
end

function handler.error(fd, msg)
    print("--------gate.lua=> handler.error")
	close_fd(fd)
	skynet.send(watchdog, "lua", "socket", "error", fd, msg)
end

function handler.warning(fd, size)
    print("-------- handler.warning")
	skynet.send(watchdog, "lua", "socket", "warning", fd, size)
end

local CMD = {}

function CMD.forward(source, fd, client, address)
    local str = string.format("source=%s, fd=%d, client=%s, address=%s",
                              source, fd, client, address)
    skynet.error("--------gate.lua=> CMD.forward:" .. str)
	local c = assert(connection[fd])
	unforward(c)
	c.client = client or 0
	c.agent = address or source
	forwarding[c.agent] = c
	gateserver.openclient(fd)
end

function CMD.accept(source, fd)
    skynet.error("--------gate.lua=> CMD.accept")
	local c = assert(connection[fd])
	unforward(c)
	gateserver.openclient(fd)
end

function CMD.kick(source, fd)
    local str = string.format("source=%s, fd=%s", source, fd)
    skynet.error("--------gate.lua=> CMD.kick:" .. str)
	gateserver.closeclient(fd)
end

function handler.command(cmd, source, ...)
    local str = string.format("cmd=%s,source=%s", cmd, source)
    skynet.error("--------gate.lua=> handler.command: " .. str)
	local f = assert(CMD[cmd])
	return f(source, ...)
end

gateserver.start(handler)
