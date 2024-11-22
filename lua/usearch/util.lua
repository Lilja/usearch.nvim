local M = {}

--- @param n number
--- @param singular string
--- @param plural string
--- @return string
function M.pluralize(n, singular, plural)
	if n == 1 then
		return n .. " " .. singular
	end
	return n .. " " .. plural
end

--- @param ripgrep_search_output RipgrepSearchOutput[]
--- @return LuaSearchOutput[]
function M.convert_line_numbers_and_matches(ripgrep_search_output)
	--- @type LuaSearchOutput[]
	local lua_search_output = {}
	for _, output in ipairs(ripgrep_search_output) do
		local submatches = {}
		for _, submatch in ipairs(output.submatches) do
			table.insert(submatches, {
				match = submatch.match,
				start = submatch.start + 1,
				finish = submatch.finish + 1,
			})
		end

		table.insert(lua_search_output, {
			file_path = output.file_path,
			line_number = output.line_number + 1,
			lines = output.lines,
			submatches = submatches,
		})
	end
	return lua_search_output
end

--- @param offset Offset[]
--- @param diff number
function M.change_offset(offset, diff)
	--- @type Offset[]
	local new_offset = {}
	for _, o in ipairs(offset) do
		table.insert(new_offset, {
			start = o.start + diff,
			finish = o.finish + diff,
		})
	end
	return new_offset
end

return M
