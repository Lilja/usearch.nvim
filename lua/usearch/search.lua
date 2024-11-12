local M = {}

--- @param regex string
--- @param ignore string|nil
--- @return { data: { file_path: string, line_no: string }[], error: string | string[] | nil }
function M.search(regex, ignore)
	local rg_args = {
		"--color=never",
		"--no-heading",
		"--with-filename",
		"--line-number",
		"--column",
	}

	local rg_flags = table.concat(rg_args, " ")
	if ignore ~= nil and ignore ~= "" then
		rg_flags = rg_flags .. " -g '!" .. ignore .. "'"
	end
	local cmd = "rg " .. rg_flags .. " " .. "'" .. regex .. "'" .. " 2>&1; echo $?"
	local handle = io.popen(cmd)
	if handle == nil then
		return { data = {}, error = { "Failed to execute command", cmd } }
	end
	local lines = {}
	local last_line = nil
	for line in handle:lines() do
		table.insert(lines, line)
		last_line = line
	end
	handle:close()

	-- The result is the output, but will now contain the exit code as the last line
	-- We need to remove the last line
	local result = table.concat(lines, "\n")

	if tonumber(last_line) ~= 0 then
		return { data = {}, error = { "Failed to execute command", unpack(lines), cmd } }
	end

	--- @type { file_path: string, line_no: string }
	local matches = {}

	for s in result:gmatch("[^\r\n]+") do
		if s == "0" then
			break
		end
		local m = process_result_row(vim.loop.cwd(), s, regex)
		table.insert(matches, m)
	end

	return { data = matches, error = nil }
end

--- @param cwd string
--- @param row string
--- @param search string
--- @return { file_path: string, line_no: string }
function process_result_row(cwd, row, search)
	local file_path = nil
	local line_no = nil
	local column_no = nil
	local idx = 0
	local matches = {}
	for word in string.gmatch(row, "([^:]+)") do
		if idx > 3 then
			break
		end
		if idx == 0 then
			file_path = cwd .. "/" .. word
		end
		if idx == 1 then
			line_no = word
		end
		if idx == 2 then
			column_no = word
		end
		idx = idx + 1
	end
	if file_path == nil then
		error("File null")
	end
	return { ["file_path"] = file_path, ["line_no"] = line_no }
end

return M
