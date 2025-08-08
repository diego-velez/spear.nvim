local M = {}
local H = {}

local augroup = vim.api.nvim_create_augroup("Spear", { clear = true })

---Open the Spear UI in order to edit the current list
function M.open()
	local bufnr = vim.api.nvim_create_buf(false, true)
	local win_id = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		title = Spear.data.current_list,
		title_pos = "center",
		row = math.floor(vim.o.lines * 0.2),
		col = math.floor(vim.o.columns * 0.2),
		width = math.floor(vim.o.columns * 0.6),
		height = math.floor(vim.o.lines * 0.6),
		style = "minimal",
	})

	H.setup_window(win_id, bufnr)

	local list_paths = vim.tbl_map(function(spear_item)
		return spear_item.name
	end, Spear.get_current_list())
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, list_paths)
end

function H.setup_window(win_id, bufnr)
	-- Needed to be able to :w without getting error because
	-- buffer is not for a file
	if vim.api.nvim_buf_get_name(bufnr) == "" then
		vim.api.nvim_buf_set_name(bufnr, "Spear Buffer")
	end

	vim.api.nvim_set_option_value("number", true, {
		win = win_id,
	})

	vim.api.nvim_set_option_value("filetype", "spear", { buf = bufnr })
	vim.api.nvim_set_option_value("buftype", "acwrite", { buf = bufnr })

	vim.keymap.set("n", "q", function()
		H.close_menu(bufnr, win_id)
	end, { buffer = bufnr, silent = true })
	vim.keymap.set("n", "<esc>", function()
		H.close_menu(bufnr, win_id)
	end, { buffer = bufnr, silent = true })
	vim.keymap.set("n", "<cr>", function()
		local index = vim.fn.line(".")
		H.save_buffer(bufnr)
		H.close_menu(bufnr, win_id)
		Spear.select(index)
	end, { buffer = bufnr, silent = true })

	vim.api.nvim_create_autocmd({ "BufWriteCmd" }, {
		group = augroup,
		buffer = bufnr,
		callback = function()
			H.save_buffer(bufnr)
			H.close_menu(bufnr, win_id)
		end,
	})

	vim.api.nvim_create_autocmd({ "BufLeave" }, {
		group = augroup,
		buffer = bufnr,
		callback = function()
			H.close_menu(bufnr, win_id)
		end,
	})
end

function H.save_buffer(bufnr)
	local ui_list = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	ui_list = H.remove_duplicates(ui_list)

	-- Remove files that do not exist
	ui_list = vim.tbl_filter(function(path)
		return vim.fn.filereadable(path) == 1
	end, ui_list)

	local spear_list = vim.tbl_map(H.ui_path_to_spear_entry, ui_list)
	Spear.data.lists[Spear.data.current_list] = spear_list
end

function H.close_menu(bufnr, win_id)
	vim.schedule(function()
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end

		if vim.api.nvim_win_is_valid(win_id) then
			vim.api.nvim_win_close(win_id, true)
		end
	end)
end

---@param paths table<string>
function H.remove_duplicates(paths)
	local seen = {}
	local result = {}

	for _, path in ipairs(paths) do
		if not seen[path] then
			seen[path] = true
			table.insert(result, path)
		end
	end

	return result
end

---@param path string
function H.ui_path_to_spear_entry(path)
	local buffer_name = Spear.get_buffer_name(path)

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
	return list_item
end

return M
