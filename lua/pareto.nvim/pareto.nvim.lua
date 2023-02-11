local ts_utils = require("nvim-tressitter.ts_utils")
local ts_query = require("vim.treesitter.query")

local M = {}

local opening_parens = {
	["("] = ")",
	["["] = "]",
	["{"] = "}",
	["<"] = ">",
}

local closing_parens = {
	[")"] = "(",
	["]"] = "[",
	["}"] = "{",
	[">"] = "<",
}

local parens_map = {}
parens_map = vim.tbl_extend("force", parens_map, opening_parens, closing_parens)

-- backward node
M.backward_node = function()
	local cur = vim.api.nvim_win_get_cursor(0)
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})
	while node do
		---@diagnostic disable-next-line: no-unknown
		local row, col, _ = node:start()
		if cur[1] ~= row + 1 or cur[2] ~= col then
			vim.api.nvim_win_set_cursor(0, { row + 1, col })
			return
		end
		---@diagnostic disable-next-line: no-unknown
		local sibling = node:prev_sibling()
		if sibling then
			---@diagnostic disable-next-line: no-unknown
			row, col, _ = sibling:start()
			if cur[1] ~= row + 1 or cur[2] ~= col then
				vim.api.nvim_win_set_cursor(0, { row + 1, col })
				return
			end
		end
		---@diagnostic disable-next-line: no-unknown
		node = node:parent()
	end
end

-- go forward node
M.forward_node = function()
	local cur = vim.api.nvim_win_get_cursor(0)
	---@diagnostic disable-next-line: no-unknown
	local node, shift
	if vim.api.nvim_get_mode().mode == "n" then
		node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})
		shift = 1
	elseif vim.api.nvim_get_mode().mode == "i" then
		node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2] - 1, {})
		shift = 0
	end
	while node do
		---@diagnostic disable-next-line: no-unknown
		local row, col, _ = node:end_()
		if cur[1] ~= row + 1 or cur[2] ~= col - shift then
			vim.api.nvim_win_set_cursor(0, { row + 1, col - shift })
			return
		end
		---@diagnostic disable-next-line: no-unknown
		local sibling = node:next_sibling()
		if sibling then
			---@diagnostic disable-next-line: no-unknown
			row, col, _ = sibling:end_()
			if cur[1] ~= row + 1 or cur[2] ~= col - shift then
				vim.api.nvim_win_set_cursor(0, { row + 1, col - shift })
				return
			end
		end
		---@diagnostic disable-next-line: no-unknown
		node = node:parent()
	end
end

-- wrap treesitter node with
---@param char string
M.wrap_node = function(char)
	local cur = vim.api.nvim_win_get_cursor(0)
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})
	if node then
		---@diagnostic disable-next-line: param-type-mismatch
		local node_text = vim.treesitter.query.get_node_text(node, 0, {})
		---@diagnostic disable-next-line: no-unknown
		local start_row, start_col, end_row, end_col = node:range()
		---@diagnostic disable-next-line: no-unknown
		local begin_char, end_char, text
		if opening_parens[char] ~= nil then
			begin_char = char
			--- @type string
			end_char = parens_map[char]
			text = table.concat({ begin_char, " ", node_text, " ", end_char })
		end
		vim.api.nvim_buf_set_text(0, start_row, start_col, end_row, end_col, { text })
		vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col + 1 })
	end
end

return M
