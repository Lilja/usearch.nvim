local M = {}

--- Changes the contents of a file_path.
--- The changes are a list of line numbers and the new content to replace the line with.
--- @param file_path string
--- @param changes { [number]: string }
--- @return number
function M.open_file_and_change_it(file_path, changes)
	local buf = vim.fn.bufadd(file_path)
	vim.fn.bufload(buf)

	for line_no, new_content in pairs(changes) do
		-- Add -1 to the line number as the buffer is 0 indexed and the line numbers from ripgrep are 1 indexed
		local line_no_0i = line_no - 1
		vim.api.nvim_buf_set_lines(buf, line_no_0i, line_no_0i + 1, false, { new_content })
	end

	local undo_seq_cur = -1

	-- Save the buffer
	vim.api.nvim_buf_call(buf, function()
		vim.cmd("write")
		-- Save the undo number
		undo_seq_cur = vim.fn.undotree(buf).seq_cur
	end)

	-- Close the buffer
	vim.api.nvim_buf_delete(buf, { force = true })
	return undo_seq_cur
end

--- Rollback the changes made to a file_path
--- @param file_path string
--- @param seq_cur number
function M.rollback_file(file_path, seq_cur)
	local buf = vim.fn.bufadd(file_path)
	vim.fn.bufload(buf)

	-- Restore the buffer to the state it was before the search and replace
	vim.api.nvim_buf_call(buf, function()
		local buf_seq_cur = vim.fn.undotree(buf).seq_cur
		if buf_seq_cur == seq_cur then
			-- Our stored seq_cur is the same as the current seq_cur.
			-- Which means that if we undo now, we will undo the changes we made.
			vim.cmd("undo")
			vim.cmd("write")
		end
	end)

	-- Close the buffer
	vim.api.nvim_buf_delete(buf, { force = true })
end

--- Perform a search and replace on a file_path.
--- The changes are a list of line numbers and the new content to replace the line with.
--- @param file_path string
--- @param line_numbers number[]
--- @param search string
--- @param replacer string
--- @return { data: { [number]: string } | nil, error: string[] | nil }
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
		-- Let's use # as the delimiter for the sed command to avoid escaping the slashes in the strings
		-- Also, we are performing the replace globally, as we want to replace all
		-- occurrences of the search string in the line.
		-- Hence, we use the g flag at the end of the sed command.
		local sed_replace_command = "sed -E 's#" .. search .. "#" .. replacer .. "#g'"

		-- We want to pipe the output of the first command to the second command,
		-- we don't want to do the replacement in the file,
		-- As we want neovim to perform the replacement, making undo/redo easier for the user.
		-- Finally, we want to print the exit code of the command, so we can check if the command was successful.
		local sed_command = sed_read_line_command .. " | " .. sed_replace_command .. " 2>&1 ; echo $?"

		-- Finally, execute the command and get the output
		local handle = io.popen(sed_command)
		if handle == nil then
			return { data = nil, error = { "Failed to execute command", sed_command } }
		end
		local lines = {}
		local last_line = nil
		for line in handle:lines() do
			table.insert(lines, line)
			last_line = line
		end
		handle:close()

		local result = lines[1]

		if tonumber(last_line) ~= 0 then
			return { data = nil, error = { "Failed to execute command", result, sed_command } }
		end

		changes[line_no] = result
	end

	return { data = changes, error = nil }
end

--- Perform a search and replace on contents from stdin
--- @param contents string
--- @param search string
--- @param replacer string
function M.replace_in_line(contents, search, replacer)
	local sed_command = "echo '" .. contents .. "' | sed -E 's#" .. search .. "#" .. replacer .. "#g'; echo $?"

	local handle = io.popen(sed_command)
	if handle == nil then
		return { data = nil, error = { "Failed to execute command", sed_command } }
	end
	local lines = {}
	local last_line = nil
	for line in handle:lines() do
		table.insert(lines, line)
		last_line = line
	end
	handle:close()

	local result = lines[1]

	if tonumber(last_line) ~= 0 then
		return { data = nil, error = { "Failed to execute command", result, sed_command } }
	end

	return { data = result, error = nil }
end

return M
