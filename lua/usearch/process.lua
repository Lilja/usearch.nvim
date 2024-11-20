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

--- @alias Offset { start: number, end: number }
--- @alias ProcessedSearchOutput { line: string, search_offset: Offset[], replace_offset: Offset[] }
--- @param search string
--- @param replacer string
--- @param search_output SearchOutput[]
--- @return ProcessedSearchOutput[]
function M.process_search_output(search, replacer, search_output)
	local changes = {}

	for _, output in ipairs(search_output) do
		local line = output["lines"]
		print(vim.inspect(output))

		local new_lines = line

		--- @type Offset[]
		local search_offsets = {}
		---
		--- @type Offset[]
		local replace_offsets = {}

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
			table.insert(replace_offsets, {
				["start"] = replace_offset_adjusted_start - 1,
				["end"] = replace_offset_adjusted_end - 1,
			})

			offset = offset + new_content_length
		end

		table.insert(changes, {
			line = new_lines,
			search_offset = search_offsets,
			replace_offset = replace_offsets,
		})
	end

	return changes
end

return M
