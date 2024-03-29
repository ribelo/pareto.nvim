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

local function format_range(start_row, start_col, end_row, end_col)
	local row_diff = end_row - start_row
	local col_diff = end_col - start_col
	vim.pretty_print(start_row, start_col, end_row, end_col)
	vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
	local cmd = "v"
	if row_diff > 0 then
		cmd = cmd .. string.rep("j", row_diff + 1)
	else
		cmd = cmd .. string.rep("k", row_diff + 1)
	end
	-- if col_diff > 0 then
	-- 	cmd = cmd .. "0" .. string.rep("l", end_col - 1)
	-- else
	-- 	cmd = cmd .. "0"
	-- 	string.rep("h", end_col - 1)
	-- end
	cmd = cmd .. "="
	vim.api.nvim_feedkeys(cmd, "n", true)
	-- vim.defer_fn(function()
	-- 	vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
	-- end, 250)
	vim.schedule(function()
		vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
	end)
end

---Backward Node
M.backward_node = function()
	local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))

	-- Get the node at the current position
	local node = vim.treesitter.get_node({ buffer = 0, pos = { cur_row - 1, cur_col } })

	-- Iterate over the parent nodes of the current node
	while node do
		---@diagnostic disable-next-line: undefined-field
		local row, col, _ = node:start()

		-- If the current position is not the same as the node start
		-- set the cursor to the node start position and return
		if cur_row ~= row + 1 or cur_col ~= col then
			vim.api.nvim_win_set_cursor(0, { row + 1, col })
			return
		end

		-- Get the previous sibling of the current node
		---@diagnostic disable-next-line: undefined-field
		local sibling = node:prev_sibling()

		-- If a sibling exists, check the start position.
		-- set the cursor to the node start position and return
		if sibling then
			local sibling_row, sibling_col, _ = sibling:start()
			-- If the current position is not the same as the node start
			if cur_row ~= sibling_row + 1 or cur_col ~= sibling_col then
				vim.api.nvim_win_set_cursor(0, { sibling_row + 1, sibling_col })
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
	local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
	local node, shift

	-- Set node and shift depending on mode
	if vim.api.nvim_get_mode().mode == "n" then
		node = vim.treesitter.get_node({ buffer = 0, pos = { cur_row - 1, cur_col } })
		shift = 1
	elseif vim.api.nvim_get_mode().mode == "i" then
		node = vim.treesitter.get_node({ buffer = 0, pos = { cur_row - 1, cur_col - 1 } })
		shift = 0
	end

	-- Iterate over tree nodes
	while node do
		-- Get node end position
		local row, col, _ = node:end_()

		-- Check if not at the same position
		if cur_row ~= row + 1 or cur_col ~= col - shift then
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
			if cur_row ~= row + 1 or cur_col ~= col - shift then
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
	local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))

	-- Get the node at the current cursor position
	local node = vim.treesitter.get_node({ buffer = 0, pos = { cur_row - 1, cur_col } })

	-- Keep looping until a node is found or it reaches the root node
	while node do
		-- Get the start position of the node
		---@diagnostic disable-next-line: undefined-field
		local sibling_row, sibling_col, _ = node:start()

		-- If the current cursor position is not equal to the start position of the node
		if cur_row ~= sibling_row + 1 or cur_col ~= sibling_col then
			-- Get the character at the end of the node position
			local char = vim.api.nvim_buf_get_text(0, sibling_row, sibling_col, sibling_row, sibling_col + 1, {})

			-- If the character at the end of the node position is an opening parenthesis, set the cursor
			if opening_parens[char[1]] ~= nil then
				vim.api.nvim_win_set_cursor(0, { sibling_row + 1, sibling_col })
				return
			end
		end

		-- Get the previous sibling of the node
		---@diagnostic disable-next-line: undefined-field
		local sibling = node:prev_sibling()

		-- If a sibling is found
		if sibling then
			-- Get the start position of the sibling
			sibling_row, sibling_col, _ = sibling:start()

			-- If the current cursor position is not equal to the start position of the sibling
			if cur_row ~= sibling_row + 1 or cur_col ~= sibling_col then
				-- Get the character at the end of the sibling position
				local char = vim.api.nvim_buf_get_text(0, sibling_row, sibling_col, sibling_row, sibling_col + 1, {})

				-- If the character at the end of the sibling position is a closing parenthesis, set the cursor
				if closing_parens[char[1]] ~= nil then
					vim.api.nvim_win_set_cursor(0, { sibling_row + 1, sibling_col })
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
	local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
	local node, shift

	-- Determine the current node and shift values based on the mode
	if vim.api.nvim_get_mode().mode == "n" then
		node = vim.treesitter.get_node({ buffer = 0, pos = { cur_row - 1, cur_col } })
		shift = 1
	elseif vim.api.nvim_get_mode().mode == "i" then
		node = vim.treesitter.get_node({ buffer = 0, pos = { cur_row - 1, cur_col - 1 } })
		shift = 0
	end

	-- Iteratively traverse up the tree and check each node
	while node do
		local row, col, _ = node:end_()
		if cur_row ~= row + 1 or cur_col ~= col - shift then
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
			if cur_row ~= row + 1 or cur_col ~= col - shift then
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
	local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))

	-- If no node is given, get the node at the given cursor position
	if node == nil then
		node = vim.treesitter.get_node({ buffer = 0, pos = { cur_row - 1, cur_col } })
	end

	if node then
		-- Get the text of the node
		local node_text = vim.treesitter.get_node_text(node, 0, {})
		---@diagnostic disable-next-line: cast-local-type
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
	local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
	local node = vim.treesitter.get_node({ buffer = 0, pos = { cur_row - 1, cur_col } })
	if node then
		---@diagnostic disable-next-line: undefined-field
		node = node:parent()
		M.wrap_node(char, node)
	end
end

-- wrap treesitter node with char
---@param char string
M.wrap_current_node = function(char)
	local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
	local node = vim.treesitter.get_node({ buffer = 0, pos = { cur_row - 1, cur_col } })
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
	local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))

	-- Get node at current position
	local node = vim.treesitter.get_node({ buffer = 0, pos = { cur_row - 1, cur_col } })

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
	local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
	-- Get the current node under the cursor
	local node = vim.treesitter.get_node({ buffer = 0, pos = { cur_row - 1, cur_col } })
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
		local cur_shift = cur_col - node_col_start
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
	local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
	local node = vim.treesitter.get_node({ buffer = 0, pos = { cur_row - 1, cur_col } })

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
	local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
	local node = vim.treesitter.get_node({ buffer = 0, pos = { cur_row - 1, cur_col } })

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
	local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))

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
			local line = lines[cur_row - 1 - i]
			vim.pretty_print("line before", line)

			-- If the line contains a comment, replace it with a space
			if is_comment(line, cur_col + 1) then
				---@diagnostic disable-next-line: undefined-field
				local new_line = line:gsub(commentstring, " ")
				vim.api.nvim_buf_set_lines(0, cur_row - 2 - i, cur_row - 1 - i, false, { new_line })
			end
		end

		if i <= #lines then
			local line = lines[cur_row + i]
			vim.pretty_print("line after", line)

			-- If the line contains a comment, replace it with a space
			if is_comment(line, cur_col + 1) then
				---@diagnostic disable-next-line: undefined-field
				local new_line = line:gsub(commentstring, " ")
				vim.api.nvim_buf_set_lines(0, cur_row - 1 + i, cur_row + i, false, { new_line })
			end
		end
	end
end

---Comment every line of node, place the comment in column where the node starts
M.comment_node = function()
	local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
	local node = vim.treesitter.get_node({ buffer = 0, pos = { cur_row - 1, cur_col } })
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
	local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
	local node = vim.treesitter.get_node({ buffer = 0, pos = { cur_row - 1, cur_col } })

	-- Traverse up the tree until the node end is preceded by a closing paren
	while node do
		-- Get the end (row, column) position of a node
		local node_row, node_col, _ = node:end_()
		-- Get the text of the node as a string
		local node_text = vim.treesitter.get_node_text(node, 0, {})
		-- Get the last character of the text string
		local last_char = node_text:sub(-1)
		if closing_parens[last_char] then
			-- Get the next sibling node
			local sibling_node = node:next_named_sibling()
			-- If there is a sibling node,
			if sibling_node then
				local sibling_row, sibling_col, _ = sibling_node:end_()
				-- Remove node closing paren,
				vim.api.nvim_buf_set_text(0, node_row, node_col - 1, node_row, node_col, { "" })
				-- Calculate the shift of the opening paren
				local shift = 0
				if node_row == sibling_row then
					shift = 1
				end
				-- Set the closing paren at the end of the sibling node,
				vim.api.nvim_buf_set_text(
					0,
					sibling_row,
					sibling_col - shift,
					sibling_row,
					sibling_col - shift,
					{ last_char }
				)
				-- Highlight the closing paren
				local ns_id =
					vim.api.nvim_buf_add_highlight(0, 0, M.default.hl, sibling_row, sibling_col, sibling_col + 1)
				-- Unhighlight the character after a short delay
				vim.defer_fn(function()
					vim.api.nvim_buf_clear_namespace(0, ns_id, sibling_row, sibling_row + 1)
				end, 250)
				return
			else
				-- If there is no sibling node,
				-- return from the function
				return
			end
		end
		-- Traverse up the syntax tree to the parent node
		node = node:parent()
	end
end

---Backward Slurp Node
M.backward_slurp = function()
	-- Get the current cursor position
	local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
	-- Get the current node
	local node = vim.treesitter.get_node({ buffer = 0, pos = { cur_row - 1, cur_col } })

	-- Iterate up the tree until we reach the top node
	while node do
		-- Get the row and column of the current node
		local node_row, node_col, _ = node:start()
		-- Get the text of the node as a string
		local node_text = vim.treesitter.get_node_text(node, 0, {})
		-- Get the first character of the text string
		local first_char = node_text:sub(1, 1)

		-- If the character is an opening parenthesis...
		if opening_parens[first_char] then
			-- Get the previous sibling of the node
			local sibling_node = node:prev_named_sibling()
			if sibling_node then
				local sibling_row, sibling_col, _ = sibling_node:start()
				-- Remove node opening paren,
				vim.api.nvim_buf_set_text(0, node_row, node_col, node_row, node_col + 1, { "" })
				-- Calculate the shift of the closing paren
				local shift = 0
				if node_row == sibling_row then
					shift = 1
				end
				-- Set the opening paren at the begining of the sibling node,
				vim.api.nvim_buf_set_text(
					0,
					sibling_row,
					sibling_col + shift,
					sibling_row,
					sibling_col + shift,
					{ first_char }
				)
				-- Highlight the closing paren
				local ns_id =
					vim.api.nvim_buf_add_highlight(0, 0, M.default.hl, sibling_row, sibling_col, sibling_col + 1)
				-- Unhighlight the character after a short delay
				vim.defer_fn(function()
					vim.api.nvim_buf_clear_namespace(0, ns_id, sibling_row, sibling_row + 1)
				end, 250)
				return
			else
				-- If there is no sibling node,
				-- return from the function
				return
			end
		end
		-- Move up the tree to the parent node
		node = node:parent()
	end
end

---Forward barf
M.forward_barf = function()
	local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
	-- Get the node at the cursor position
	local node = vim.treesitter.get_node({ buffer = 0, pos = { cur_row - 1, cur_col } })

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
	local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))

	-- Get the node at the cursor position
	local node = vim.treesitter.get_node({ buffer = 0, pos = { cur_row - 1, cur_col } })

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

M.split_node = function()
	local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))

	-- Get the node at the cursor position
	local cursor_node = vim.treesitter.get_node({ buffer = 0, pos = { cur_row - 1, cur_col } })
	if not cursor_node then
		-- No cursor node found
		return
	end

	-- Get the start and end positions of the node node
	local node_start_row, node_start_col, _ = cursor_node:start()
	local node_end_row, node_end_col, _ = cursor_node:end_()

	-- Split the node node into two nodes
	local before_node_text = vim.api.nvim_buf_get_text(0, node_start_row, node_start_col, cur_row - 1, cur_col, {})
	local after_node_text = vim.api.nvim_buf_get_text(0, cur_row - 1, cur_col, node_end_row, node_end_col, {})

	-- Get first and last char of node
	local first_char =
		vim.api.nvim_buf_get_text(0, node_start_row, node_start_col, node_start_row, node_start_col + 1, {})[1]
	local last_char = vim.api.nvim_buf_get_text(0, node_end_row, node_end_col - 1, node_end_row, node_end_col, {})[1]

	-- Insert new text
	vim.api.nvim_buf_set_text(
		0,
		node_start_row,
		node_start_col,
		node_end_row,
		node_end_col,
		{ before_node_text[1] .. last_char .. " " .. first_char .. vim.trim(after_node_text[1]) }
	)
	-- Move cursor to the right
	vim.api.nvim_win_set_cursor(0, { cur_row, cur_col + 1 })
end

M.move_node_left = function()
	-- Get the current node
	local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
	local cur_node = vim.treesitter.get_node({ buffer = 0, pos = { cur_row - 1, cur_col } })

	while cur_node do
		-- Get the previous sibling node
		local prev_sibling = cur_node:prev_sibling()
		if not prev_sibling then
			cur_node = cur_node:parent()
		else
			-- Get the node text
			local cur_start_row, cur_start_col, cur_end_row, cur_end_col = cur_node:range()
			local node_text = vim.api.nvim_buf_get_text(0, cur_start_row, cur_start_col, cur_end_row, cur_end_col, {})

			-- Get the sibling text
			local prev_start_row, prev_start_col, prev_end_row, prev_end_col = prev_sibling:range()
			local sibling_text =
				vim.api.nvim_buf_get_text(0, prev_start_row, prev_start_col, prev_end_row, prev_end_col, {})

			-- Check if sibling_text is't paren
			if parens_map[sibling_text[1]] then
				--- We don't want to change the position of parentheses
				return
			end

			local new_text = {}

			-- Add the current node text
			for _, x in ipairs(node_text) do
				table.insert(new_text, x)
			end

			-- Add the previous sibling text
			for i, x in ipairs(sibling_text) do
				if prev_end_row == cur_start_row and i == 1 then
					new_text[#new_text] = new_text[#new_text] .. " " .. x
				else
					local indent = string.rep(" ", cur_start_col)
					table.insert(new_text, indent .. x)
				end
			end
			-- Replace the previous sibling text with the new text
			vim.api.nvim_buf_set_text(0, prev_start_row, prev_start_col, cur_end_row, cur_end_col, new_text)
			-- Done
			return
		end
	end
end

M.move_node_right = function()
	-- Get the current node
	local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
	local cur_node = vim.treesitter.get_node({ buffer = 0, pos = { cur_row - 1, cur_col } })
	-- Get the next sibling node
	while cur_node do
		local next_sibling = cur_node:next_sibling()
		if not next_sibling then
			cur_node = cur_node:parent()
		else
			-- Get the current node text
			local cur_start_row, cur_start_col, cur_end_row, cur_end_col = cur_node:range()
			local node_text = vim.api.nvim_buf_get_text(0, cur_start_row, cur_start_col, cur_end_row, cur_end_col, {})

			-- Get the next sibling node text
			local next_start_row, next_start_col, next_end_row, next_end_col = next_sibling:range()
			local sibling_text =
				vim.api.nvim_buf_get_text(0, next_start_row, next_start_col, next_end_row, next_end_col, {})
			-- Check if sibling_text is't paren
			if parens_map[sibling_text[1]] then
				--- We don't want to change the position of parentheses
				return
			end

			local new_text = {}

			-- Add the next sibling text
			for i, x in ipairs(sibling_text) do
				if cur_end_row == next_start_row and i == #sibling_text then
					table.insert(new_text, x .. " " .. node_text[1])
				else
					table.insert(new_text, x)
				end
			end

			-- Add the current node text
			for i, x in ipairs(node_text) do
				if cur_end_row == next_start_row and i == 1 then
				else
					local indent = string.rep(" ", cur_start_col)
					table.insert(new_text, indent .. x)
				end
			end

			-- Replace the both sibling text with the new text
			vim.api.nvim_buf_set_text(0, cur_start_row, cur_start_col, next_end_row, next_end_col, new_text)

			vim.api.nvim_win_set_cursor(0, { cur_start_col, cur_col + #sibling_text[#sibling_text] })
			-- Done
			return
		end
	end
end

vim.keymap.set({ "n", "i" }, "<F7>", function()
	M.backward_slurp()
end, {})
vim.keymap.set({ "n", "i" }, "<F8>", function()
	M.forward_slurp()
end, {})

return M
