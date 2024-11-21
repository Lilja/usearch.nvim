local ui = require("usearch.ui")
local process = require("usearch.process")
local search = require("usearch.search")

local M = {}

--- @param file_paths { [string]: boolean }
--- @return { [string]: "OK" | "OPEN_AND_MODIFIED" }
function M.detectModifiedFiles(file_paths)
	local bufs = vim.api.nvim_list_bufs()
	local openBufs = {}

	for _, buf in ipairs(bufs) do
		local path = vim.api.nvim_buf_get_name(buf)
		if path ~= "" then
			local modified = vim.api.nvim_get_option_value("modified", { buf = buf })
			if modified then
				table.insert(openBufs, path)
			end
		end
	end
	--- @type { [string]: "OK" | "OPEN_AND_MODIFIED" }
	local file_path_checks = {}
	for file_path_to_change, _ in pairs(file_paths) do
		for _, open_file_that_is_modified in ipairs(openBufs) do
			if file_path_to_change == open_file_that_is_modified then
				file_path_checks[file_path_to_change] = "OPEN_AND_MODIFIED"
				break
			end
		end
		if file_paths[file_path_to_change] == true then
			file_path_checks[file_path_to_change] = "OK"
		end
	end
	return file_path_checks
end

--- @param { file_path: string, line_no: string }
--- @return { [string]: { file_path: string, line_no: string } }
function M.groupSearches(matches)
	local grouped = {}
	for _, match in ipairs(matches) do
		local file_path = match["file_path"]
		if grouped[file_path] == nil then
			grouped[file_path] = {}
		end
		table.insert(grouped[file_path], match)
	end
	return grouped
end

function M.new_search()
	local state = require("usearch.state")
	state.reset_state()

	ui.drawUI("new")
end

function M.toggle_search()
	ui.drawUI("toggle")
end

return M
