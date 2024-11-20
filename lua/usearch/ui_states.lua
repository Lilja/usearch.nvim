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
function M.display_matches_v2(processed_search_output)
	local lines = {}
	for _, output in ipairs(processed_search_output) do
		table.insert(lines, output["line"])
		table.insert(lines, "")
	end
	return lines
end


function M.display_error()
	local error = state.error
	if type(error) == "table" then
		return { "Error: ", "", unpack(error) }
	end
	return { "Error", "", error }
end

return M
