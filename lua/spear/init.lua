---@diagnostic disable: missing-fields

---@class CursorPosition
---@field row number
---@field col number

---@class SpearListEntry
---@field name string
---@field position CursorPosition

---@class SpearList
---@field [string] SpearListEntry[]

---@class SpearData
---@field current_list string
---@field lists SpearList

---@class Spear
---@field data SpearData
---@field setup fun()
---@field add fun()
---@field remove fun()
---@field select fun(index:number)
---@field create fun()
---@field delete fun()
---@field switch fun()
---@field rename fun()
---@field debug fun()
local Spear = {}
local H = {}

local Path = require("plenary.path")

local plugin_folder = "spear.nvim"
H.nvim_data_path = Path:new(string.format("%s/%s", vim.fn.stdpath("data"), plugin_folder))

Spear.setup = function()
	_G.Spear = Spear

	if not H.nvim_data_path:exists() then
		H.nvim_data_path:mkdir()
	end

	H.create_autocmds()

	Spear.data = H.load_data()
end

Spear.add = function()
	local buffer_name = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
	buffer_name = Spear.get_buffer_name(buffer_name)

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

Spear.remove = function()
	if #Spear.get_current_list() == 0 then
		return
	end

	vim.ui.select(Spear.get_current_list(), {
		prompt = "Which file do you want to delete?",
		format_item = function(item)
			return item.name
		end,
	}, function(item)
		if not item then
			return
		end

		local _, i = H.get_item_by_name(item.name)
		table.remove(Spear.get_current_list(), i)
	end)
end

---@param index number
Spear.select = function(index)
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

Spear.create = function()
	vim.ui.input({ prompt = "Name of new list: " }, function(input)
		if not input or input == "" then
			return
		end

		Spear.data.current_list = input
		Spear.data.lists[input] = {}
	end)
end

Spear.delete = function()
	if #Spear.data.lists == 1 then
		return
	end

	local items = vim.tbl_keys(Spear.data.lists)
	vim.ui.select(items, { prompt = "Which list would you like to delete?" }, function(list)
		if not list then
			return
		end

		-- Switch current list if we are going to delete it
		if list == Spear.data.current_list then
			vim.notify("Cannot delete currently selected list", vim.log.levels.WARN)
			return
		end

		Spear.data.lists[list] = nil
	end)
end

Spear.switch = function()
	local items = vim.tbl_keys(Spear.data.lists)
	local picker_name = "Current List: " .. Spear.data.current_list
	vim.ui.select(items, { prompt = picker_name }, function(item)
		if not item then
			return
		end

		Spear.data.current_list = item
		local notification_msg = string.format("Switched to %s list", item)
		vim.notify(notification_msg, vim.log.levels.INFO)
	end)
end

Spear.rename = function()
	local prompt = string.format("Rename %s to: ", Spear.data.current_list)
	vim.ui.input({ prompt = prompt }, function(input)
		if not input or input == "" then
			return
		end

		Spear.data.lists[input] = Spear.get_current_list()
		Spear.data.lists[Spear.data.current_list] = nil
		Spear.data.current_list = input
	end)
end

Spear.debug = function()
	vim.print(vim.inspect(Spear.data))
end

---@return SpearListEntry[]
Spear.get_current_list = function()
	local current_list = Spear.data.current_list
	return Spear.data.lists[current_list]
end

H.create_autocmds = function()
	local augroup = vim.api.nvim_create_augroup("DVT Harpoon", {})
	vim.api.nvim_create_autocmd("BufLeave", {
		group = augroup,
		pattern = "*",
		callback = function(event)
			local bufnr = event.buf
			local bufname = Spear.get_buffer_name(vim.api.nvim_buf_get_name(bufnr))
			local item = H.get_item_by_name(bufname)

			if item then
				local pos = vim.api.nvim_win_get_cursor(0)

				item.position.row = pos[1]
				item.position.col = pos[2]
			end
		end,
	})
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = augroup,
		pattern = "*",
		callback = function()
			H.save_data()
		end,
	})
end

---@return string path The path to the current project json
H.path_to_project_list = function()
	---@diagnostic disable-next-line: param-type-mismatch
	local filename = vim.fn.sha256(vim.uv.cwd())
	return string.format("%s/%s.json", H.nvim_data_path, filename)
end

---@param buffer_name string The path of the file of the buffer
---@return string path The relative path name to the file of the buffer
Spear.get_buffer_name = function(buffer_name)
	return Path:new(buffer_name):make_relative(vim.uv.cwd())
end

---Checks if the current project list contains a file
---@param buffer_name string The buffer file name to look for
---@return boolean
H.list_contains_file = function(buffer_name)
	for i = 1, #Spear.get_current_list() do
		local item = Spear.get_current_list()[i]
		if item.name == buffer_name then
			return true
		end
	end
	return false
end

---Gets a [list item](lua://SpearListEntry) based on the buffer file name
---@param buffer_name string
---@return SpearListEntry?
---@return number?
H.get_item_by_name = function(buffer_name)
	for i = 1, #Spear.get_current_list() do
		local list_item = Spear.get_current_list()[i]
		if list_item.name == buffer_name then
			return list_item, i
		end
	end
	return nil, nil
end

---The [project data](lua://SpearData) to write to the project's JSON data file
---@param data SpearData
H.write_data = function(data)
	local path_to_project_file = Path:new(H.path_to_project_list())
	local json_encoded_list = vim.json.encode(data)
	path_to_project_file:write(json_encoded_list, "w")
end

---Gets the [project data](lua://SpearData) for this project
---@return SpearData
H.load_data = function()
	local path_to_project_list = Path:new(H.path_to_project_list())
	if not path_to_project_list:exists() then
		H.write_data(H.initial_data)
	end

	local file_data = path_to_project_list:read()

	if not file_data or file_data == "" then
		H.write_data(H.initial_data)
		file_data = vim.json.encode(H.initial_data)
	end

	return vim.json.decode(file_data)
end

---Writes the [project data](lua://SpearData) to the project JSON file
H.save_data = function()
	H.write_data(Spear.data)
end

---Default initial data if there is none
---@type SpearData
H.initial_data = {
	current_list = "Default List",
	lists = {
		["Default List"] = {},
	},
}

return Spear
