local M = {}


--- Changes the contents of a file_path. The changes are a list of line numbers and the new content to replace the line with.
--- @param file_path string
--- @param changes { [number]: string }
function M.openFileAndChangeIt(file_path, changes)
	local buf = vim.api.nvim_create_buf(false, false)
	vim.api.nvim_buf_set_name(buf, file_path)
	-- Open the file, read the contents into the buffer
	local file = io.open(file_path, "r")

	if file == nil then
		error("File not found")
	end
	local contents = file:read("*a")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(contents, "\n"))

	for line_no, new_content in pairs(changes) do
		vim.api.nvim_buf_set_lines(buf, line_no, line_no, false, { new_content })
	end
end

function M.sedContents(contents, search, replacer)
	local echoCmd = "echo '" .. contents .. "'"
	local sed = "sed -E s#" .. search .. "#" .. replacer .. "#g"
	local cmd = echoCmd .. " | " .. sed
	-- print(cmd)
	local handle = io.popen(cmd)
	if handle == nil then
		error("Stuff")
	end
	local result = handle:read("*a")
	-- print(result)
end



return M
