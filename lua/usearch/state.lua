local pkg = "usearch"
---
--- @type string | nil
local regex = nil

--- @type string | nil
local replacer = nil

--- @type string | nil
local ignore = nil

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

--- @type nil | string | string[]
local error = nil

local M = {
	initial = true,

	regex = regex,
	replacer = replacer,
	ignore = ignore,

	searchWin = -1,
	replaceWin = -1,
	outputWin = -1,
	ignoreWin = -1,

	searchBuf = -1,
	replaceBuf = -1,
	outputBuf = -1,
	ignoreBuf = -1,

	pkg = pkg,

	last_matches = last_matches,

	error = error,
}

function M.reset_state()
	M.initial = true

	M.regex = nil
	M.replacer = nil
	M.ignore = nil

	M.searchWin = -1
	M.replaceWin = -1
	M.outputWin = -1
	M.ignoreWin = -1

	M.searchBuf = -1
	M.replaceBuf = -1
	M.outputBuf = -1
	M.ignoreBuf = -1

	M.last_matches = {
		matches_count = 0,
		matches = {},
		unique_file_paths = {},
		grouped_matches = {},
	}

	M.error = nil

end

return M
