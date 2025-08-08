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
	require("spear.list").add()
end

---@param index number
Spear.select = function(index)
	require("spear.list").select(index)
end

---Create a new Spear list. Will prompt user for name.
Spear.create = function()
	vim.ui.input({ prompt = "Name of new list: " }, function(input)
		if not input or input == "" then
			return
		end

		Spear.data.current_list = input
		Spear.data.lists[input] = {}
	end)
end

---Deletes a Spear list. Will prompt the user to select which list to delete.
Spear.delete = function()
	if #Spear.data.lists == 1 then
		return
	end

	local items = vim.tbl_keys(Spear.data.lists)
	items = vim.tbl_filter(function(list)
		return list ~= Spear.data.current_list
	end, items)
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
