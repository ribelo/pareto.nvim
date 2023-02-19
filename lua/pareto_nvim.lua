---@diagnostic disable: no-unknown
local M = {}

M.default = {
	hl = "IncSearch",
}

M.setup = function(opts)
	M.default = vim.tbl_deep_extend("force", M.default, opts)
end

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
			if col - shift > 0 then
				vim.api.nvim_win_set_cursor(0, { row + 1, col - shift })
			end
			return
		end
		local sibling = node:next_sibling()
		if sibling then
			row, col, _ = sibling:end_()
			if cur[1] ~= row + 1 or cur[2] ~= col - shift then
				if col - shift > 0 then
					vim.api.nvim_win_set_cursor(0, { row + 1, col - shift })
				end
				return
			end
		end
		node = node:parent()
	end
end

-- backward sexp
M.backward_sexp = function()
	local cur = vim.api.nvim_win_get_cursor(0)
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})
	local i = 0
	while node do
		i = i + 1
		local row, col, _ = node:start()
		if cur[1] ~= row + 1 or cur[2] ~= col then
			-- get char at end of node pos
			local char = vim.api.nvim_buf_get_text(0, row, col, row, col + 1, {})
			-- if char at end of node is closing parens set cursor
			if opening_parens[char[1]] ~= nil then
				vim.api.nvim_win_set_cursor(0, { row + 1, col })
				return
			end
		end
		local sibling = node:prev_sibling()
		if sibling then
			row, col, _ = sibling:start()
			if cur[1] ~= row + 1 or cur[2] ~= col then
				-- get char at end of node pos
				local char = vim.api.nvim_buf_get_text(0, row, col, row, col + 1, {})
				-- if char at end of node is closing parens set cursor
				if closing_parens[char[1]] ~= nil then
					vim.api.nvim_win_set_cursor(0, { row + 1, col })
					return
				end
			end
		end
		node = node:parent()
	end
end

-- go forward sexp based on treesitter node
M.forward_sexp = function()
	local cur = vim.api.nvim_win_get_cursor(0)
	local node, shift
	if vim.api.nvim_get_mode().mode == "n" then
		node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})
		shift = 1
	elseif vim.api.nvim_get_mode().mode == "i" then
		node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2] - 1, {})
		shift = 0
	end
	local i = 0
	while node do
		i = i + 1
		local row, col, _ = node:end_()
		if cur[1] ~= row + 1 or cur[2] ~= col - shift then
			-- get char at end of node pos
			local char = vim.api.nvim_buf_get_text(0, row, col - 1, row, col, {})
			-- if char at end of node is closing parens set cursor
			if closing_parens[char[1]] ~= nil then
				vim.api.nvim_win_set_cursor(0, { row + 1, col - shift })
				return
			end
		end
		local sibling = node:next_sibling()
		if sibling then
			row, col, _ = sibling:end_()
			if cur[1] ~= row + 1 or cur[2] ~= col - shift then
				-- get char at end of node pos
				local char = vim.api.nvim_buf_get_text(0, row, col - 1, row, col, {})
				-- if char at end of node is closing parens set cursor
				if closing_parens[char[1]] ~= nil then
					if col - 1 > 0 then
						vim.api.nvim_win_set_cursor(0, { row + 1, col - shift })
					end
					return
				end
			end
		end
		node = node:parent()
	end
end

-- wrap treesitter node with char
---@param char string
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
M.raise_node = function()
	local cur = vim.api.nvim_win_get_cursor(0)
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})
	vim.pretty_print("begin")
	while node do
		local node_row_start, node_col_start, _ = node:start()
		local node_row_end, node_col_end, _ = node:end_()
		local char_start =
			vim.api.nvim_buf_get_text(0, node_row_start, node_col_start, node_row_start, node_col_start + 1, {})[1]
		local char_end = vim.api.nvim_buf_get_text(0, node_row_end, node_col_end - 1, node_row_end, node_col_end, {})[1]
		vim.pretty_print("start", char_start, "end", char_end)
		if opening_parens[char_start] and closing_parens[char_end] then
			vim.api.nvim_buf_set_text(0, node_row_start, node_col_start, node_row_start, node_col_start + 1, { "" })
			vim.api.nvim_buf_set_text(0, node_row_end, node_col_end - 2, node_row_end, node_col_end - 1, { "" })
			local ns_id =
				vim.api.nvim_buf_add_highlight(0, 0, M.default.hl, node_row_start, node_col_start, node_col_start + 1)
			vim.api.nvim_buf_add_highlight(0, ns_id, M.default.hl, node_row_end, node_col_end - 3, node_col_end - 2)
			vim.defer_fn(function()
				vim.api.nvim_buf_clear_namespace(0, ns_id, node_row_start, node_row_end + 1)
			end, 250)
			return
		end
		node = node:parent()
	end
end

-- splice current treesitter node
M.splice_node = function()
	local cur = vim.api.nvim_win_get_cursor(0)
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})
	if node then
		local parent = node:parent()
		if parent then
			local parent_start_row, parent_start_col, parent_end_row, parent_end_col = parent:range()
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

-- uncomment every line if contains commentstring
M.uncomment_node = function()
	vim.pretty_print("start 3")
	local cur = vim.api.nvim_win_get_cursor(0)
	local commentstring = vim.api.nvim_buf_get_option(0, "commentstring"):gsub("%%s", "")
	local is_comment = function(xs, col_start)
		return xs:sub(col_start, col_start + #commentstring - 1) == commentstring
	end
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local i = -1
	local break_backward, break_forward = false, false
	while true do
		i = i + 1
		if i >= 0 and not break_backward then
			local line = lines[cur[1] - 1 - i]
			vim.pretty_print("line before", line)
			if is_comment(line, cur[2] + 1) then
				local new_line = line:gsub(commentstring, " ")
				vim.api.nvim_buf_set_lines(0, cur[1] - 2 - i, cur[1] - 1 - i, false, { new_line })
			else
				break_backward = true
			end
		end
		if i <= #lines and not break_forward then
			local line = lines[cur[1] + i]
			vim.pretty_print("line after", line)
			if is_comment(line, cur[2] + 1) then
				local new_line = line:gsub(commentstring, " ")
				vim.api.nvim_buf_set_lines(0, cur[1] - 1 + i, cur[1] + i, false, { new_line })
			else
				break_forward = true
			end
		end
		if break_backward and break_forward then
			break
		end
	end
end

-- comment every line of node, place the comment in column where the node starts
M.comment_node = function()
	local cur = vim.api.nvim_win_get_cursor(0)
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})
	local commentstring = vim.api.nvim_buf_get_option(0, "commentstring")
	if node and commentstring then
		local start_row, start_col, end_row, end_col = node:range()
		local line = vim.api.nvim_buf_get_lines(0, end_row, end_row + 1, true)[1]
		-- if line contains string other than blankline befor begining of the node inser line before node
		if line:sub(0, start_col):match("%S") then
			local x = line:sub(0, start_col)
			local y = line:sub(start_col + 1)
			vim.pretty_print(x, y)
			vim.api.nvim_buf_set_lines(0, start_row, start_row + 1, false, { x, string.rep(" ", start_col) .. y })
			start_row = start_row + 1
			end_row = end_row + 1
		end
		-- if character after end of node is not end of line inser new line
		if end_col < #vim.fn.getline(end_row + 1) then
			local x = line:sub(0, end_col)
			local y = line:sub(end_col + 1)
			vim.api.nvim_buf_set_lines(0, end_row, end_row + 1, false, { x, string.rep(" ", start_col) .. y })
		end
		for i = start_row, end_row do
			line = vim.api.nvim_buf_get_lines(0, i, i + 1, true)[1]:sub(start_col)
			vim.api.nvim_buf_set_lines(
				0,
				i,
				i + 1,
				false,
				{ string.format(string.rep(" ", start_col) .. commentstring, line) }
			)
		end
	end
end

-- forward slurp node
M.forward_slurp = function()
	local cur = vim.api.nvim_win_get_cursor(0)
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2] - 1, {})
	while node do
		local node_row, node_col, _ = node:end_()
		local char = vim.api.nvim_buf_get_text(0, node_row, node_col - 1, node_row, node_col, {})[1]
		if closing_parens[char] ~= nil then
			vim.api.nvim_buf_set_text(0, node_row, node_col - 1, node_row, node_col, { "" })
			local sibling_node = node:next_sibling()
			if sibling_node then
				local sibling_row, sibling_col, _ = sibling_node:end_()
				vim.api.nvim_buf_set_text(0, sibling_row, sibling_col, sibling_row, sibling_col, { char })
				local ns_id =
					vim.api.nvim_buf_add_highlight(0, 0, M.default.hl, sibling_row, sibling_col, sibling_col + 1)
				vim.defer_fn(function()
					vim.api.nvim_buf_clear_namespace(0, ns_id, sibling_row, sibling_row + 1)
				end, 250)
				return
			end
		end
		node = node:parent()
	end
end

-- backward slurp node
M.backward_slurp = function()
	local cur = vim.api.nvim_win_get_cursor(0)
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2] - 1, {})
	while node do
		local node_row, node_col, _ = node:start()
		local char = vim.api.nvim_buf_get_text(0, node_row, node_col, node_row, node_col + 1, {})[1]
		if opening_parens[char] ~= nil then
			local sibling_node = node:prev_sibling()
			if sibling_node then
				local sibling_row, sibling_col, _ = sibling_node:start()
				local parent_node = node:parent()
				local parent_row, parent_col, _ = parent_node:start()
				if parent_row ~= sibling_row or parent_col < sibling_col - 1 then
					vim.api.nvim_buf_set_text(0, node_row, node_col, node_row, node_col + 1, { "" })
					vim.api.nvim_buf_set_text(0, sibling_row, sibling_col, sibling_row, sibling_col, { char })
					local ns_id =
						vim.api.nvim_buf_add_highlight(0, 0, M.default.hl, sibling_row, sibling_col, sibling_col + 1)
					vim.defer_fn(function()
						vim.api.nvim_buf_clear_namespace(0, ns_id, sibling_row, sibling_row + 1)
					end, 250)
				end
				return
			end
		end
		node = node:parent()
	end
end

-- forward barf
M.forward_barf = function()
	local cur = vim.api.nvim_win_get_cursor(0)
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})
	while node do
		local node_row, node_col, _ = node:end_()
		local char = vim.api.nvim_buf_get_text(0, node_row, node_col - 1, node_row, node_col, {})[1]
		if closing_parens[char] then
			local child_count = node:child_count()
			local child_node = node:child(math.max(0, child_count - 3)) --  first and last is paren
			if child_node then
				local child_row, child_col, _ = child_node:end_()
				vim.api.nvim_buf_set_text(0, node_row, node_col - 1, node_row, node_col, { "" })
				vim.api.nvim_buf_set_text(0, child_row, child_col, child_row, child_col, { char })
				local ns_id = vim.api.nvim_buf_add_highlight(0, 0, "incsearch", child_row, child_col, child_col + 1)
				vim.defer_fn(function()
					vim.api.nvim_buf_clear_namespace(0, ns_id, child_row, child_row + 1)
				end, 250)
				return
			end
		end
		node = node:parent()
	end
end

-- backward barf
M.backward_barf = function()
	local cur = vim.api.nvim_win_get_cursor(0)
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})
	while node do
		local node_row, node_col, _ = node:start()
		local char = vim.api.nvim_buf_get_text(0, node_row, node_col, node_row, node_col + 1, {})[1]
		if opening_parens[char] then
			local child_count = node:child_count()
			local child_node = node:child(math.min(child_count, 2)) --  first and last is paren
			if child_node then
				local child_row, child_col, _ = child_node:start()
				vim.api.nvim_buf_set_text(0, node_row, node_col, node_row, node_col + 1, { "" })
				vim.api.nvim_buf_set_text(0, child_row, child_col - 1, child_row, child_col - 1, { char })
				local ns_id = vim.api.nvim_buf_add_highlight(0, 0, "IncSearch", child_row, child_col - 1, child_col)
				vim.defer_fn(function()
					vim.api.nvim_buf_clear_namespace(0, ns_id, child_row, child_row + 1)
				end, 250)
				return
			end
		end
		node = node:parent()
	end
end

-- vim.keymap.set({ "n", "i" }, "<F7>", function()
-- 	M.raise_node()
-- end, {})
-- vim.keymap.set({ "n", "i" }, "<F8>", function()
-- 	M.backward_barf()
-- end, {})

return M
