local M = {}


--- Changes the contents of a file_path. The changes are a list of line numbers and the new content to replace the line with.
--- @param file_path string
--- @param changes { [number]: string }
function M.open_file_and_change_it(file_path, changes)
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

--- Perform a search and replace on a file_path. The changes are a list of line numbers and the new content to replace the line with.
--- @param file_path string
--- @param line_numbers number[]
--- @param search string
--- @param replacer string
--- @return { line_no: string }[]
function M.perform_replace_on_file_path(file_path, line_numbers, search, replacer)
	--- @type { [number]: string }
	local changes = {}

	for _, line_no in pairs(line_numbers) do
		-- Open the file using sed and get to the specific line number
		local sed_read_line_command = "sed -n " .. line_no .. "p " .. file_path
		--
		-- Next, pipe the output of the command to sed to replace the search string with the replacer string
		-- We assume the search string is a modern regex variant, so we use the -E flag
		-- We also assume the replacer string is a modern regex variant, so we use the -E flag
		-- Let's use # as the delimiter for the sed command to avoid escaping the slashes in the search and replacer strings
		-- Also, we are performing the replace globally, as we want to replace all occurrences of the search string in the line.
		-- Hence, we use the g flag at the end of the sed command.
		local sed_replace_command = "sed -E 's#" .. search .. "#" .. replacer .. "#g'"

		-- We want to pipe the output of the first command to the second command, we don't want to do the replacement in the file,
		-- As we want neovim to perform the replacement, making undo/redo easier for the user.
		-- We also want to remove the newline character at the end of the line, as we will be replacing the entire line.
		local sed_command = sed_read_line_command .. " | " .. sed_replace_command .. " | tr -d '\\n'"

		print("The command is: " .. sed_command)

		-- Finally, execute the command and get the output
		local handle = io.popen(sed_command)
		if handle == nil then
			error("Failed to execute command")
		end
		local result = handle:read("*a")
		handle:close()
		table.insert(changes, { line_no = result })
	end

	print("The changes are:")
	print(vim.inspect(changes))
end

return M
