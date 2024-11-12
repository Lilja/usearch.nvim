local state = require("usearch.state")
local ui_states = require("usearch.ui_states")
local search = require("usearch.search")
local process = require("usearch.process")
local replace = require("usearch.replace")

local M = {}

--- @param buf number
--- @param outputBuf number
--- @param callback fun(contents: string[]): nil
function M.listen_for_mode_change_in_buf(buf, outputBuf, callback)
	-- Listen for input changes in the buffer
	-- We want to display the search results in the output buffer, but only when the user is done typing.
	-- The InsertLeave event is triggered when the user leaves insert mode, so we can use that to detect when the user is done typing.

	vim.api.nvim_create_autocmd("InsertLeave", {
		buffer = buf,
		callback = function()
			local bufferContents = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			callback(bufferContents)
		end,
	})
end

--- @param buf number
--- @param next "search" | "replace" | "ignore" | "output"
--- @param prev "search" | "replace" | "ignore" | "output"
function M.bind_keybinds_to_buf(buf, next, prev)
	local cmdNext = ":lua require('" .. state.pkg .. ".ui').switch_to_window('" .. next .. "')<CR>"
	local cmdPrev = ":lua require('" .. state.pkg .. ".ui').switch_to_window('" .. prev .. "')<CR>"
	vim.api.nvim_buf_set_keymap(buf, "n", "<Tab>", cmdNext, { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, "n", "<S-Tab>", cmdPrev, { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, "n", "<C-n>", cmdNext, { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, "n", "<C-p>", cmdPrev, { noremap = true, silent = true })

	-- Bind <leader>R to perform the search and replace
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"<leader>R",
		":lua require('" .. state.pkg .. ".ui').perform_replace()<CR>",
		{ noremap = true, silent = true }
	)
end

function M.close_window()
	if vim.api.nvim_win_is_valid(state.searchWin) then
		vim.api.nvim_win_close(state.searchWin, true)
	end
	if vim.api.nvim_win_is_valid(state.replaceWin) then
		vim.api.nvim_win_close(state.replaceWin, true)
	end
	if vim.api.nvim_win_is_valid(state.outputWin) then
		vim.api.nvim_win_close(state.outputWin, true)
	end
	if vim.api.nvim_win_is_valid(state.ignoreWin) then
		vim.api.nvim_win_close(state.ignoreWin, true)
	end

	if vim.api.nvim_buf_is_loaded(state.searchBuf) then
		vim.api.nvim_buf_delete(state.searchBuf, { force = true })
	end
	if vim.api.nvim_buf_is_loaded(state.replaceBuf) then
		vim.api.nvim_buf_delete(state.replaceBuf, { force = true })
	end
	if vim.api.nvim_buf_is_loaded(state.outputBuf) then
		vim.api.nvim_buf_delete(state.outputBuf, { force = true })
	end
	if vim.api.nvim_buf_is_loaded(state.ignoreBuf) then
		vim.api.nvim_buf_delete(state.ignoreBuf, { force = true })
	end
end

function M.bind_escape_to_all_buffers()
	for _, buf in ipairs({ state.searchBuf, state.replaceBuf, state.outputBuf, state.ignoreBuf }) do
		vim.api.nvim_buf_set_keymap(
			buf,
			"n",
			"<Esc>",
			":lua require('" .. state.pkg .. ".ui').close_window()<CR>",
			{ noremap = true, silent = true }
		)
	end
end

--- @param results { file_path: string, line_no: string }[]
function render_search_results(results)
	local lines = {}
	for _, result in ipairs(results) do
		table.insert(lines, result["file_path"])
		table.insert(lines, result["line_no"])
	end
	return lines
end

function perform_search()
	if state.regex == nil or state.regex == "" then
		return
	end
	local matchesResult = search.search(state.regex, state.ignore)
	if matchesResult.error ~= nil then
		state.error = matchesResult.error
		M.reduce_output_state()
		return
	end
	local matches = matchesResult.data
	state.last_matches = process.group_up_matches_and_craft_meta_data(matches)

	M.reduce_output_state()
end

function perform_replace()
	if state.regex == nil or state.regex == "" then
		return
	end

	if state.replacer ~= nil then
		for file_path, result in pairs(state.last_matches.grouped_matches) do
			-- Flatten out the results to a number[]
			local line_numbers = {}
			for _, line_no in pairs(result.matches) do
				table.insert(line_numbers, line_no)
			end
			local replaceResult = replace.perform_replace_on_file_path(file_path, line_numbers, state.regex, state.replacer)
			if replaceResult.error ~= nil then
				state.error = replaceResult.error
				M.reduce_output_state()
				return
			end
			local data = replaceResult.data
			if data == nil then
				state.error = { "Failed to replace" }
				M.reduce_output_state()
				return
			end
			replace.open_file_and_change_it(file_path, data)
		end
	end
end

--- @param mode "new" | "toggle"
function M.drawUI(mode)
	-- Create search buffer for the floating window
	local searchBuf = vim.api.nvim_create_buf(false, false)
	vim.api.nvim_buf_set_option(searchBuf, "buftype", "nofile")

	-- Create replace buffer for the floating window
	local replaceBuf = vim.api.nvim_create_buf(false, false)
	vim.api.nvim_buf_set_option(replaceBuf, "buftype", "nofile")

	-- Create ignore buffer for the floating window
	local ignoreBuf = vim.api.nvim_create_buf(false, false)
	vim.api.nvim_buf_set_option(replaceBuf, "buftype", "nofile")

	-- Create output buffer for the floating window
	local outputBuf = vim.api.nvim_create_buf(false, false)
	vim.api.nvim_buf_set_option(outputBuf, "buftype", "nofile")

	M.listen_for_mode_change_in_buf(searchBuf, outputBuf, function(contents)
		local regex = contents[1]
		state.initial = false
		state.regex = regex
		state.error = nil
		perform_search()
	end)
	M.listen_for_mode_change_in_buf(replaceBuf, outputBuf, function(contents)
		state.initial = false
		state.replacer = contents[1]
		state.error = nil
		perform_search()
	end)
	M.listen_for_mode_change_in_buf(ignoreBuf, outputBuf, function(contents)
		state.initial = false
		state.ignore = contents[1]
		state.error = nil
		perform_search()
	end)

	-- Create the search buffer, it's located on the top of the screen
	local searchWin = vim.api.nvim_open_win(searchBuf, true, {
		relative = "editor",
		width = 40,
		height = 1,
		row = 1,
		col = 10,
		style = "minimal",
		border = "rounded",
		title = "Search",
		title_pos = "center",
	})
	-- Next, create the replace buffer, it's located below the search buffer
	local replaceWin = vim.api.nvim_open_win(replaceBuf, true, {
		relative = "editor",
		width = 40,
		height = 1,
		row = 4,
		col = 10,
		style = "minimal",
		border = "rounded",
		title = "Replace",
		title_pos = "center",
	})

	-- Create the ignore buffer, it's located below the replace buffer
	local ignoreWin = vim.api.nvim_open_win(ignoreBuf, true, {
		relative = "editor",
		width = 40,
		height = 1,
		row = 7,
		col = 10,
		style = "minimal",
		border = "rounded",
		title = "Ignore",
		title_pos = "center",
	})

	-- Finally, create the floating window that will show the results of the search and replace
	-- It's located to the right of both the search and replace buffers
	local outputWin = vim.api.nvim_open_win(outputBuf, true, {
		relative = "editor",
		width = 80,
		height = 30,
		row = 1,
		col = 52,
		style = "minimal",
		border = "rounded",
		title = "Search results",
		title_pos = "center",
	})

	-- Bind keybinds to the buffers, you should navigate vertically and then switch to the output buffer, and back to the search buffer.
	M.bind_keybinds_to_buf(searchBuf, "replace", "output")
	M.bind_keybinds_to_buf(replaceBuf, "ignore", "search")
	M.bind_keybinds_to_buf(ignoreBuf, "output", "replace")
	M.bind_keybinds_to_buf(outputBuf, "search", "ignore")

	state.searchWin = searchWin
	state.replaceWin = replaceWin
	state.outputWin = outputWin
	state.ignoreWin = ignoreWin

	state.searchBuf = searchBuf
	state.replaceBuf = replaceBuf
	state.outputBuf = outputBuf
	state.ignoreBuf = ignoreBuf

	M.bind_escape_to_all_buffers()

	if mode == "toggle" then
		if state.regex ~= nil then
			vim.api.nvim_buf_set_lines(searchBuf, 0, -1, false, { state.regex })
		end
		if state.replacer ~= nil then
			vim.api.nvim_buf_set_lines(replaceBuf, 0, -1, false, { state.replacer })
		end
		if state.ignore ~= nil then
			vim.api.nvim_buf_set_lines(ignoreBuf, 0, -1, false, { state.ignore })
		end
		perform_search()
	end

	-- Focus the search window
	vim.api.nvim_set_current_win(searchWin)
	M.reduce_output_state()
end

--- @param win "search" | "replace" | "ignore" | "output"
function M.switch_to_window(win)
	if win == "search" then
		vim.api.nvim_set_current_win(state.searchWin)
	elseif win == "replace" then
		vim.api.nvim_set_current_win(state.replaceWin)
	elseif win == "ignore" then
		vim.api.nvim_set_current_win(state.ignoreWin)
	elseif win == "output" then
		vim.api.nvim_set_current_win(state.outputWin)
	end
end

--- @param data_to_render string[]
function M.render_output_state(data_to_render)
	local outputBuf = state.outputBuf
	if outputBuf ~= -1 then
		vim.api.nvim_buf_set_lines(outputBuf, 0, -1, false, data_to_render)
	end
end

function M.reduce_output_state()
	if state.initial then
		return M.render_output_state(ui_states.initial_state())
	end

	if state.error ~= nil then
		print(vim.inspect(state.error))
		return M.render_output_state(ui_states.display_error())
	end

	if state.regex == nil or state.last_matches.matches_count == 0 then
		local s = ui_states.empty_state()
		return M.render_output_state(s)
	end

	if state.last_matches ~= nil then
		return M.render_output_state(ui_states.display_matches())
	end
end

return M
