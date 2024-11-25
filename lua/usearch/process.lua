local replace = require("usearch.replace")
local util = require("usearch.util")

local M = {}

--- @param search_output RipgrepSearchOutput[]
--- @return FileMatch[]
function M.search_output_file_and_line(search_output)
	-- Inside of search_output, there are multiple matches for a single file. We want to group them up by file.
	--- @type { [string]: number[] }
	local file_matches = {}

	for _, output in ipairs(search_output) do
		local file_path = output["file_path"]
		if file_matches[file_path] == nil then
			file_matches[file_path] = {}
		end

		table.insert(file_matches[file_path], output["line_number"])
	end

	--- @type FileMatch[]
	local file_matches_final = {}

	for file_path, line_numbers in pairs(file_matches) do
		table.insert(file_matches_final, {
			["file_path"] = file_path,
			["line_numbers"] = line_numbers,
		})
	end

	return file_matches_final
end

--- @param process_search_output ProcessedSearchOutput[]
--- @return GroupedSearchOutput[]
function M.group_up_search_outputs_by_filename(process_search_output)
	--- @type { [string]: LineSearchOutput[] }
	local grouped_search_outputs = {}

	for _, output in ipairs(process_search_output) do
		local file_path = output["file_path"]
		if grouped_search_outputs[file_path] == nil then
			grouped_search_outputs[file_path] = {}
		end

		local line_number = output["line_number"]
		local lines = output["line"]
		local search_offset = output["search_offset"]
		local replace_offset = output["replace_offset"]

		local line_search_output = {
			["line_number"] = line_number,
			["lines"] = lines,
			["search_offset"] = search_offset,
			["replace_offset"] = replace_offset,
		}
		table.insert(grouped_search_outputs[file_path], line_search_output)
	end

	--- @type GroupedSearchOutput[]
	local grouped_search_outputs_final = {}

	for file_path, line_search_outputs in pairs(grouped_search_outputs) do
		table.insert(grouped_search_outputs_final, {
			["file_path"] = file_path,
			["line_search_outputs"] = line_search_outputs,
		})
	end

	return grouped_search_outputs_final
end

--- @alias Offset { start: number, finish: number }
--- @alias ProcessedSearchOutput {
---   line: string,
---   search_offset: Offset[],
---   replace_offset: Offset[] | nil,
---   file_path: string,
---   line_number: number,
--- }
--- @param search string
--- @param replacer string
--- @param search_output RipgrepSearchOutput[]
--- @return { data: ProcessedSearchOutput[] | nil, error: string[] | nil }
function M.process_search_output(search, replacer, search_output)
	local changes = {}

	local lua_search_output = util.convert_line_numbers_and_matches(search_output)

	for _, output in ipairs(lua_search_output) do
		local line = output["lines"]

		local new_lines = line
		-- If there is a trailing newline, remove it
		if new_lines:sub(-1) == "\n" then
			new_lines = new_lines:sub(1, -2)
		end

		--- @type Offset[]
		local search_offsets = {}
		---
		--- @type Offset[] | nil
		local replace_offsets = {}

		if replacer == nil or replacer == "" then
			for _, match in ipairs(output.submatches) do
				local start = match.start
				local finish = match.finish
				-- The offsets from ripgrep are 0-based.
				-- We're about to do some string manipulation in lua, so we need to adjust the offsets to be 1-based
				table.insert(search_offsets, {
					["start"] = start - 1,
					["finish"] = finish - 1,
				})
				replace_offsets = nil
			end
		else
			local offset = 0
			for _, match in ipairs(output.submatches) do
				local start = match.start
				local finish = match.finish
				local content = match.match

				local new_line_result = replace.replace_in_line(content, search, replacer)
				if new_line_result.error ~= nil then
					return {
						data = nil,
						error = new_line_result.error,
					}
				end
				--- @type string
				local new_content = new_line_result.data
				local new_content_length = string.len(new_content)

				local new_str = content .. new_content
				local just_before_beginning_of_match = start + offset - 1
				local prev_str = new_lines:sub(1, just_before_beginning_of_match)
				local rest_of_str = new_lines:sub(finish + offset)
				local concatted = prev_str .. new_str .. rest_of_str
				new_lines = concatted

				local search_offset_adjusted_start = start + offset
				local search_offset_adjusted_end = finish + offset

				local replace_offset_adjusted_start = search_offset_adjusted_end
				local replace_offset_adjusted_end = replace_offset_adjusted_start + new_content_length

				-- The offsets from ripgrep are 0-based.
				-- We're about to do some string manipulation in lua, so we need to adjust the offsets to be 1-based
				table.insert(search_offsets, {
					["start"] = search_offset_adjusted_start - 1,
					["finish"] = search_offset_adjusted_end - 1,
				})
				if replace_offsets == nil then
					error("Replace offsets should not be nil")
				end
				table.insert(replace_offsets, {
					["start"] = replace_offset_adjusted_start - 1,
					["finish"] = replace_offset_adjusted_end - 1,
				})

				offset = offset + new_content_length
			end
		end

		table.insert(changes, {
			line = new_lines,
			file_path = output["file_path"],
			line_number = output["line_number"],
			search_offset = search_offsets,
			replace_offset = replace_offsets,
		})
	end

	return {
		data = changes,
		error = nil,
	}
end

return M
