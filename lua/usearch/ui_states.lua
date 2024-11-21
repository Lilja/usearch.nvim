local state = require("usearch.state")
local devicon = require("nvim-web-devicons")

local M = {}
--- @alias HighlightInstruction { buffer_line_number: number, highlight_group: string, offsets: Offset[]}

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
---
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

--- @param file_path string
--- @param lines string[]
--- @param highlight_content HighlightInstruction[]
--- @param buffer_line_number number
--- @return { line: string, highlight: HighlightInstruction }
function render_file_path(file_path, lines, highlight_content, buffer_line_number)
	local filename = file_path:match("([^/]+)$")
	local file_extension = filename:match("^.+%.(.+)$")
	local icon = devicon.get_icon(filename, file_extension, { default = true })
	local highlight = {
		buffer_line_number = buffer_line_number,
		highlight_group = state.config.file_path_highlight_group,
		offsets = {
			{
				start = 0,
				finish = -1,
			},
		},
	}
	local line = icon .. " " .. file_path
	table.insert(lines, line)
	table.insert(highlight_content, highlight)
end

--- @param buffer_line_number number
--- @param line_output LineSearchOutput
--- @param highlight_content HighlightInstruction[]
function render_search_and_replace_content(buffer_line_number, line_output, highlight_content)
	local search_offsets = line_output.search_offset
	local replace_offsets = line_output.replace_offset
	search_offsets = change_offset(search_offsets, #tostring(line_output.line_number) + 1)
	if replace_offsets ~= nil then
		replace_offsets = change_offset(replace_offsets, #tostring(line_output.line_number) + 1)
	end
	-- Insert formatting for the line number. Use the LineNr highlight group.
	table.insert(highlight_content, {
		buffer_line_number = buffer_line_number,
		highlight_group = state.config.line_number_highlight_group,
		offsets = {
			{
				start = 0,
				finish = #tostring(line_output.line_number),
			},
		},
	})

	table.insert(highlight_content, {
		buffer_line_number = buffer_line_number,
		highlight_group = state.config.search_highlight_group,
		offsets = search_offsets,
	})
	if line_output.replace_offset ~= nil then
		if replace_offsets == nil then
			replace_offsets = {}
		end
		table.insert(highlight_content, {
			buffer_line_number = buffer_line_number,
			highlight_group = state.config.replace_highlight_group,
			offsets = replace_offsets,
		})
	end
end

--- @param grouped_search_outputs GroupedSearchOutput[]
	-- elapsed should be a string of the form "0.123s". Read ripgrep's JSON output for more information.
--- @param elapsed string
--- @return { lines: string[], callback: function }
function M.display_matches_v2(grouped_search_outputs, elapsed)
	local ns = vim.api.nvim_create_namespace("usearch")
	local outputBuf = state.outputBuf
	local lines = {}


	-- A table to store what to highlight in the buffer. The key is the buffer line number(0-indexed).
	---
	--- @type HighlightInstruction[]
	local highlight_content = {}

	local highlight_callback = function()
		-- We have just put all the lines in the buffer. Now we need to highlight them.
		-- Previously, we saved instructions for highlighting in the highlight_content table.
		-- Now we will use those instructions to highlight the buffer.
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

	local number_of_files = 0
	local number_of_matches = 0

	for _, output in ipairs(grouped_search_outputs) do
		number_of_files = number_of_files + 1
		number_of_matches = number_of_matches + #output["line_search_outputs"]
	end

	-- Insert metadata about the search results.
	local file_or_files = pluralize(number_of_files, "file", "files")
	local match_or_matches = pluralize(number_of_matches, "match", "matches")
	local match_info = file_or_files .. " found with " .. match_or_matches .. " in "
	local meta_line = match_info .. elapsed
	table.insert(lines, meta_line)
	table.insert(highlight_content, {
		buffer_line_number = buffer_line_number,
		highlight_group = state.config.elapsed_highlight_group,
		offsets = {
			{
				start = #match_info,
				finish = -1,
			},
		},
	})
	buffer_line_number = buffer_line_number + 1

	table.insert(lines, "")

	buffer_line_number = buffer_line_number + 1

	-- Insert the search results into the buffer.
	for it, output in ipairs(grouped_search_outputs) do
		-- file path contains slash, so we need to split it.
		local file_path = output["file_path"]
		render_file_path(file_path, lines, highlight_content, buffer_line_number)
		buffer_line_number = buffer_line_number + 1

		for _, line_output in ipairs(output["line_search_outputs"]) do
			local line = line_output.lines
			-- Prepend the line number before the line with a space. Then adjust the offsets.
			line = line_output.line_number .. " " .. line
			table.insert(lines, line)
			render_search_and_replace_content(buffer_line_number, line_output, highlight_content)
			buffer_line_number = buffer_line_number + 1
		end

		-- If there are more files to display, add a newline.
		if it < #grouped_search_outputs then
			table.insert(lines, "")
			buffer_line_number = buffer_line_number + 1
		end
	end
	return {
		lines = lines,
		callback = highlight_callback,
	}
end

function pluralize(n, singular, plural)
	if n == 1 then
		return n .. " " .. singular
	end
	return n .. " " .. plural
end

function M.display_error()
	local error = state.error
	if type(error) == "table" then
		return { "Error: ", "", unpack(error) }
	end
	return { "Error", "", error }
end

return M
