local M = {}

local config_path = vim.fn.stdpath("data") .. "/checkpatch_last_cfg.json"

function M.load_cfg()
	local f = io.open(config_path, "r")
		if not f then
			return nil
		end

		local content = f:read("*a")
		f:close()
	return content
end

function M.get_last_cfg()
	local vim_cfg = vim.g.checkpatch_last_cfg
	if type(vim_cfg) ~= "table" then
		local content = M.load_cfg()

		local ok, cfg = pcall(vim.fn.json_decode, content)

		if ok then
			vim.g.checkpatch_last_cfg = cfg
			return cfg
		else
			local def_cfg = {
				strict = false,
				codespell = false,
				log = false,
				no_tree = false,
				quiet = false,
				diff = true
			}
			return def_cfg
		end
	else
		return vim_cfg
	end
end


function M.set_last_cfg(cfg)
    vim.g.checkpatch_last_cfg = cfg

    local json = vim.fn.json_encode(cfg)

    local f = io.open(config_path, "w")
    if f then
        f:write(json)
        f:close()
    else
        vim.notify("Failed to save checkpatch config to " .. config_path, vim.log.levels.ERROR)
    end
end

return M
