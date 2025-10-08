local utils = require "plugins.utils"
local config = require "plugins.config"
local parser = require "plugins.parser"

local M = {}

-- namespace for diagnostics
M.ns = vim.api.nvim_create_namespace("checkpatch")

local CHECKPATCH_GROUP = vim.api.nvim_create_augroup("CheckpatchAuto",
                                                     {clear = true})
local configured = false

local default_key_config = {
    mappings = {
        run = {keys = "<leader>cp", desc = "Run checkpatch"},
        next = {keys = ",", desc = "Next checkpatch remark"},
        prev = {keys = "<", desc = "Prev checkpatch remark"}
    }
}

function M.setup(opts)
    if configured then return end

    local _ = config.init_cfg()

    local ok_tbl, _ = pcall(require, "vim.tbl")
    local key_cfg
    if ok_tbl then
        key_cfg = vim.tbl_deep_extend("force", default_key_config, opts or {})
    else
        key_cfg = default_key_config
    end

    local map = vim.keymap.set
    local km = key_cfg.mappings or {}
    if km.run and km.run.keys then
        map("n", km.run.keys, ":Checkpatch<CR>",
            {silent = true, desc = km.run.desc or "Run checkpatch"})
    end
    if km.next and km.next.keys then
        map("n", km.next.keys,
            function() require("plugins.checkpatch").next_remark() end,
            {silent = true, desc = km.next.desc or "Next checkpatch remark"})
    end
    if km.prev and km.prev.keys then
        map("n", km.prev.keys,
            function() require("plugins.checkpatch").prev_remark() end,
            {silent = true, desc = km.prev.desc or "Prev checkpatch remark"})
    end

    configured = true
end

local current_index = 0

function M.next_remark()
    local remarks = utils.get_remarks()
    if #remarks == 0 then
        print("No remarks")
        return
    end

    current_index = current_index + 1
    if current_index > #remarks then current_index = 1 end

    local err = remarks[current_index]
    vim.api.nvim_win_set_cursor(0, {err.lnum + 1, err.col})
    vim.notify(err.message, vim.log.levels.ERROR)
end

function M.prev_remark()
    local remarks = utils.get_remarks()
    if #remarks == 0 then
        print("No remarks found")
        return
    end

    current_index = current_index - 1
    if current_index < 1 then current_index = #remarks end

    local err = remarks[current_index]
    local log_level = (err.severity == vim.diagnostic.severity.ERROR) and
                          vim.log.levels.ERROR or vim.log.levels.WARN

    vim.api.nvim_win_set_cursor(0, {err.lnum + 1, err.col})
    vim.notify(err.message, log_level)
end

function M.run(cfg)
    local buf = vim.api.nvim_get_current_buf()
    local file = vim.api.nvim_buf_get_name(buf)
    local tmp_patch

    if file == "" then
        if not cfg.quiet then
            vim.notify("Buffer is empty. Open some file.", vim.log.levels.INFO)
            return
        end
    end

    local checkpatch_path = utils.install_checkpatch()

    local opts = "--terse "
    if cfg.strict then opts = opts .. "--strict " end

    if cfg.no_tree then opts = opts .. "--no-tree " end

    if cfg.codespell then opts = opts .. "--codespell " end

    local handle
    if cfg.diff then
        local base_commit = cfg.diff_base or ""
        tmp_patch = vim.fn.tempname() .. ".patch"
        local diff_cmd = string.format("git diff --unified=0 %s -- %s > %s",
                                       base_commit, file, tmp_patch)
        os.execute(diff_cmd)

        local cmd = string.format("perl %s %s %s", checkpatch_path, opts or "",
                                  tmp_patch)

        --	print("[checkpatch diff-mode] " .. cmd)
        handle = io.popen(cmd)
    else
        handle = io.popen(
                     "perl " .. checkpatch_path .. " " .. opts .. "--file " ..
                         file)
    end
    -- This function is system dependent and is not available on all platforms. (lua 5.1 ref manual)
    if not handle then
        vim.notify("Failed to run checkpatch command", vim.log.levels.ERROR)
        return
    end

    local result = handle:read("*a")
    handle:close()

    if cfg.log then utils.write_log(result) end
    -- print(result)

    local diagnostics = parser.parse_result(result, cfg.diff, tmp_patch)

    -- Reset and set diagnostics (use default Neovim visuals)
    vim.diagnostic.reset(M.ns, buf)
    vim.diagnostic.set(M.ns, buf, diagnostics, {})
    if not cfg.quiet and #diagnostics ~= 0 then
        vim.notify("checkpatch: " .. #diagnostics .. " issues found",
                   vim.log.levels.INFO)
    end
end

vim.api.nvim_create_user_command("Checkpatch", function(opts)
    local args = opts.fargs
    local last_cfg = config.init_cfg()
    local cfg = {}

    if #args > 0 then
        local overrides = {
            strict = vim.tbl_contains(args, "strict"),
            codespell = vim.tbl_contains(args, "codespell"),
            log = vim.tbl_contains(args, "log"),
            no_tree = vim.tbl_contains(args, "no-tree"),
            quiet = vim.tbl_contains(args, "quiet"),
            diff = vim.tbl_contains(args, "diff")
        }
        for _, a in ipairs(args) do
            local base =
                a:match("^base=(.+)$") or a:match("^diff_base=(.+)$") or
                    a:match("^ref=(.+)$")
            if base then overrides.diff_base = base end
        end
        for k, v in pairs(overrides) do cfg[k] = v end
        last_cfg = cfg
    end

    if vim.tbl_contains(args, "on-save") then
        last_cfg.on_save = true
        config.set_last_cfg(last_cfg)
        M.enable_on_save()
    end

    if vim.tbl_contains(args, "on-save-off") then
        last_cfg.on_save = false
        config.set_last_cfg(last_cfg)
        M.disable_on_save()
    end

    if #args > 0 and vim.tbl_contains(args, "set") then
        config.set_last_cfg(cfg)
    end

    M.run(last_cfg)

end, {desc = "Highlights the checkpatch msg in buf", nargs = "*"})

-- auto-exec on .c safe
function M.enable_on_save()
    vim.api.nvim_create_autocmd("BufWritePost", {
        group = CHECKPATCH_GROUP,
        pattern = "*.c",
        callback = function()
            local cfg = config.init_cfg()
            cfg.quiet = true
            M.run(cfg)
        end,
        desc = "Run checkpatch automatically on C file save"
    })
    vim.notify("checkpatch: auto-run enabled", vim.log.levels.INFO)
end

function M.disable_on_save()
    vim.api.nvim_clear_autocmds({group = CHECKPATCH_GROUP})
    vim.notify("checkpatch: auto-run disabled", vim.log.levels.INFO)
end

vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
        local ok, checkpatch = pcall(require, "plugins.checkpatch")
        if ok then
            checkpatch.setup() -- sets up mappings and loads last_cfg
        else
            vim.notify("Failed to load checkpatch.nvim", vim.log.levels.ERROR)
        end
    end
})

-- M.setup()

return M

