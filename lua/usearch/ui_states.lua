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

return M
