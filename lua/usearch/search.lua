local M = {}

--- @param search string
--- @param ignore string|nil
--- @return { data: {elapsed: string, output: RipgrepSearchOutput[]} | nil, error: string | string[] | nil }
function M.search_with_json(search, ignore)
	-- Perform a search with ripgrep using --json flag.
	-- This will return a more detailed output that we are able to later highlight in neovim.
	local rg_args = {
		"--json",
	}
	local rg_flags = table.concat(rg_args, " ")
	if ignore ~= nil and ignore ~= "" then
		rg_flags = rg_flags .. " -g '!" .. ignore .. "'"
	end
	local cmd = "rg " .. rg_flags .. " '" .. search .. "' 2>&1; echo $?"
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
	local elapsed = 0

	for _, result in ipairs(cmd_lines) do
		if result["type"] == "match" then
			table.insert(matches, result)
		end
		if result["type"] == "summary" then
			elapsed = result["data"]["elapsed_total"]["human"]
		end
	end

	-- Finally, we can return the appropriate data
	--- @type RipgrepSearchOutput[]
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
				start = submatch["start"],
				finish = submatch["end"],
			})
		end

		table.insert(search_output, {
			file_path = file_path,
			lines = lines,
			line_number = line_number,
			submatches = submatches,
		})
	end

	local data = {
		elapsed = elapsed,
		output = search_output,
	}

	return { data = data, error = nil }
end

return M
