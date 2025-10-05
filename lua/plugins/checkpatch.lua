require "parser"

local M = {}

-- namespace for diagnostics
M.ns = vim.api.nvim_create_namespace("checkpatch")

-- remember last used flags across runs
local function get_last_cfg()
    local cfg = vim.g.checkpatch_last_cfg
    if type(cfg) ~= "table" then
        cfg = { strict = false, codespell = false, log = false, no_tree = false }
    end
    return cfg
end

local function set_last_cfg(cfg)
    vim.g.checkpatch_last_cfg = cfg
end

function DiagnosticIndicator()
    local counts = vim.diagnostic.get_count(0)
    
    if not counts or (counts.error == 0 and counts.warn == 0) then
        return "" 
    end

    local parts = {}
    if counts.error and counts.error > 0 then
        table.insert(parts, " " .. counts.error)
    end
    if counts.warn and counts.warn > 0 then
        table.insert(parts, " " .. counts.warn)
    end

    return table.concat(parts, " ")
end

local function write_log(data)
    local log_dir = vim.fn.stdpath("data") .. "/checkpatch-logs"
    vim.fn.mkdir(log_dir, "p") -- create dir if missing

    local filename = log_dir .. "/log_" .. os.date("%Y-%m-%d") .. ".txt"
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

-- main execution function
function M.run(checkpatch_path, strict_mode, codespell_mode, log_mode, no_tree_mode, quiet)
    local buf = vim.api.nvim_get_current_buf()
    local file = vim.api.nvim_buf_get_name(buf)
    if file == "" then
        if not quiet then
            vim.notify("Buffer is empty. Running in current dir", vim.log.levels.INFO)
        end
    end

	if not checkpatch_path then
		checkpatch_path = install_checkpatch()
	end

	local opts = "--terse "
	if strict_mode then
		opts = opts .. "--strict "
	end

	if no_tree_mode then
		opts = opts .. "--no-tree "
	end

	if codespell_mode then
		opts = opts .. "--codespell "
	end

    local handle = io.popen("perl " .. checkpatch_path .. " " .. opts .. file)
	-- This function is system dependent and is not available on all platforms. (lua 5.1 ref manual)
	if not handle then
		print("Error opening the file")
	end

    local result = handle:read("*a")
    handle:close()

	if log_mode then
		write_log(result)
	end

    local diagnostics = parse_checkpatch(result)

    -- Reset and set diagnostics (use default Neovim visuals)
    vim.diagnostic.reset(M.ns, buf)
    vim.diagnostic.set(M.ns, buf, diagnostics, {})
    if not quiet and #diagnostics ~= 0 then
        vim.notify("checkpatch: " .. #diagnostics .. " issues found", vim.log.levels.INFO)
    end
end

vim.api.nvim_create_user_command("Checkpatch", function(opts)
    local args = opts.fargs
	local checkpatch_path = vim.tbl_contains(args, "cppath")
    local strict_mode = vim.tbl_contains(args, "strict")
    local log_mode = vim.tbl_contains(args, "log")
    local codespell_mode = vim.tbl_contains(args, "codespell")
	local no_tree_mode = vim.tbl_contains(args, "no-tree")

    -- remember last used flags
    set_last_cfg({ strict = strict_mode, codespell = codespell_mode, log = log_mode, no_tree = no_tree_mode })

    M.run(nil, strict_mode, codespell_mode, log_mode, no_tree_mode, false)
end, { desc = "Highlights the checkpatch msg in buf", nargs = "*" })

-- auto-exec on .c safe
vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = "*.c",
    callback = function ()
        local cfg = get_last_cfg()
        M.run(false, cfg.strict, cfg.codespell, cfg.log, cfg.no_tree, true)
	end
})

return M
