local replace = require("usearch.replace")

local M = {}

--- @param matches { file_path: string, line_no: string }[]
--- @return { matches: { file_path: string, line_no: string }[], matches_count: number, unique_file_paths: { [string]: boolean }, grouped_matches: { [string]: { matches: { file_path: string, line_no: string }[], count: number } } }
function M.group_up_matches_and_craft_meta_data(matches)
	--- @type { [string]: boolean }
	local unique_file_paths = {}

	--- @type { [string]: { matches: { file_path: string, line_no: string }[], count: number } }
	local grouped_matches = {}

	local count = 0
	for _, m in ipairs(matches) do
		-- table.insert(matches, m)

		local key = m["file_path"]
		unique_file_paths[key] = true
		count = count + 1
	end

	for _, m in ipairs(matches) do
		local key = m["file_path"]
		if grouped_matches[key] == nil then
			grouped_matches[key] = {
				["matches"] = {},
				["count"] = 0,
			}
		end

		table.insert(grouped_matches[key]["matches"], m["line_no"])
		grouped_matches[key]["count"] = grouped_matches[key]["count"] + 1
	end

	return {
		matches = matches,
		matches_count = count,
		unique_file_paths = unique_file_paths,
		grouped_matches = grouped_matches,
	}
end

--- @alias LineSearchOutput { line_number: number, lines: string, search_offset: Offset[], replace_offset: Offset[] | nil }
--- @alias GroupedSearchOutput { file_path: string, line_search_outputs: LineSearchOutput[] }
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

--- @alias Offset { start: number, end: number }
--- @alias ProcessedSearchOutput { line: string, search_offset: Offset[], replace_offset: Offset[] | nil, file_path: string, line_number: number }
--- @param search string
--- @param replacer string
--- @param search_output SearchOutput[]
--- @return ProcessedSearchOutput[]
function M.process_search_output(search, replacer, search_output)
	local changes = {}

	for _, output in ipairs(search_output) do
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
				table.insert(search_offsets, {
					["start"] = start - 1,
					["end"] = finish - 1,
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
					error("Error")
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

				table.insert(search_offsets, {
					["start"] = search_offset_adjusted_start - 1,
					["end"] = search_offset_adjusted_end - 1,
				})
				if replace_offsets == nil then
					error("Replace offsets should not be nil")
				end
				table.insert(replace_offsets, {
					["start"] = replace_offset_adjusted_start - 1,
					["end"] = replace_offset_adjusted_end - 1,
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

	return changes
end

return M
