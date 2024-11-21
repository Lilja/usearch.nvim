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
--- @param next "search" | "replace" | "ignore" | "output" | "debug"
--- @param prev "search" | "replace" | "ignore" | "output" | "debug"
function M.bind_keybinds_to_buf(buf, next, prev)
	local cmdNext = ":lua require('" .. state.pkg .. ".ui').switch_to_window('" .. next .. "')<CR>"
	local cmdPrev = ":lua require('" .. state.pkg .. ".ui').switch_to_window('" .. prev .. "')<CR>"
	vim.api.nvim_buf_set_keymap(buf, "n", "<Tab>", cmdNext, { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, "n", "<S-Tab>", cmdPrev, { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, "n", "<C-n>", cmdNext, { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, "n", "<C-p>", cmdPrev, { noremap = true, silent = true })

	-- Bind <leader>R to perform the search and replace
	-- TODO: This should be a keybind that is set in the user's config
	-- TODO: This should not call a function in the UI module, but rather in the main module
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
	if vim.api.nvim_win_is_valid(state.debugWin) then
		vim.api.nvim_win_close(state.debugWin, true)
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
	if vim.api.nvim_buf_is_loaded(state.debugBuf) then
		vim.api.nvim_buf_delete(state.debugBuf, { force = true })
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
	if state.search_regex == nil or state.search_regex == "" then
		return
	end
	local matchesResult = search.search_with_json(state.search_regex, state.ignore)
	if matchesResult.error ~= nil then
		state.error = matchesResult.error
		M.reduce_output_state()
		return
	end
	local matches = matchesResult.data
	if matches == nil then
		state.error = { "Failed to search" }
		M.reduce_output_state()
		return
	end
	state.grouped_search_outputs = process.group_up_search_outputs_by_filename(matches)

	M.reduce_output_state()
end

function M.perform_replace()
	if state.search_regex == nil or state.search_regex == "" then
		return
	end

	if state.replace_regex ~= nil then
		for file_path, result in pairs(state.last_matches.grouped_matches) do
			-- Flatten out the results to a number[]
			local line_numbers = {}
			for _, line_no in pairs(result.matches) do
				table.insert(line_numbers, line_no)
			end
			local replaceResult = replace.perform_replace_on_file_path(file_path, line_numbers, state.search_regex, state.replace_regex)
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

	-- Create debug buffer for the floating window
	local debugBuf = vim.api.nvim_create_buf(false, false)
	vim.api.nvim_buf_set_option(debugBuf, "buftype", "nofile")

	M.listen_for_mode_change_in_buf(searchBuf, outputBuf, function(contents)
		local regex = contents[1]
		state.initial = false
		state.search_regex = regex
		state.error = nil
		perform_search()
	end)
	M.listen_for_mode_change_in_buf(replaceBuf, outputBuf, function(contents)
		state.initial = false
		state.replace_regex = contents[1]
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

	-- Create the debug buffer, it's located below the ignore buffer
	local debugWin = vim.api.nvim_open_win(debugBuf, true, {
		relative = "editor",
		width = 40,
		height = 9,
		row = 10,
		col = 10,
		style = "minimal",
		border = "rounded",
		title = "Debug",
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
	M.bind_keybinds_to_buf(ignoreBuf, "debug", "replace")
	M.bind_keybinds_to_buf(debugBuf, "output", "ignore")
	M.bind_keybinds_to_buf(outputBuf, "search", "debug")

	state.searchWin = searchWin
	state.replaceWin = replaceWin
	state.outputWin = outputWin
	state.ignoreWin = ignoreWin
	state.debugWin = debugWin

	state.searchBuf = searchBuf
	state.replaceBuf = replaceBuf
	state.outputBuf = outputBuf
	state.ignoreBuf = ignoreBuf
	state.debugBuf = debugBuf

	M.bind_escape_to_all_buffers()

	if mode == "toggle" then
		if state.search_regex ~= nil then
			vim.api.nvim_buf_set_lines(searchBuf, 0, -1, false, { state.search_regex })
		end
		if state.replace_regex ~= nil then
			vim.api.nvim_buf_set_lines(replaceBuf, 0, -1, false, { state.replace_regex })
		end
		if state.ignore ~= nil then
			vim.api.nvim_buf_set_lines(ignoreBuf, 0, -1, false, { state.ignore })
		end
		perform_search()
	end

	M.debug_buf_print({
		"searchWin: " .. searchWin,
		"replaceWin: " .. replaceWin,
		"outputWin: " .. outputWin,
		"ignoreWin: " .. ignoreWin,
		"debugWin: " .. debugWin,
		"searchBuf: " .. searchBuf,
		"replaceBuf: " .. replaceBuf,
		"outputBuf: " .. outputBuf,
		"ignoreBuf: " .. ignoreBuf,
		"debugBuf: " .. debugBuf,
	})

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
	elseif win == "debug" then
		vim.api.nvim_set_current_win(state.debugWin)
	end
end

--- @param data_to_render string[]
--- @param highlight_callback nil | fun(): nil
function M.render_output_state(data_to_render, highlight_callback)
	local outputBuf = state.outputBuf
	if outputBuf ~= -1 then
		vim.api.nvim_buf_set_lines(outputBuf, 0, -1, false, data_to_render)
	end
	if highlight_callback ~= nil then
		highlight_callback()
	end
end

function M.preview_search_results()
	local so = search.search_with_json(state.search_regex, state.ignore)
	if so.error ~= nil then
		print(vim.inspect(so.error))
		error("Error")
	end

	local pso = process.process_search_output(state.search_regex, state.replace_regex, so.data)
	return process.group_up_search_outputs_by_filename(pso)
end

function M.reduce_output_state()
	if state.initial then
		return M.render_output_state(ui_states.initial_state(), nil)
	end

	if state.error ~= nil then
		return M.render_output_state(ui_states.display_error(), nil)
	end

	if state.search_regex == nil or #state.grouped_search_outputs == 0 then
		local s = ui_states.empty_state()
		return M.render_output_state(s, nil)
	end

	if state.grouped_search_outputs ~= nil then
		local grouped_up_results = M.preview_search_results()
		local result = ui_states.display_matches_v2(grouped_up_results)
		return M.render_output_state(result.lines, result.callback)
	end
end

--- @param contents string[]
function M.debug_buf_print(contents)
	local debugBuf = state.debugBuf
	if debugBuf ~= -1 then
		vim.api.nvim_buf_set_lines(debugBuf, 0, -1, false, contents)
	end
end

return M
