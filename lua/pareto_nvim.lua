---@diagnostic disable: no-unknown
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
		local row, col, _ = node:start()
		if cur[1] ~= row + 1 or cur[2] ~= col then
			vim.api.nvim_win_set_cursor(0, { row + 1, col })
			return
		end
		local sibling = node:prev_sibling()
		if sibling then
			row, col, _ = sibling:start()
			if cur[1] ~= row + 1 or cur[2] ~= col then
				vim.api.nvim_win_set_cursor(0, { row + 1, col })
				return
			end
		end
		node = node:parent()
	end
end

-- go forward node
M.forward_node = function()
	local cur = vim.api.nvim_win_get_cursor(0)
	local node, shift
	if vim.api.nvim_get_mode().mode == "n" then
		node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})
		shift = 1
	elseif vim.api.nvim_get_mode().mode == "i" then
		node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2] - 1, {})
		shift = 0
	end
	while node do
		local row, col, _ = node:end_()
		if cur[1] ~= row + 1 or cur[2] ~= col - shift then
			vim.api.nvim_win_set_cursor(0, { row + 1, col - shift })
			return
		end
		local sibling = node:next_sibling()
		if sibling then
			row, col, _ = sibling:end_()
			if cur[1] ~= row + 1 or cur[2] ~= col - shift then
				vim.api.nvim_win_set_cursor(0, { row + 1, col - shift })
				return
			end
		end
		node = node:parent()
	end
end

-- wrap treesitter node with char
---@ char string
---@param node? any
M.wrap_node = function(char, node)
	local cur = vim.api.nvim_win_get_cursor(0)
	if node == nil then
		node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})
	end
	if node then
		---@diagnostic disable-next-line: param-type-mismatch
		local node_text = vim.treesitter.query.get_node_text(node, 0, {})
		---@diagnostic disable-next-line: param-type-mismatch
		node_text = vim.split(node_text, "\n", {})
		local start_row, start_col, end_row, end_col = node:range()
		local begin_char, end_char
		if opening_parens[char] ~= nil then
			begin_char = char
			--- @type string
			end_char = parens_map[char]
			node_text[1] = begin_char .. node_text[1]
			node_text[#node_text] = node_text[#node_text] .. end_char
		end
		if closing_parens[char] ~= nil then
			begin_char = closing_parens[char]
			--- @type string
			end_char = char
			node_text[1] = begin_char .. " " .. node_text[1]
			node_text[#node_text] = node_text[#node_text] .. " " .. end_char
		end
		vim.api.nvim_buf_set_text(0, start_row, start_col, end_row, end_col, node_text)
		vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col + 1 })
	end
end

-- wrap treesitter parent node with cahr
---@param char string
M.wrap_parent_node = function(char)
	local cur = vim.api.nvim_win_get_cursor(0)
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})
	if node then
		node = node:parent()
		M.wrap_node(char, node)
	end
end

-- wrap treesitter node with char
---@param char string
M.wrap_current_node = function(char)
	local cur = vim.api.nvim_win_get_cursor(0)
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})
	if node then
		local parent = node:parent()
		if parent then
			M.wrap_node(char, parent)
		end
	end
end

-- raise current treesitter node and replace parent node
M.splice_node = function()
	local cur = vim.api.nvim_win_get_cursor(0)
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})
	if node then
		local parent = node:parent()
		if parent then
			local parent_start_row, parent_start_col, parent_end_row, parent_end_col = parent:range()
			---@diagnostic disable-next-line: param-type-mismatch
			local node_text = vim.treesitter.query.get_node_text(node, 0, {})
			---@diagnostic disable-next-line: param-type-mismatch
			local node_text_list = vim.split(node_text, "\n", {})
			vim.api.nvim_buf_set_text(
				0,
				parent_start_row,
				parent_start_col,
				parent_end_row,
				parent_end_col,
				node_text_list
			)
			vim.api.nvim_win_set_cursor(0, { parent_start_row + 1, parent_start_col })
		end
	end
end

-- insert cursor at the begingng of parent sexp node
M.jump_parent_begin = function()
	local cur = vim.api.nvim_win_get_cursor(0)
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})
	while node do
		local parent = node:parent()
		if parent then
			local start_row, start_col, _, _ = parent:range()
			-- check if node starts with opening paren
			local char = vim.fn.getline(start_row + 1):sub(start_col + 1, start_col + 1)
			if opening_parens[char] then
				vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col + 1 })
				vim.cmd(":startinsert")
				return
			end
		end
		node = parent
	end
end

-- insert cursor at the end of parent sexp node
M.jump_parent_end = function()
	local cur = vim.api.nvim_win_get_cursor(0)
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})
	while node do
		local parent = node:parent()
		if parent then
			local _, _, end_row, end_col = parent:range()
			-- check if node starts with opening paren
			local char = vim.fn.getline(end_row + 1):sub(end_col - 1, end_col - 1)
			if closing_parens[char] then
				vim.api.nvim_win_set_cursor(0, { end_row + 1, end_col - 1 })
				vim.cmd(":startinsert")
				return
			end
		end
		node = parent
	end
end

-- vim.keymap.set("n", "<F7>", function()
-- 	M.jump_parent_end()
-- end, {})

return M
