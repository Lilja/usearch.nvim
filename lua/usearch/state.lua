local pkg = "usearch"
---
--- @type string | nil
local regex = nil

--- @type string | nil
local replacer = nil

--- @type number
local matches_count = 0

--- @type { file_path: string, line_no: string }[]
local matches = {}

--- @type { [string]: boolean }
local unique_file_paths = {}

--- @type { [string]: { matches: { file_path: string, line_no: string }[], count: number } }
local grouped_matches = {}

local last_matches = {
	matches_count = matches_count,
	matches = matches,
	unique_file_paths = unique_file_paths,
	grouped_matches = grouped_matches,
}

local M = {
	initial = true,

	regex = regex,
	replacer = replacer,

	searchWin = -1,
	replaceWin = -1,
	outputWin = -1,

	searchBuf = -1,
	replaceBuf = -1,
	outputBuf = -1,

	pkg = pkg,

	last_matches = last_matches,
}

function M.reset_state()
	M.initial = true

	M.regex = nil
	M.replacer = nil

	M.searchWin = -1
	M.replaceWin = -1
	M.outputWin = -1

	M.searchBuf = -1
	M.replaceBuf = -1
	M.outputBuf = -1

	M.last_matches = {
		matches_count = 0,
		matches = {},
		unique_file_paths = {},
		grouped_matches = {},
	}

end

return M
