local state = require("usearch.state")

local M = {}

function M.empty_state()
	return {
		"No search results found.",
		"Please enter another search term or exit by pressing <Esc>.",
	}
end

function M.initial_state()
	return {
		"Welcome to " .. state.pkg .. "!",
		"",
		"Begin by entering a search term in the search buffer.",
	}
end

function M.display_matches()
	local matches = state.last_matches
	local lines = {}
	table.insert(lines, "Matches found: " .. matches["matches_count"])
	table.insert(lines, "")
	for file_path, group in pairs(matches["grouped_matches"]) do
		table.insert(lines, "File: " .. file_path)
		table.insert(lines, "Matches: " .. group["count"])
		table.insert(lines, "")
	end
	return lines
end

--- @param grouped_search_outputs GroupedSearchOutput[]
--- @return { lines: string[], callback: function }
function M.display_matches_v2(grouped_search_outputs)
	local ns = vim.api.nvim_create_namespace("usearch")
	local outputBuf = state.outputBuf
	local lines = {}

	--- @type Offset[][]
	local search_offsets = {}

	--- @type Offset[][] | nil
	local replace_offsets = nil

	local highlight_callback = function()
		for line, offsets in ipairs(search_offsets) do
			for _, offset in ipairs(offsets) do
				vim.api.nvim_buf_add_highlight(outputBuf, ns, "IncSearch", line - 1, offset["start"], offset["end"])
			end
			if replace_offsets ~= nil then
				local replace_offset = replace_offsets[line]

				for _, offset in ipairs(replace_offset) do
					vim.api.nvim_buf_add_highlight(outputBuf, ns, "CurSearch", line - 1, offset["start"], offset["end"])
				end
			end
		end
	end
	for _, output in ipairs(grouped_search_outputs) do
		-- TODO: insert file path as a heading or something
		for it, line_output in ipairs(output["line_search_outputs"]) do
			local line = line_output.lines
			table.insert(lines, line)
			table.insert(search_offsets, line_output.search_offset)
			if line_output.replace_offset ~= nil then
				if replace_offsets == nil then
					replace_offsets = {}
				end
				table.insert(replace_offsets, line_output.replace_offset)
			end
		end
		-- local _search_offsets = output["search_offset"]
		-- table.insert(lines, output["line"])
		-- table.insert(search_offsets, _search_offsets)
	end
	return {
		lines = lines,
		callback = highlight_callback,
	}
end

function M.display_error()
	local error = state.error
	if type(error) == "table" then
		return { "Error: ", "", unpack(error) }
	end
	return { "Error", "", error }
end

return M
