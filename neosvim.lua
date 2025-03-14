local M = {}

local function add_to_path(path)
	if not package.path:find(path, 1, true) then
		package.path = path .. "/?.lua;" .. package.path
	end
end

local function set_config_path(path)
	-- Store original if not already stored
	vim._original_stdpath = vim._original_stdpath or vim.fn.stdpath
	
	-- Override stdpath
	vim.fn.stdpath = function(what)
	if what == "config" then
		return path
	end
		return vim._original_stdpath(what)
	end
end

local config_path = vim.fn.stdpath("config")
local neosvim_path = config_path .. "/NeoSvim"
local lua_path = neosvim_path .. "/lua"

set_config_path(neosvim_path)
add_to_path(lua_path)

M.switch_logs = {} -- Store logs in memory

-- Function to restore to initial state
function M:show_logs()
	if #self.switch_logs == 0 then
		vim.notify("No logs available", vim.log.levels.INFO)
		return
	end

	-- Create a new buffer for logs
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, self.switch_logs)

	-- Create window options
	local width = math.min(120, math.floor(vim.o.columns * 0.8))
	local height = math.min(30, math.floor(vim.o.lines * 0.8))
	local ui = vim.api.nvim_list_uis()[1]
	local col = math.floor((ui.width - width) / 2)
	local row = math.floor((ui.height - height) / 2)

	local opts = {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		style = "minimal",
		border = "rounded",
		title = " NeoSvim Switch Logs "
	}

	-- Open window
	local win = vim.api.nvim_open_win(buf, true, opts)

	-- Set buffer options
	vim.api.nvim_set_option_value("modifiable", true, {buf = buf})
	vim.api.nvim_set_option_value("buftype", "nofile", {buf = buf})
	vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
	vim.api.nvim_set_option_value("filetype", "log", {buf = buf})

	-- Add key mappings
	vim.api.nvim_buf_set_keymap(buf, 'n', 'q', 
		'<cmd>lua vim.api.nvim_win_close(' .. win .. ', true)<CR>', 
		{noremap = true, silent = true})

	-- Scroll to bottom
	vim.api.nvim_win_set_cursor(win, {#self.switch_logs, 0})

	vim.notify("Showing NeoSvim switch logs (press 'q' to close)", vim.log.levels.INFO)

	return win, buf
end
function M:popup_input(prompt, callback)
	local buf = vim.api.nvim_create_buf(false, true)

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {prompt, ""})

	-- Calculate dimensions
	local width = math.max(60, #prompt + 4)
	local height = 2

	-- Get editor dimensions
	local ui = vim.api.nvim_list_uis()[1]

	-- Calculate centered position
	local col = math.floor((ui.width - width) / 2)
	local row = math.floor((ui.height - height) / 2)

	-- Create floating window
	local opts = {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		style = "minimal",
		border = "rounded"
	}

	local win = vim.api.nvim_open_win(buf, true, opts)

	-- Set buffer options for input
	vim.api.nvim_set_option_value("modifiable", true, {buf = buf})
	vim.api.nvim_set_option_value("buftype", "prompt", {buf = buf})

	vim.fn.prompt_setprompt(buf, "")
	-- Cancel on ESC
	vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', 
		'<Esc>:lua vim.api.nvim_win_close(' .. win .. ', true)<CR>', 
		{noremap = true, silent = true})

	vim.api.nvim_buf_set_keymap(buf, 'n', 'p', '"+p', 
		{ noremap = true, desc = "Paste from system clipboard" })

	-- Store callback in a global table indexed by buffer id
	if not _G.neosvim_callbacks then
		_G.neosvim_callbacks = {}
	end
	_G.neosvim_callbacks[buf] = callback

	-- Add normal mode Enter key mapping
	vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>',
		':lua require("neosvim"):_handle_normal_enter(' .. buf .. ', ' .. win .. ')<CR>',
		{noremap = true, silent = true})

	vim.defer_fn(function ()
		vim.api.nvim_set_current_win(win)

		-- Move cursor to the input line
		vim.api.nvim_win_set_cursor(win, {2, 0})
	end, 100)

	-- Set prompt callback
	vim.fn.prompt_setcallback(buf, function(text)
		-- Get the callback before closing anything
		local cb = _G.neosvim_callbacks[buf]
		-- Clean up
		_G.neosvim_callbacks[buf] = nil
		vim.api.nvim_win_close(win, true)
		-- Call the callback if it exists
		if cb then
			cb(text)
		end
	end)

	return win, buf
end

-- Helper function to handle Enter in normal mode
function M:_handle_normal_enter(buf, win)
	-- Safety check
	if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_win_is_valid(win) then
		return
	end

	-- Get the input text (line 2)
	local text = vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1]

	-- Get the callback before closing anything
	local callback = _G.neosvim_callbacks and _G.neosvim_callbacks[buf]
	-- Clean up
	if _G.neosvim_callbacks then
		_G.neosvim_callbacks[buf] = nil
	end

	-- Close the window
	vim.api.nvim_win_close(win, true)

	-- Call the callback if it exists
	if callback then
		callback(text)
	end
end

function M:delete_dir(dir_path)
	-- Use system commands for efficient directory removal
	local os_name = jit.os
	local command

	if os_name == "Windows" then
		command = string.format('rmdir /S /Q "%s"', dir_path:gsub('/', '\\'))
	else
		command = string.format('rm -rf "%s"', dir_path)
	end

	os.execute(command)
end

function M:run_init()
	self:setup_commands()

	-- Try to source the init files with full paths
	local init_lua = neosvim_path .. "/init.lua"
	local init_vim = neosvim_path .. "/init.vim"

	local sourced = false

	if vim.fn.filereadable(init_lua) == 1 then
		local success, err = pcall(vim.cmd, "source " .. init_lua)
		if success then
			sourced = true
			vim.notify("Sourced " .. init_lua, vim.log.levels.INFO)
		else
			vim.notify("Error sourcing " .. init_lua .. ": " .. tostring(err), vim.log.levels.ERROR)
		end
	elseif vim.fn.filereadable(init_vim) == 1 then
		local success, err = pcall(vim.cmd, "source " .. init_vim)
		if success then
			sourced = true
			vim.notify("Sourced " .. init_vim, vim.log.levels.INFO)
		else
			vim.notify("Error sourcing " .. init_vim .. ": " .. tostring(err), vim.log.levels.ERROR)
		end
	end

	if not sourced then
		vim.notify("Something went wrong", vim.log.levels.ERROR)
		return false
	end

	return true
end

function M:ask_repo()
	self:popup_input("Enter the repo URL", function (url)
		self:switch(url)
	end)
end

function M:directory_exists(dir_path)
	local stat = vim.loop.fs_stat(dir_path)
	return stat and stat.type == "directory"
end

function M:git_clone(url, callback)
	-- Clear previous logs
	self.switch_logs = {"=== NeoSvim Switch Logs ===", "Cloning " .. url .. " to " .. neosvim_path .. "...", ""}

	-- Create a buffer for showing progress
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"Cloning " .. url .. " to " .. neosvim_path .. "...", ""})

	-- Create a floating window for progress
	local width = math.min(120, math.floor(vim.o.columns * 0.8))
	local height = math.min(20, math.floor(vim.o.lines * 0.8))
	local ui = vim.api.nvim_list_uis()[1]
	local col = math.floor((ui.width - width) / 2)
	local row = math.floor((ui.height - height) / 2)

	local opts = {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		style = "minimal",
		border = "rounded",
		title = " Git Clone Progress "
	}

	local win = vim.api.nvim_open_win(buf, true, opts)

	-- Set up the job with callbacks
	local stdout_data = {}
	local stderr_data = {}
	local exit_code

	-- Determine the shell command based on OS
	local cmd = {"git", "clone", "--progress", url, neosvim_path}

	-- Function to append output to the buffer
	local function append_to_buffer(data, is_stderr)
		if not data or #data == 0 then return end

		-- Process lines, handling carriage returns properly
		if is_stderr then
			for _, line in ipairs(data) do
				if line and line ~= "" then
					-- Replace carriage returns with actual line breaks
					line = line:gsub("\r", "\n")
					-- Split by newlines in case multiple lines were created
					for _, split_line in ipairs(vim.split(line, "\n")) do
						if split_line ~= "" then
							table.insert(stderr_data, split_line)
							table.insert(self.switch_logs, "[stderr] " .. split_line)
						end
					end
				end
			end
		else
			for _, line in ipairs(data) do
				if line and line ~= "" then
					-- Replace carriage returns with actual line breaks
					line = line:gsub("\r", "\n")
					-- Split by newlines in case multiple lines were created
					for _, split_line in ipairs(vim.split(line, "\n")) do
						if split_line ~= "" then
							table.insert(stdout_data, split_line)
							table.insert(self.switch_logs, "[stdout] " .. split_line)
						end
					end
				end
			end
		end

		-- Update buffer with all collected data
		local display_lines = {"Cloning " .. url .. " to " .. neosvim_path .. "..."}
		for _, line in ipairs(stdout_data) do
			table.insert(display_lines, line)
		end
		for _, line in ipairs(stderr_data) do
			table.insert(display_lines, line)
		end

		-- If window is still valid, update it
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)
			-- Scroll to bottom
			if #display_lines > 0 then
				vim.api.nvim_win_set_cursor(win, {#display_lines, 0})
			end
		end
	end

	local job_id = vim.fn.jobstart(cmd, {
		on_stdout = function(_, data) 
			append_to_buffer(data, false) 
		end,
		on_stderr = function(_, data) 
			append_to_buffer(data, true) 
		end,
		on_exit = function(_, code)
			if code == 0 then
				local msg = "Clone completed successfully!"
				append_to_buffer({"", msg}, false)
				table.insert(self.switch_logs, "")
				table.insert(self.switch_logs, msg)
			else
				local msg = "Clone failed with exit code " .. code
				append_to_buffer({"", msg}, false)
				table.insert(self.switch_logs, "")
				table.insert(self.switch_logs, msg)
			end

			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end

			-- Call callback if provided
			if callback then
				callback(code == 0)
			end
		end
	})

	-- Allow cancellation with Esc
	vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', string.format(
		'<cmd>lua vim.fn.jobstop(%d); vim.api.nvim_win_close(%d, true); vim.notify("Clone operation cancelled", vim.log.levels.INFO)<CR>',
		job_id, win), {noremap = true, silent = true})

	return job_id
end

function M:try_clone(url, force)
	if self:directory_exists(neosvim_path) and not force then
		-- Directory exists, ask for confirmation
		self:popup_input(
			"Configuration already exists. Type 'switch' to replace it: ",
			function(response)
				if response ~= "switch" then
					vim.notify("Operation cancelled", vim.log.levels.INFO)
					return
				else
					self:delete_dir(neosvim_path)
					self:git_clone(url, function(success)
						if success then
							vim.notify("Clone completed successfully", vim.log.levels.INFO)
							self:reload()
						end
					end)
				end
			end
		)
	else
		self:git_clone(url, function(success)
			if success then
				vim.notify("Clone completed successfully", vim.log.levels.INFO)
				self:reload()
			end
		end)
	end
end

function M:setup_commands()
	vim.api.nvim_create_user_command("Switch", ":lua require('neosvim'):ask_repo()<CR>", {})
	vim.api.nvim_create_user_command("Reload", ":lua require('neosvim'):reload()<CR>", {})
	vim.api.nvim_create_user_command("SwitchLogs", ":lua require('neosvim'):show_logs()<CR>", {})
end

function M:reload()
	vim.g.maplocalleader = "<space>"
	local success = self:run_init()

	-- Execute key events
	local events = {
		"VimEnter",
		"UIEnter",
		"ColorScheme",
		"BufEnter",
	}
	for _, event in ipairs(events) do
		pcall(vim.api.nvim_exec_autocmds, event, {})
	end

	vim.cmd("redraw!")
	vim.notify("Configuration loaded. Restart neovim if nothing changed.", vim.log.levels.INFO)
	return success
end
-- Update the switch function to use this new gitClone behavior
function M:switch(url)
	self:try_clone(url)
end

return M
