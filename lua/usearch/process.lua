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

return M
