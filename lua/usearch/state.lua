local pkg = "usearch"

--- @alias Submatch { match: string, start: number, finish: number }

-- Beware: The `start` and `finish` are 0-based indices.
--- @alias RipgrepSearchOutput { file_path: string, lines: string, line_number: number, submatches: Submatch[] }

-- Beware: The `start` and `finish` are 1-based indices.
--- @alias LuaSearchOutput { file_path: string, line: string, line_number_0i: number, submatches: Submatch[] }

--- @alias LineSearchOutput {
--- line_number: number,
--- lines: string,
--- search_offset: Offset[],
--- replace_offset: Offset[] | nil
--- }

--- @alias GroupedSearchOutput { file_path: string, line_search_outputs: LineSearchOutput[] }

--- @alias FileMatch { file_path: string, line_numbers: number[] }

--- @type string | nil
local search_regex = nil

--- @type string | nil
local replace_regex = nil

--- @type string | nil
local ignore = nil

--- @type nil | string | string[]
local error = nil

--- @type FileMatch[]
local matches = {}

-- A table to store the current undo state of the files that was search and replaced.
--- @alias FileChange { file_path: string, seq_cur: number }[]
--- @type FileChange
local changed_files_with_seq_cur = {}

local M = {
	initial = true,

	search_regex = search_regex,
	replace_regex = replace_regex,
	ignore = ignore,

	searchWin = -1,
	replaceWin = -1,
	outputWin = -1,
	ignoreWin = -1,
	debugWin = -1,

	searchBuf = -1,
	replaceBuf = -1,
	outputBuf = -1,
	ignoreBuf = -1,
	debugBuf = -1,

	pkg = pkg,

	matches = matches,

	error = error,

	config = {
		search_highlight_group = "IncSearch",
		replace_highlight_group = "CurSearch",
		line_number_highlight_group = "LineNr",
		file_path_highlight_group = "Title",
		elapsed_highlight_group = "Number",
	},

	changed_files_with_seq_cur = changed_files_with_seq_cur,
}

function M.reset_state()
	M.initial = true

	M.search_regex = nil
	M.replace_regex = nil
	M.ignore = nil

	M.searchWin = -1
	M.replaceWin = -1
	M.outputWin = -1
	M.ignoreWin = -1
	M.debugWin = -1

	M.searchBuf = -1
	M.replaceBuf = -1
	M.outputBuf = -1
	M.ignoreBuf = -1
	M.debugBuf = -1

	M.matches = {}

	M.error = nil

	M.changed_files_with_seq_cur = {}
end

return M
