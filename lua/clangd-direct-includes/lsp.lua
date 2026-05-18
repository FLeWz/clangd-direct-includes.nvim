local json = vim.json
local shutting_down = false
local running = true

local function respond(id, result)
	local msg = json.encode({
		jsonrpc = "2.0",
		id = id,
		result = result,
	})

	io.write("Content-Length: " .. #msg .. "\r\n\r\n" .. msg)
	io.flush()
end

local function send(msg)
	local body = vim.json.encode(msg)

	io.write(
		"Content-Length: " .. #body .. "\r\n\r\n" .. body
	)

	io.flush()
end

local function read_request()
	local headers = {}
	local line = io.read("*l")

	if not line then
		return nil
	end

	while line ~= "" do
		local k, v = line:match("^(.-):%s*(.+)$")

		if k then
			headers[k:lower()] = v
		end

		line = io.read("*l")
		line = line:gsub("\r", "")
	end

	local len = tonumber(headers["content-length"])
	if not len then
		return nil
	end

	local body = io.read(len)

	return json.decode(body)
end

local function handle(req)
	if req.method == "initialize" then
		respond(req.id, {
			capabilities = {
				codeActionProvider = true,
			}
		})
		return
	end

	if req.method == "shutdown" then
		shutting_down = true
		respond(req.id, nil)
		return
	end

	if req.method == "exit" then
		running = false

		if shutting_down then
			os.exit(0)
		else
			os.exit(1)
		end
	end

	if req.method ~= "textDocument/codeAction" then
		return
	end

	local uri = req.params.textDocument.uri
	local symbol = nil
	local request_id = math.random(100000, 999999)

	send({
		jsonrpc = "2.0",
		id = request_id,
		method = "clangd-direct-includes/requestSymbol",
		params = {
			textDocument = { uri = uri },
			position = req.params.range.start,
		}
	})

	while true do
		local r = read_request()

		if r and r.id == request_id then
			symbol = r.result
			break
		end
	end

	if not symbol then
		respond(req.id, {})
		return
	end

	respond(req.id, symbol)
end

while running do
	local req = read_request()
	if not req then
		break
	end

	handle(req)
end
