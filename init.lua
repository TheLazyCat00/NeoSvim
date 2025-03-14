local function add_to_path(path)
	if not package.path:find(path, 1, true) then
		package.path = path .. "/?.lua;" .. package.path
	end
end

local config_path = vim.fn.stdpath("config")

add_to_path(config_path)

require("neosvim"):run_init()
require("globals")
