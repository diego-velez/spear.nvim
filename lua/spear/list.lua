local Path = require("plenary.path")

local List = {}
local H = {}

---Adds the current buffer to the current Spear list
function List.add()
	local buffer_name = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
	buffer_name = H.get_spear_name(buffer_name)

	-- Do not add file to list if it's already in the list
	if H.list_contains_file(buffer_name) then
		return
	end

	local bufnr = vim.fn.bufnr(buffer_name)

	local cursor_pos = { row = 1, col = 0 }
	if bufnr ~= -1 then
		local pos = vim.api.nvim_win_get_cursor(0)
		cursor_pos.row = pos[1]
		cursor_pos.col = pos[2]
	end

	local list_item = {
		name = buffer_name,
		position = {
			row = cursor_pos.row,
			col = cursor_pos.col,
		},
	}

	table.insert(Spear.get_current_list(), list_item)
end

---@param index number
function List.select(index)
	-- Don't do anything if the file list does not contain that file
	if index > #Spear.get_current_list() then
		return
	end

	local list_item = Spear.get_current_list()[index]
	local bufnr = vim.fn.bufnr(list_item.name)

	local needs_to_create_buffer = bufnr == -1
	if needs_to_create_buffer then
		bufnr = vim.fn.bufadd(list_item.name)
	end

	if not vim.api.nvim_buf_is_loaded(bufnr) then
		vim.fn.bufload(bufnr)
		vim.api.nvim_set_option_value("buflisted", true, { buf = bufnr })
	end

	vim.api.nvim_set_current_buf(bufnr)

	if needs_to_create_buffer then
		vim.api.nvim_win_set_cursor(0, {
			list_item.position.row,
			list_item.position.col,
		})
	end
	vim.cmd.normal({ "zz", bang = true })
end

---@param path string The path of the file of the buffer
---@return string path The relative path name to the file of the buffer
function H.get_spear_name(path)
	return Path:new(path):make_relative(vim.uv.cwd())
end

---Checks if the current project list contains a file
---@param buffer_name string The buffer file name to look for
---@return boolean
function H.list_contains_file(buffer_name)
	for i = 1, #Spear.get_current_list() do
		local item = Spear.get_current_list()[i]
		if item.name == buffer_name then
			return true
		end
	end
	return false
end

return List
