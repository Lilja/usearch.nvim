local M = {}

--- @param regex string
--- @param ignore string|nil
--- @return { file_path: string, line_no: string }[]
function M.search(regex, ignore)
	local rg_args = {
		"--color=never",
		"--no-heading",
		"--with-filename",
		"--line-number",
		"--column",
	}

	local rg_flags = table.concat(rg_args, " ")
	if ignore ~= nil then
		rg_flags = rg_flags .. " -g '!" .. ignore .. "'"
	end
	local cmd = "rg " .. rg_flags .. " " .. regex
	print("Running command: " .. cmd)
	local handle = io.popen(cmd)
	if handle == nil then
		error("Stuff")
	end
	local result = handle:read("*a")

	--- @type { file_path: string, line_no: string }
	local matches = {}

	for s in result:gmatch("[^\r\n]+") do
		local m = process_result_row(vim.loop.cwd(), s, regex)
		table.insert(matches, m)
	end

	return matches
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
