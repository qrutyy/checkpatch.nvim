local M = {}

local config_path = vim.fn.stdpath("data") .. "/checkpatch_last_cfg.json"

function M.load_cfg()
    local f = io.open(config_path, "r")
    if not f then return nil end

    local content = f:read("*a")
    f:close()
    return content
end

function M.init_cfg()
    local cfg = M.get_last_cfg()

    if not cfg then
        print("Failed to get last_cfg")
        cfg = {
            strict = false,
            codespell = false,
            log = false,
            no_tree = true,
            quiet = false,
            diff = false,
            on_save = false
        }
        M.set_last_cfg(cfg)
    end

    vim.g.checkpatch_last_cfg = cfg
    return cfg
end

function M.get_last_cfg()
    local vim_cfg = vim.g.checkpatch_last_cfg
    if type(vim_cfg) == "table" then return vim_cfg end

    local content = M.load_cfg()
    if not content or content == "" then return nil end

    local ok, cfg = pcall(vim.fn.json_decode, content)
    if ok and type(cfg) == "table" then
        vim.g.checkpatch_last_cfg = cfg
        return cfg
    end

    return nil
end

function M.set_last_cfg(cfg)
    vim.g.checkpatch_last_cfg = cfg

    local json = vim.fn.json_encode(cfg)

    local f = io.open(config_path, "w")
    if f then
        f:write(json)
        f:close()
    else
        vim.notify("Failed to save checkpatch config to " .. config_path,
                   vim.log.levels.ERROR)
    end
end

return M
