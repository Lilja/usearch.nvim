local pkg = "usearch"

--- @alias LineSearchOutput { line_number: number, lines: string, search_offset: Offset[], replace_offset: Offset[] | nil }
--- @alias GroupedSearchOutput { file_path: string, line_search_outputs: LineSearchOutput[] }


--- @type string | nil
local search_regex = nil

--- @type string | nil
local replace_regex = nil

--- @type string | nil
local ignore = nil

--- @type nil | string | string[]
local error = nil

--- @type GroupedSearchOutput[]
local grouped_search_outputs = {}

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

	grouped_search_outputs = grouped_search_outputs,

	error = error,
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

	M.grouped_search_outputs = {}

	M.error = nil

end

return M
