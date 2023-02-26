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

---

---Backward Node
function M.backward_node()
	local cur = vim.api.nvim_win_get_cursor(0)

	-- Get the node at the current position
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})

	-- Iterate over the parent nodes of the current node
	while node do
		---@diagnostic disable-next-line: undefined-field
		local row, col, _ = node:start()

		-- If the current position is not the same as the node start
		-- set the cursor to the node start position and return
		if cur[1] ~= row + 1 or cur[2] ~= col then
			vim.api.nvim_win_set_cursor(0, { row + 1, col })
			return
		end

		-- Get the previous sibling of the current node
		---@diagnostic disable-next-line: undefined-field
		local sibling = node:prev_sibling()

		-- If a sibling exists, check the start position.
		-- If the current position is not the same as the node start
		-- set the cursor to the node start position and return
		if sibling then
			row, col, _ = sibling:start()
			if cur[1] ~= row + 1 or cur[2] ~= col then
				vim.api.nvim_win_set_cursor(0, { row + 1, col })
				return
			end
		end

		-- Move up to the parent node
		---@diagnostic disable-next-line: undefined-field
		node = node:parent()
	end
end

-- go forward node
M.forward_node = function()
	-- Get current cursor position
	local cur = vim.api.nvim_win_get_cursor(0)
	local node, shift

	-- Set node and shift depending on mode
	if vim.api.nvim_get_mode().mode == "n" then
		node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})
		shift = 1
	elseif vim.api.nvim_get_mode().mode == "i" then
		node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2] - 1, {})
		shift = 0
	end

	-- Iterate over tree nodes
	while node do
		-- Get node end position
		local row, col, _ = node:end_()

		-- Check if not at the same position
		if cur[1] ~= row + 1 or cur[2] ~= col - shift then
			-- Move cursor if position is valid
			if col - shift > 0 then
				vim.api.nvim_win_set_cursor(0, { row + 1, col - shift })
			end

			-- Stop loop
			return
		end

		-- Get next sibling node
		local sibling = node:next_sibling()
		if sibling then
			-- Get sibling end position
			row, col, _ = sibling:end_()

			-- Check if not at the same position
			if cur[1] ~= row + 1 or cur[2] ~= col - shift then
				-- Move cursor if position is valid
				if col - shift > 0 then
					vim.api.nvim_win_set_cursor(0, { row + 1, col - shift })
				end

				-- Stop loop
				return
			end
		end

		-- Get parent node
		node = node:parent()
	end
end

M.backward_sexp = function()
	-- Get the current cursor position
	local cur = vim.api.nvim_win_get_cursor(0)

	-- Get the node at the current cursor position
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})

	-- Keep looping until a node is found or it reaches the root node
	while node do
		-- Get the start position of the node
		---@diagnostic disable-next-line: undefined-field
		local row, col, _ = node:start()

		-- If the current cursor position is not equal to the start position of the node
		if cur[1] ~= row + 1 or cur[2] ~= col then
			-- Get the character at the end of the node position
			local char = vim.api.nvim_buf_get_text(0, row, col, row, col + 1, {})

			-- If the character at the end of the node position is an opening parenthesis, set the cursor
			if opening_parens[char[1]] ~= nil then
				vim.api.nvim_win_set_cursor(0, { row + 1, col })
				return
			end
		end

		-- Get the previous sibling of the node
		---@diagnostic disable-next-line: undefined-field
		local sibling = node:prev_sibling()

		-- If a sibling is found
		if sibling then
			-- Get the start position of the sibling
			row, col, _ = sibling:start()

			-- If the current cursor position is not equal to the start position of the sibling
			if cur[1] ~= row + 1 or cur[2] ~= col then
				-- Get the character at the end of the sibling position
				local char = vim.api.nvim_buf_get_text(0, row, col, row, col + 1, {})

				-- If the character at the end of the sibling position is a closing parenthesis, set the cursor
				if closing_parens[char[1]] ~= nil then
					vim.api.nvim_win_set_cursor(0, { row + 1, col })
					return
				end
			end
		end

		-- Set the node to its parent
		---@diagnostic disable-next-line: undefined-field
		node = node:parent()
	end
end

-- Go forward sexp based on treesitter node
M.forward_sexp = function()
	local cur = vim.api.nvim_win_get_cursor(0)
	local node, shift

	-- Determine the current node and shift values based on the mode
	if vim.api.nvim_get_mode().mode == "n" then
		node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})
		shift = 1
	elseif vim.api.nvim_get_mode().mode == "i" then
		node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2] - 1, {})
		shift = 0
	end

	-- Iteratively traverse up the tree and check each node
	while node do
		local row, col, _ = node:end_()
		if cur[1] ~= row + 1 or cur[2] ~= col - shift then
			local char = vim.api.nvim_buf_get_text(0, row, col - 1, row, col, {})
			if closing_parens[char[1]] ~= nil then
				vim.api.nvim_win_set_cursor(0, { row + 1, col - shift })
				return
			end
		end

		-- Check the node's siblings
		local sibling = node:next_sibling()
		if sibling then
			row, col, _ = sibling:end_()
			if cur[1] ~= row + 1 or cur[2] ~= col - shift then
				local char = vim.api.nvim_buf_get_text(0, row, col - 1, row, col, {})
				if closing_parens[char[1]] ~= nil then
					if col - 1 > 0 then
						vim.api.nvim_win_set_cursor(0, { row + 1, col - shift })
					end
					return
				end
			end
		end

		-- Move up the tree
		node = node:parent()
	end
end

-- Wrap treesitter node with char
---@param char string
---@param node? any
M.wrap_node = function(char, node)
	local cur = vim.api.nvim_win_get_cursor(0)

	-- If no node is given, get the node at the given cursor position
	if node == nil then
		node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})
	end

	if node then
		-- Get the text of the node
		---@diagnostic disable-next-line: param-type-mismatch
		local node_text = vim.treesitter.query.get_node_text(node, 0, {})
		---@diagnostic disable-next-line: param-type-mismatch
		node_text = vim.split(node_text, "\n", {})

		-- Get the start and end position of the node
		local start_row, start_col, end_row, end_col = node:range()

		local begin_char, end_char

		if opening_parens[char] ~= nil then
			-- For opening parens, set the begin and end character
			begin_char = char
			--- @type string
			end_char = parens_map[char]

			-- Add the begin and end character to the node text
			node_text[1] = begin_char .. node_text[1]
			node_text[#node_text] = node_text[#node_text] .. end_char
		end

		if closing_parens[char] ~= nil then
			-- For closing parens, set the begin and end character
			begin_char = closing_parens[char]
			--- @type string
			end_char = char

			-- Add the begin and end character to the node text
			node_text[1] = begin_char .. " " .. node_text[1]
			node_text[#node_text] = node_text[#node_text] .. " " .. end_char
		end

		-- Set the text of the node
		vim.api.nvim_buf_set_text(0, start_row, start_col, end_row, end_col, node_text)

		-- Set the cursor position
		vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col + 1 })
	end
end

-- wrap treesitter parent node with cahr
---@param char string
M.wrap_parent_node = function(char)
	local cur = vim.api.nvim_win_get_cursor(0)
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})
	if node then
		---@diagnostic disable-next-line: undefined-field
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
		---@diagnostic disable-next-line: undefined-field
		local parent = node:parent()
		if parent then
			M.wrap_node(char, parent)
		end
	end
end

-- Splice current treesitter node
M.splice_node = function()
	-- Get current cursor position
	local cur = vim.api.nvim_win_get_cursor(0)

	-- Get node at current position
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})

	-- Iterate up the parent nodes to find an opening and closing parens
	while node do
		-- Get the start position of the current node
		---@diagnostic disable-next-line: undefined-field
		local node_row_start, node_col_start, _ = node:start()
		-- Get the end position of the current node
		---@diagnostic disable-next-line: undefined-field
		local node_row_end, node_col_end, _ = node:end_()

		-- Get the characters at the start and end of the node
		local char_start =
			vim.api.nvim_buf_get_text(0, node_row_start, node_col_start, node_row_start, node_col_start + 1, {})[1]
		local char_end = vim.api.nvim_buf_get_text(0, node_row_end, node_col_end - 1, node_row_end, node_col_end, {})[1]

		-- If the characters are opening and closing parens, splice the node
		if opening_parens[char_start] and closing_parens[char_end] then
			-- Delete the characters
			vim.api.nvim_buf_set_text(0, node_row_start, node_col_start, node_row_start, node_col_start + 1, { "" })
			vim.api.nvim_buf_set_text(0, node_row_end, node_col_end - 2, node_row_end, node_col_end - 1, { "" })

			-- Add a highlight to the deleted characters
			local ns_id =
				vim.api.nvim_buf_add_highlight(0, 0, M.default.hl, node_row_start, node_col_start, node_col_start + 1)
			vim.api.nvim_buf_add_highlight(0, ns_id, M.default.hl, node_row_end, node_col_end - 3, node_col_end - 2)

			-- Clear the highlight after 250 ms
			vim.defer_fn(function()
				vim.api.nvim_buf_clear_namespace(0, ns_id, node_row_start, node_row_end + 1)
			end, 250)

			return
		end

		-- Move to the parent node
		---@diagnostic disable-next-line: undefined-field
		node = node:parent()
	end
end

-- Raise current treesitter node and replace parent node
M.raise_node = function()
	-- Get the current cursor position
	local cur = vim.api.nvim_win_get_cursor(0)
	-- Get the current node under the cursor
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})
	-- Iterate up through parent nodes until there are none left
	while node do
		-- Get the start and end positions of the node
		---@diagnostic disable-next-line: undefined-field
		local node_row_start, node_col_start, _ = node:start()
		---@diagnostic disable-next-line: undefined-field
		local node_row_end, node_col_end, _ = node:end_()
		-- Get the text of the node
		local node_text = vim.api.nvim_buf_get_text(0, node_row_start, node_col_start, node_row_end, node_col_end, {})
		-- Get the cursor shift relative to the node start position
		local cur_shift = cur[2] - node_col_start
		-- Get the parent node
		---@diagnostic disable-next-line: undefined-field
		local parent = node:parent()
		if parent then
			-- Get the start and end positions of the parent node
			local parent_row_start, parent_col_start, _ = parent:start()
			local parent_row_end, parent_col_end, _ = parent:end_()
			-- Get the row and column shifts between the node and parent nodes
			local node_row_shift = node_row_start - parent_row_start
			local node_col_shift = node_col_start - parent_col_start
			-- If the node and parent nodes are not equal
			if
				node_row_start ~= parent_row_start
				or node_col_start ~= parent_col_start
				or node_row_end ~= parent_row_end
				or node_col_end ~= parent_col_end
			then
				-- Replace the parent node with the current node
				vim.api.nvim_buf_set_text(
					0,
					parent_row_start,
					parent_col_start,
					parent_row_end,
					parent_col_end,
					node_text
				)
				-- Set the cursor to the parent node start
				vim.api.nvim_win_set_cursor(0, { parent_row_start + 1, parent_col_start + cur_shift })
				-- Create a namespace for the highlight
				local ns_id = vim.api.nvim_create_namespace("pareto_raise")
				-- Highlight the node
				vim.api.nvim_buf_add_highlight(
					0,
					ns_id,
					M.default.hl,
					node_row_start - node_row_shift,
					node_col_start - node_col_shift,
					node_col_end - node_col_shift
				)
				-- Get the lines of the node
				local lines = vim.api.nvim_buf_get_lines(
					0,
					node_row_start - node_row_shift,
					node_row_end + 1 - node_row_shift,
					true
				)
				-- Highlight all lines of the node
				for i, line in ipairs(lines) do
					if i > 1 then
						local empty = string.match(line, "^s*")
						vim.api.nvim_buf_add_highlight(
							0,
							ns_id,
							M.default.hl,
							node_row_start + i - 1 - node_row_shift,
							#empty,
							#line
						)
					end
				end
				-- Clear the highlight after a delay
				vim.defer_fn(function()
					vim.api.nvim_buf_clear_namespace(
						0,
						ns_id,
						node_row_start - node_row_shift,
						node_row_end - node_row_shift + 1
					)
				end, 250)
				-- Return
				return
			else
				-- Set the node to the parent node
				node = parent
			end
		end
	end
end

-- Insert cursor at the beginning of parent sexp node
M.jump_parent_begin = function()
	local cur = vim.api.nvim_win_get_cursor(0)
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})

	-- Iterate up the tree to find the parent with an opening parens
	while node do
		---@diagnostic disable-next-line: undefined-field
		local parent = node:parent()
		if parent then
			local start_row, start_col, _, _ = parent:range()
			---@diagnostic disable-next-line: undefined-field
			local char = vim.fn.getline(start_row + 1):sub(start_col + 1, start_col + 1)

			-- If an opening parens was found, jump to it and start insert mode
			if opening_parens[char] then
				vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col + 1 })
				vim.cmd(":startinsert")
				return
			end
		end
		node = parent
	end
end

M.jump_parent_end = function()
	local cur = vim.api.nvim_win_get_cursor(0)
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})

	while node do
		---@diagnostic disable-next-line: undefined-field
		local parent = node:parent()
		if parent then
			-- Get the end position of the parent node
			local _, _, end_row, end_col = parent:range()

			-- Check if the node starts with opening paren
			---@diagnostic disable-next-line: undefined-field
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

-- Uncomment every line containing comment string
M.uncomment_node = function()
	vim.pretty_print("start 3")

	-- Get the cursor position
	local cur = vim.api.nvim_win_get_cursor(0)

	-- Get the comment string
	local commentstring = vim.api.nvim_buf_get_option(0, "commentstring"):gsub("%s", "")

	-- Function to check if a line contains a comment
	local is_comment = function(xs, col_start)
		return xs:sub(col_start, col_start + #commentstring - 1) == commentstring
	end

	-- Get all lines in the buffer
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

	-- Iterate over the lines above and below the cursor
	for i = -1, #lines do
		if i >= 0 then
			local line = lines[cur[1] - 1 - i]
			vim.pretty_print("line before", line)

			-- If the line contains a comment, replace it with a space
			if is_comment(line, cur[2] + 1) then
				---@diagnostic disable-next-line: undefined-field
				local new_line = line:gsub(commentstring, " ")
				vim.api.nvim_buf_set_lines(0, cur[1] - 2 - i, cur[1] - 1 - i, false, { new_line })
			end
		end

		if i <= #lines then
			local line = lines[cur[1] + i]
			vim.pretty_print("line after", line)

			-- If the line contains a comment, replace it with a space
			if is_comment(line, cur[2] + 1) then
				---@diagnostic disable-next-line: undefined-field
				local new_line = line:gsub(commentstring, " ")
				vim.api.nvim_buf_set_lines(0, cur[1] - 1 + i, cur[1] + i, false, { new_line })
			end
		end
	end
end

---Comment every line of node, place the comment in column where the node starts
M.comment_node = function()
	local cur = vim.api.nvim_win_get_cursor(0)
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})
	local commentstring = vim.api.nvim_buf_get_option(0, "commentstring")
	if node and commentstring then
		---@diagnostic disable-next-line: undefined-field
		local start_row, start_col, end_row, end_col = node:range()

		-- If line contains string other than blankline befor begining of the node inser line before node
		local line = vim.api.nvim_buf_get_lines(0, end_row, end_row + 1, true)[1]
		if line:sub(0, start_col):match("S") then
			local x = line:sub(0, start_col)
			local y = line:sub(start_col + 1)
			vim.pretty_print(x, y)
			vim.api.nvim_buf_set_lines(0, start_row, start_row + 1, false, { x, string.rep(" ", start_col) .. y })
			start_row = start_row + 1
			end_row = end_row + 1
		end

		-- If character after end of node is not end of line inser new line
		if end_col < #vim.fn.getline(end_row + 1) then
			local x = line:sub(0, end_col)
			local y = line:sub(end_col + 1)
			vim.api.nvim_buf_set_lines(0, end_row, end_row + 1, false, { x, string.rep(" ", start_col) .. y })
		end

		-- Comment each line of the node
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

-- Forward slurp node
function M.forward_slurp()
	local cur = vim.api.nvim_win_get_cursor(0)
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2] - 1, {})

	-- Traverse up the tree until the node end is preceded by a closing paren
	while node do
		local node_row, node_col, _ = node:end_()
		local char = vim.api.nvim_buf_get_text(0, node_row, node_col - 1, node_row, node_col, {})[1]
		if closing_parens[char] ~= nil then
			-- Remove the closing paren
			vim.api.nvim_buf_set_text(0, node_row, node_col - 1, node_row, node_col, { "" })

			-- Get the next sibling node
			local sibling_node = node:next_sibling()
			if sibling_node then
				local sibling_row, sibling_col, _ = sibling_node:end_()

				-- Set the closing paren at the end of the sibling node
				vim.api.nvim_buf_set_text(0, sibling_row, sibling_col, sibling_row, sibling_col, { char })

				-- Highlight the closing paren
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

---Backward Slurp Node
-- Move the opening parenthesis of the current node one character to the left
M.backward_slurp = function()
	-- Get the current cursor position
	local cur = vim.api.nvim_win_get_cursor(0)
	-- Get the current node
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2] - 1, {})

	-- Iterate up the tree until we reach the top node
	while node do
		-- Get the row and column of the current node
		local node_row, node_col, _ = node:start()
		-- Get the character at the start of the node
		local char = vim.api.nvim_buf_get_text(0, node_row, node_col, node_row, node_col + 1, {})[1]

		-- If the character is an opening parenthesis...
		if opening_parens[char] ~= nil then
			-- Get the previous sibling of the node
			local sibling_node = node:prev_sibling()
			if sibling_node then
				-- Get the row and column of the sibling node
				local sibling_row, sibling_col, _ = sibling_node:start()
				-- Get the row and column of the parent node of the current node
				local parent_node = node:parent()
				local parent_row, parent_col, _ = parent_node:start()

				-- If the parent and the sibling are not on the same line
				-- or if the sibling is further to the left than the parent,
				-- move the opening parenthesis one character to the left
				if parent_row ~= sibling_row or parent_col < sibling_col - 1 then
					vim.api.nvim_buf_set_text(0, node_row, node_col, node_row, node_col + 1, { "" })
					vim.api.nvim_buf_set_text(0, sibling_row, sibling_col, sibling_row, sibling_col, { char })
					-- Highlight the character we've just moved
					local ns_id =
						vim.api.nvim_buf_add_highlight(0, 0, M.default.hl, sibling_row, sibling_col, sibling_col + 1)
					-- Unhighlight the character after a short delay
					vim.defer_fn(function()
						vim.api.nvim_buf_clear_namespace(0, ns_id, sibling_row, sibling_row + 1)
					end, 250)
				end
				return
			end
		end
		-- Move up the tree to the parent node
		node = node:parent()
	end
end

---Forward barf
M.forward_barf = function()
	local cur = vim.api.nvim_win_get_cursor(0)
	-- Get the node at the cursor position
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})

	-- Iterate up the tree until we find a node with a closing parens
	while node do
		local node_row, node_col, _ = node:end_()
		local char = vim.api.nvim_buf_get_text(0, node_row, node_col - 1, node_row, node_col, {})[1]
		if closing_parens[char] then
			-- Get the third-to-last child of this node
			-- (the first and last are the parentheses)
			local child_count = node:child_count()
			local child_node = node:child(math.max(0, child_count - 3))
			if child_node then
				local child_row, child_col, _ = child_node:end_()
				-- Delete the closing parens
				vim.api.nvim_buf_set_text(0, node_row, node_col - 1, node_row, node_col, { "" })
				-- Replace the third-to-last child with the closing parens
				vim.api.nvim_buf_set_text(0, child_row, child_col, child_row, child_col, { char })
				-- Highlight the closing parens
				local ns_id = vim.api.nvim_buf_add_highlight(0, 0, "incsearch", child_row, child_col, child_col + 1)
				vim.defer_fn(function()
					-- Clear the highlight after 250ms
					vim.api.nvim_buf_clear_namespace(0, ns_id, child_row, child_row + 1)
				end, 250)
				return
			end
		end
		-- Move up the tree
		node = node:parent()
	end
end

---Backward barf
M.backward_barf = function()
	local cur = vim.api.nvim_win_get_cursor(0)

	-- Get the node at the cursor position
	local node = vim.treesitter.get_node_at_pos(0, cur[1] - 1, cur[2], {})

	-- Iterate up through parent nodes until a node with an opening parens is found
	while node do
		local node_row, node_col, _ = node:start()
		local char = vim.api.nvim_buf_get_text(0, node_row, node_col, node_row, node_col + 1, {})[1]

		if opening_parens[char] then
			local child_count = node:child_count()
			local child_node = node:child(math.min(child_count, 2)) --  first and last is paren

			-- If a valid child node is found, move the opening parens to that
			if child_node then
				local child_row, child_col, _ = child_node:start()
				vim.api.nvim_buf_set_text(0, node_row, node_col, node_row, node_col + 1, { "" })
				vim.api.nvim_buf_set_text(0, child_row, child_col - 1, child_row, child_col - 1, { char })

				-- Highlight the moved parens for a brief time
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

vim.keymap.set({ "n", "i" }, "<F7>", function()
	M.raise_node()
end, {})
vim.keymap.set({ "n", "i" }, "<F8>", function()
	M.splice_node()
end, {})

return M
