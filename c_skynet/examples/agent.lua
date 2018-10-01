local skynet = require "skynet"
local socket = require "skynet.socket"
local sproto = require "sproto"
local sprotoloader = require "sprotoloader"

local WATCHDOG
local host
local send_request

local CMD = {}
local REQUEST = {}
local client_fd

function REQUEST:get()
	skynet.error("agent.lua=>REQUEST:get, what=%s", self.what)
	local r = skynet.call("SIMPLEDB", "lua", "get", self.what)
	return { result = r }
end

function REQUEST:set()
	local str = string.format("what=%s, value=%s", self.what, self.value)
	skynet.error("agent.lua=>REQUEST:set," .. str)
	local r = skynet.call("SIMPLEDB", "lua", "set", self.what, self.value)
end

function REQUEST:handshake()
	skynet.error("agent.lua=>REQUEST:handshake")
	return { msg = "Welcome to skynet, agent will send mynotify every 5 sec." }
end

function REQUEST:quit()
	skynet.error("agent.lua=>REQUEST:quit")
	skynet.call(WATCHDOG, "lua", "close", client_fd)
end

local function request(name, args, response)
	local str = string.format("name=%s,response=%s",
							  name, response)
	skynet.error("agent.lua=>request:" .. str)
	local f = assert(REQUEST[name])
	local r = f(args)
	 --reponse是host:dispatch函数的第四个返回值，
	 --reponse是一个函数，用于生成sproto请求的回应包(即proto.lua 中 c2s类 特定某个协议的response结构)
	if response then
		return response(r)
	end
end

local function send_package(pack)
	skynet.error("agent.lua=>send_package: client_fd=", client_fd)
	local package = string.pack(">s2", pack)
	socket.write(client_fd, package)
end

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg, sz)
		return host:dispatch(msg, sz)
	end,
	dispatch = function (fd, _, type, ...)
		assert(fd == client_fd)	-- You can use fd to reply message
		skynet.ignoreret()	-- session is fd, don't call skynet.ret
		--skynet.trace()
		if type == "REQUEST" then
			skynet.error("agent.lua=>(skynet.register_protocol) dispatch: type=REQUEST, fd=", fd)
			local ok, result  = pcall(request, ...)
			--skynet.error("agent.lua=> after pcall, ok=", ok)
			if ok then
				--skynet.error("agent.lua=> after pcall, before if result")
				if result then
					-- result 是由request函数生成的回应包
					skynet.error("agent.lua=>before send_package,dispatch:type=REQUEST, fd=", fd)

					--发送sproto请求的回应包
					send_package(result)
				end
			else
				--skynet.error(result)
				skynet.error("agent.lua=> pcall fail,client_fd=", client_fd)
			end
		else
			assert(type == "RESPONSE")
			error "This example doesn't support request client"
		end
	end
}

function CMD.start(conf)
	local str = string.format("client=%d, gate=%s, watchdog=%s",
							  conf.client, conf.gate, conf.watchdog)
	skynet.error("agent.lua=>CMD.start, " .. str)
	local fd = conf.client
	local gate = conf.gate
	WATCHDOG = conf.watchdog
	-- slot 1,2 set at main.lua
	host = sprotoloader.load(1):host "package"

	--生成一个函数，用于将s2c消息打包成数据包
	send_request = host:attach(sprotoloader.load(2))
	skynet.fork(function()
		while true do
			skynet.error("agent.lua=>before send_package, skynet.fork:send_request")

			--主动发送sproto 消息包
			send_package(send_request "mynotify")
			skynet.sleep(500)
		end
	end)

	client_fd = fd
	skynet.call(gate, "lua", "forward", fd)
	skynet.error("agent.lua=> CMD.start: after call gate")
end

function CMD.disconnect()
	-- todo: do something before exit
	skynet.error("agent.lua=>CMD.disconnect")
	skynet.exit()
end

skynet.start(function()
	skynet.error("agent.lua=>skynet.start")
	skynet.dispatch("lua", function(_,_, command, ...)
		--skynet.trace()
		skynet.error("agent.lua=>(skynet.start) skynet.dispatch: command=", command)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
