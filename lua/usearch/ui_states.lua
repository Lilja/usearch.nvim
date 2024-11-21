local state = require("usearch.state")
local devicon = require("nvim-web-devicons")

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


--- @param offset Offset[]
--- @param diff number
function change_offset(offset, diff)
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

--- @param grouped_search_outputs GroupedSearchOutput[]
--- @return { lines: string[], callback: function }
function M.display_matches_v2(grouped_search_outputs)
	local ns = vim.api.nvim_create_namespace("usearch")
	local outputBuf = state.outputBuf
	local lines = {}

	-- A table to store what to highlight in the buffer. The key is the buffer line number(0-indexed).
	---
	--- @type { buffer_line_number: number, highlight_group: string, offsets: Offset[]}[]
	local highlight_content = {}

	local highlight_callback = function()
		for _, content in ipairs(highlight_content) do
			local buffer_line_number = content["buffer_line_number"]

			local offsets = content["offsets"]
			for _, offset in ipairs(offsets) do
				vim.api.nvim_buf_add_highlight(
					outputBuf,
					ns,
					content["highlight_group"],
					buffer_line_number,
					offset["start"],
					offset["finish"]
				)
			end
		end
	end

	local buffer_line_number = 0
	for _, output in ipairs(grouped_search_outputs) do
		-- file path contains slash, so we need to split it.
		local filename = output["file_path"]:match("([^/]+)$")
		local file_extension = filename:match("^.+%.(.+)$")
		local icon = devicon.get_icon(filename, file_extension, { default = true })
		local file_name_row = icon .. " " .. output["file_path"]
		table.insert(lines, file_name_row)
		-- Insert formatting for the file path. Use the Title highlight group.
		table.insert(highlight_content, {
			buffer_line_number = buffer_line_number,
			highlight_group = "Title",
			offsets = {
				{
					start = 0,
					finish = #file_name_row,
				},
			},
		})
		buffer_line_number = buffer_line_number + 1

		for _, line_output in ipairs(output["line_search_outputs"]) do
			local line = line_output.lines
			-- Prepend the line number before the line with a space. Then adjust the offsets.
			line = line_output.line_number .. " " .. line
			table.insert(lines, line)
			local search_offsets = line_output.search_offset
			local replace_offsets = line_output.replace_offset
			search_offsets = change_offset(search_offsets, #tostring(line_output.line_number) + 1)
			if replace_offsets ~= nil then
				replace_offsets = change_offset(replace_offsets, #tostring(line_output.line_number) + 1)
			end
			-- Insert formatting for the line number. Use the LineNr highlight group.
			table.insert(highlight_content, {
				buffer_line_number = buffer_line_number,
				highlight_group = "LineNr",
				offsets = {
					{
						start = 0,
						finish = #tostring(line_output.line_number),
					},
				},
			})

			-- table.insert(search_offsets[buffer_line_number], line_output.search_offset)
			table.insert(highlight_content, {
				buffer_line_number = buffer_line_number,
				highlight_group = "IncSearch",
				offsets = search_offsets,
			})
			if line_output.replace_offset ~= nil then
				if replace_offsets == nil then
					replace_offsets = {}
				end
				table.insert(highlight_content, {
					buffer_line_number = buffer_line_number,
					highlight_group = "CurSearch",
					offsets = replace_offsets,
				})
			end
			buffer_line_number = buffer_line_number + 1
		end
		-- local _search_offsets = output["search_offset"]
		-- table.insert(lines, output["line"])
		-- table.insert(search_offsets, _search_offsets)
	end
	return {
		lines = lines,
		callback = highlight_callback,
	}
end

function M.display_error()
	local error = state.error
	if type(error) == "table" then
		return { "Error: ", "", unpack(error) }
	end
	return { "Error", "", error }
end

return M
