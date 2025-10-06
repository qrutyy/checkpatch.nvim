require "parser"

local M = {}
local configured = false

local default_config = {
mappings = {
run = { keys = "<leader>cp", desc = "Run checkpatch" },
next = { keys = ",", desc = "Next checkpatch remark" },
prev = { keys = "<", desc = "Prev checkpatch remark" },
},
}

function M.setup(opts)
if configured then return end
local ok_tbl, tbl = pcall(require, "vim.tbl")
local cfg
if ok_tbl then
cfg = vim.tbl_deep_extend("force", default_config, opts or {})
else
cfg = default_config
end

local map = vim.keymap.set
local km = cfg.mappings or {}
if km.run and km.run.keys then
map("n", km.run.keys, ":Checkpatch<CR>", { silent = true, desc = km.run.desc or "Run checkpatch" })
end
if km.next and km.next.keys then
map("n", km.next.keys, function() require("plugins.checkpatch").next_remark() end, { silent = true, desc = km.next.desc or "Next checkpatch remark" })
end
if km.prev and km.prev.keys then
map("n", km.prev.keys, function() require("plugins.checkpatch").prev_remark() end, { silent = true, desc = km.prev.desc or "Prev checkpatch remark" })
end

configured = true
end

local current_index = 0

-- namespace for diagnostics
M.ns = vim.api.nvim_create_namespace("checkpatch")

-- remember last used flags across runs
local function get_last_cfg()
    local cfg = vim.g.checkpatch_last_cfg
    if type(cfg) ~= "table" then
        cfg = { strict = false, codespell = false, log = false, no_tree = false, quiet = false }
    end
    return cfg
end

local function set_last_cfg(cfg)
    vim.g.checkpatch_last_cfg = cfg
	return cfg
end

table.filter = function(array, filterIterator)
   local result = {}

   for key, value in pairs(array) do
      if filterIterator(value, key, array) then
		 table.insert(result,value)
	  end
   end

   return result
end

function DiagnosticIndicator()
    local counts = vim.diagnostic.get_count(0)
    
    if not counts or (counts.remark == 0 and counts.warn == 0) then
        return "" 
    end

    local parts = {}
    if counts.error and counts.error > 0 then
        table.insert(parts, " " .. counts.remark)
    end
    if counts.warn and counts.warn > 0 then
        table.insert(parts, " " .. counts.warn)
    end

    return table.concat(parts, " ")
end

local function write_log(data)
    local log_dir = vim.fn.stdpath("data") .. "/checkpatch-logs"
    vim.fn.mkdir(log_dir, "p") -- create dir if missing

    local filename = log_dir .. "/log_" .. os.date("%Y-%m-%d_%H-%M") .. ".txt"
    local file, err = io.open(filename, "w")
    if not file then
        print("Error opening log file:", err)
        return
    end

    file:write(data)
    file:close()
end

local function file_exists(path)
    local f = io.open(path, "r")
    if f then f:close() end
    return f ~= nil
end

local function install_checkpatch()
    local script_dir = vim.fn.stdpath("data") .. "/checkpatch-scripts"
    vim.fn.mkdir(script_dir, "p")

    local checkpatch_file = script_dir .. "/checkpatch.pl"
    local spelling_file = script_dir .. "/spelling.txt"
    local const_structs_file = script_dir .. "/const_structs.checkpatch"

    -- Download helper (synchronous)
    local function curl_get(url, dest)
        vim.fn.system({ "curl", "-sSL", "-o", dest, url })
        if vim.v.shell_error ~= 0 then
            print("Failed to download: " .. url)
            return false
        end
        return true
    end

	-- Ensure main script
    if not file_exists(checkpatch_file) then
        if curl_get(
            "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/scripts/checkpatch.pl",
            checkpatch_file
        ) then
            vim.fn.system({"chmod", "+x", checkpatch_file})
        end
    end

    -- Ensure aux files that checkpatch expects when certain flags are used
    if not file_exists(spelling_file) then
        curl_get(
            "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/scripts/spelling.txt",
            spelling_file
        )
    end

    if not file_exists(const_structs_file) then
        curl_get(
            "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/scripts/const_structs.checkpatch",
            const_structs_file
        )
    end

    return checkpatch_file
end

local function get_remarks()
  local bufnr = vim.api.nvim_get_current_buf()
  local diag = vim.diagnostic.get(bufnr)
	local filteredDiag = table.filter(diag,
		function (element, key, index)
			return element.source == "checkpatch"
		end
		)
	return filteredDiag
end

function M.next_remark()
  local remarks = get_remarks()
  if #remarks == 0 then
    print("No remarks")
    return
  end

  current_index = current_index + 1
  if current_index > #remarks then
    current_index = 1
  end

  local err = remarks[current_index]
  vim.api.nvim_win_set_cursor(0, {err.lnum + 1, err.col})
  vim.notify(err.message, vim.log.levels.ERROR)
end

function M.prev_remark()
  local remarks = get_remarks()
  if #remarks == 0 then
    print("No remarks found")
    return
  end

  current_index = current_index - 1
  if current_index < 1 then
    current_index = #remarks
  end

  local err = remarks[current_index]
  local log_level = (err.severity == vim.diagnostic.severity.ERROR) and vim.log.levels.ERROR or vim.log.levels.WARN

  vim.api.nvim_win_set_cursor(0, {err.lnum + 1, err.col})
  vim.notify(err.message, log_level)
end

-- main execution function
local function shell_escape_dquote(str)
    return (str or ""):gsub('"', '\\"')
end

local function get_repo_root(start_dir)
    local out = vim.fn.systemlist({ "git", "-C", start_dir, "rev-parse", "--show-toplevel" })
    if vim.v.shell_error ~= 0 or not out or #out == 0 then return nil end
    return out[1]
end

function M.run(cfg)
    local buf = vim.api.nvim_get_current_buf()
    local file = vim.api.nvim_buf_get_name(buf)
    if file == "" then
        if not cfg.quiet then
            vim.notify("Buffer is empty. Running in current dir", vim.log.levels.INFO)
            cfg.filem = true
        end
    end

	local checkpatch_path = install_checkpatch()

	local opts = "--terse "
	if cfg.strict then
		opts = opts .. "--strict "
	end

	if cfg.no_tree then
		opts = opts .. "--no-tree "
	end

	if cfg.codespell then
		opts = opts .. "--codespell "
	end

    local handle
    if cfg.diff then
        local file_dir = vim.fn.fnamemodify(file, ":p:h")
        local repo_root = get_repo_root(file_dir)
        if not repo_root then
            if not cfg.quiet then
                vim.notify("checkpatch: not a git repo; falling back to file mode", vim.log.levels.WARN)
            end
            handle = io.popen("perl " .. checkpatch_path .. " " .. opts .. "--file " .. file)
        else
            local base = cfg.diff_base or "HEAD"
            local esc_repo = '"' .. shell_escape_dquote(repo_root) .. '"'
            local esc_file = '"' .. shell_escape_dquote(file) .. '"'
            local cmd = "git -C " .. esc_repo .. " diff " .. base .. " -- " .. esc_file .. " | perl " .. checkpatch_path .. " " .. opts .. "-"
            handle = io.popen(cmd)
        end
    else
        handle = io.popen("perl " .. checkpatch_path .. " " .. opts .. "--file " .. file)
    end
	-- This function is system dependent and is not available on all platforms. (lua 5.1 ref manual)
	if not handle then
		print("Error opening the file")
	end

    local result = handle:read("*a")
    handle:close()

    if cfg.log then
		write_log(result)
	end

    local diagnostics = parse_checkpatch(result)

    -- Reset and set diagnostics (use default Neovim visuals)
    vim.diagnostic.reset(M.ns, buf)
    vim.diagnostic.set(M.ns, buf, diagnostics, {})
    if not cfg.quiet and #diagnostics ~= 0 then
        vim.notify("checkpatch: " .. #diagnostics .. " issues found", vim.log.levels.INFO)
    end
end

vim.api.nvim_create_user_command("Checkpatch", function(opts)
    local cfg = get_last_cfg()

    local args = opts.fargs
    if #args > 0 then
        local overrides = {
            strict = vim.tbl_contains(args, "strict"),
            codespell = vim.tbl_contains(args, "codespell"),
            log = vim.tbl_contains(args, "log"),
            no_tree = vim.tbl_contains(args, "no-tree"),
            quiet = vim.tbl_contains(args, "quiet"),
            filem = vim.tbl_contains(args, "check-all"),
            diff = vim.tbl_contains(args, "diff"),
        }
        for _, a in ipairs(args) do
            local base = a:match("^base=(.+)$") or a:match("^diff_base=(.+)$") or a:match("^ref=(.+)$")
            if base then overrides.diff_base = base end
        end
        for k, v in pairs(overrides) do cfg[k] = v end
        cfg = set_last_cfg(cfg)
    end

    M.run(cfg)
end, { desc = "Highlights the checkpatch msg in buf", nargs = "*" })

-- auto-exec on .c safe
vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = "*.c",
    callback = function ()
        local cfg = get_last_cfg()
        cfg.quiet = true
        M.run(cfg)
	end
})

return M
