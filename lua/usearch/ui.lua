local state = require("usearch.state")
local ui_states = require("usearch.ui_states")
local search = require("usearch.search")
local process = require("usearch.process")

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

function M.bind_tab_to_next_window(buf, currentWindow, nextWindow)
	local cmdNext = ":lua vim.api.nvim_set_current_win(" .. nextWindow .. ")<CR>"
	local cmdPrev = ":lua vim.api.nvim_set_current_win(" .. currentWindow .. ")<CR>"
	vim.api.nvim_buf_set_keymap(buf, "n", "<Tab>", cmdNext, { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, "n", "<S-Tab>", cmdPrev, { noremap = true, silent = true })
end

function M.closeWindow()
	for _, win in ipairs(state.windows) do
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
end

function M.bind_escape_to_all_buffers()
	for _, buf in ipairs(state.buffers) do
		vim.api.nvim_buf_set_keymap(
			buf,
			"n",
			"<Esc>",
			":lua require('" .. state.pkg .. ".ui').closeWindow()<CR>",
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

function M.drawUI()
	-- Create search buffer for the floating window
	local searchBuf = vim.api.nvim_create_buf(false, false)
	vim.api.nvim_buf_set_option(searchBuf, "buftype", "nofile")

	-- Create replace buffer for the floating window
	local replaceBuf = vim.api.nvim_create_buf(false, false)
	vim.api.nvim_buf_set_option(replaceBuf, "buftype", "nofile")

	-- Create output buffer for the floating window
	local outputBuf = vim.api.nvim_create_buf(false, false)
	vim.api.nvim_buf_set_option(outputBuf, "buftype", "nofile")

	M.listen_for_mode_change_in_buf(searchBuf, outputBuf, function(contents)
		print("Search contents changed!")
		local regex = contents[1]
		state.initial = false
		state.regex = regex
		if regex == nil or regex == "" then
			M.reduce_output_state()
			return
		end
		local matches = search.search(state.regex)
		state.last_matches = process.group_up_matches_and_craft_meta_data(matches)
		M.reduce_output_state()
	end)
	M.listen_for_mode_change_in_buf(replaceBuf, outputBuf, function(contents)
		state.initial = false
		print("Replace contents changed!")
		print(vim.inspect(contents))
		M.reduce_output_state()
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

	M.bind_tab_to_next_window(searchBuf, searchWin, replaceWin)
	M.bind_tab_to_next_window(replaceBuf, replaceWin, outputWin)
	M.bind_tab_to_next_window(outputBuf, outputWin, searchWin)

	state.windows = { searchWin, replaceWin, outputWin }
	state.buffers = { searchBuf, replaceBuf, outputBuf }

	state.searchWin = searchWin
	state.replaceWin = replaceWin
	state.outputWin = outputWin

	state.searchBuf = searchBuf
	state.replaceBuf = replaceBuf
	state.outputBuf = outputBuf

	M.bind_escape_to_all_buffers()

	-- Focus the search window
	vim.api.nvim_set_current_win(searchWin)
	M.reduce_output_state()
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

	if state.regex == nil or state.last_matches.matches_count == 0 then
		local s = ui_states.empty_state()
		return M.render_output_state(s)
	end

	if state.last_matches ~= nil then
		return M.render_output_state(ui_states.display_matches())
	end
end

return M
