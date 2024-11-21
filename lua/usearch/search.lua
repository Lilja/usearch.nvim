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

	-- According to ripgrep documentation, the exit code is 0 if there are matches, 1 if there are no matches, and 2 if there is an error
	if tonumber(last_line) == 2 then
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

--- @alias Submatch { match: string, start: number, finish: number }
--- @alias SearchOutput { file_path: string, lines: string, line_number: number, submatches: Submatch[] }
--- @param search string
--- @return { data: SearchOutput[] | nil, error: string | string[] | nil }
function M.search_with_json(search)
	-- Perform a search with ripgrep using --json flag. This will return a more detailed output that we are able to later highlight in neovim.
	local cmd = "rg --json " .. "'" .. search .. "' test/references.txt" .. " 2>&1; echo $?"
	local handle = io.popen(cmd)
	if handle == nil then
		return { data = {}, error = { "Failed to execute command", cmd } }
	end
	local cmd_lines = {}
	local last_line = nil
	for line in handle:lines() do
		-- If the line starts with "{" then it is a json output line
		if line:sub(1, 1) == "{" then
			local row = vim.fn.json_decode(line)
			table.insert(cmd_lines, row)
		end
		last_line = line
	end
	handle:close()

	if tonumber(last_line) == 2 then
		return { data = nil, error = { "Failed to execute command", unpack(cmd_lines), cmd } }
	end

	-- Now we need to filter out the certain results we are not interested in.
	-- We are only interested in the results that have a "type" equal to "match"
	local matches = {}

	for _, result in ipairs(cmd_lines) do
		if result["type"] == "match" then
			table.insert(matches, result)
		end
	end

	-- Finally, we can return the appropriate data
	--- @type SearchOutput[]
	local search_output = {}

	for _, match in ipairs(matches) do
		local file_path = match["data"]["path"]["text"]
		local lines = match["data"]["lines"]["text"]
		local line_number = match["data"]["line_number"]
		local raw_submatches = match["data"]["submatches"]

		--- @type Submatch[]
		local submatches = {}
		for _, submatch in ipairs(raw_submatches) do
			table.insert(submatches, {
				match = submatch["match"]["text"],
				start = submatch["start"] + 1,
				finish = submatch["end"] + 1,
			})
		end

		table.insert(search_output, {
			file_path = file_path,
			lines = lines,
			line_number = line_number,
			submatches = submatches,
		})
	end

	return { data = search_output, error = nil }
end

return M
