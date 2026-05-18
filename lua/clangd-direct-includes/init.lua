-- A client-side Neovim LSP code action provider for C/C++
-- for direct header includes.
--
-- Works alongside mason-installed clangd.

local defaults = {
	name = "clangd-direct-includes",
	filetypes = { "c", "cpp" },
}

local function extract_header(text)
	if not text then return nil end

	return text:match("provided by `%s*<(.-)>%s*`")
		or text:match("#include%s*<(.-)>")
		or text:match("`<(.-)>`")
		or text:match("([%w_/%-]+%.h)")
end

local function find_include_insertion(bufnr, header)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local include_pattern = '^#include%s*[<"]([^>"]+)[>"]'
	local system_include_pattern = '^#include%s*<([^>]+)>'
	local includes = {}

	for i, line in ipairs(lines) do
		local included = line:match(include_pattern)

		if included then
			if included == header then
				return nil
			end

			local is_system = line:match(system_include_pattern) ~= nil

			table.insert(includes, {
				line = i - 1,
				header = included,
				system = is_system,
			})
		end
	end

	if #includes == 0 then
		local insert_line = 0

		if lines[1] and lines[1]:match("^#pragma%s+once") then
			insert_line = 1
		end

		return insert_line
	end

	local target_system = true
	local last_matching = nil

	for _, inc in ipairs(includes) do
		if inc.system == target_system then
			last_matching = inc.line

			if header < inc.header then
				return inc.line
			end
		end
	end

	if last_matching then
		return last_matching + 1
	end

	return includes[#includes].line + 1
end

local function build_include_action(bufnr, uri, header)
	local insert_line = find_include_insertion(bufnr, header)

	if insert_line == nil then
		return nil
	end

	return {
		title = "Add include <" .. header .. ">",
		kind = "quickfix",
		edit = {
			changes = {
				[uri] = {
					{
						newText = "#include <" .. header .. ">\n",
						range = {
							start = { line = insert_line, character = 0 },
							["end"] = { line = insert_line, character = 0 },
						},
					},
				},
			},
		},
	}
end

vim.lsp.handlers["clangd-direct-includes/requestSymbol"] = function(err, params, ctx)
	local uri = params.textDocument.uri
	local pos = params.position or { line = 0, character = 0 }
	local bufnr = vim.uri_to_bufnr(uri)

	local result = vim.lsp.buf_request_sync(bufnr, "textDocument/hover", {
		textDocument = { uri = uri },
		position = pos,
	}, 1000)

	if not result then
		return {}
	end

	local client_result = next(result) and select(2, next(result))
	local res = client_result and client_result.result
	local text = ""

	if res and res.contents then
		local c = res.contents

		if type(c) == "string" then
			text = c
		elseif c.value then
			text = c.value
		end
	end

	local header = extract_header(text)
	if header then
		local action = build_include_action(bufnr, uri, header)
		if action then
			return { action }
		end
	end

	return {}
end

local root = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)))
local lsp = root .. "/" .. defaults.name .. "/lsp.lua"

vim.lsp.config(defaults.name, {
	cmd = {
		"nvim",
		"-l",
		lsp,
	},
	filetypes = defaults.filetypes,
	single_file_support = true,
})
