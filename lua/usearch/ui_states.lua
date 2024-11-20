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

--- @param processed_search_output ProcessedSearchOutput[]
--- @return { lines: string[], callback: function }
function M.display_matches_v2(processed_search_output)
	local ns = vim.api.nvim_create_namespace("usearch")
	local outputBuf = state.outputBuf
	local lines = {}

	--- @type Offset[][]
	local search_offsets = {}

	local highlight_callback = function()
		for line, offsets in ipairs(search_offsets) do
			for _, offset in ipairs(offsets) do
				print("Highlighting search", line - 1, offset["start"], offset["end"], outputBuf)
				vim.api.nvim_buf_add_highlight(outputBuf, ns, "IncSearch", line - 1, offset["start"], offset["end"])
			end
		end
	end
	print("Displaying matches v2")
	-- print(vim.inspect(processed_search_output))
	for _, output in ipairs(processed_search_output) do
		local _search_offsets = output["search_offset"]
		table.insert(lines, output["line"])
		table.insert(search_offsets, _search_offsets)
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
