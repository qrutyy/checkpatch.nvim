require "parser"

local M = {}

-- namespace for diagnostics
M.ns = vim.api.nvim_create_namespace("checkpatch")

vim.diagnostic.handlers["checkpatch_handler"] = {
    show = function(namespace, bufnr, diagnostics, opts)
		-- clearing old buf
        vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
		-- adding virtual text with CP prefix
        for _, d in ipairs(diagnostics) do
            vim.api.nvim_buf_set_virtual_text(bufnr, namespace, d.lnum, { { "CP: " .. d.message, "WarningMsg" } }, {})
        end
    end,
    hide = function(namespace, bufnr)
        vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
    end,
}

local function write_log(data)
	local date_str = os.date("%Y-%m-%d")
	local filename = "../logs/log_" .. date_str .. ".txt"
	local file, err = io.open(filename, "w")

	if not file then
		print("Error opening file:", err)
		return
	end

	file:write(data)
	file:close()
end

-- main execution function
function M.run(strict_mode, codespell_mode, log_mode)
    local buf = vim.api.nvim_get_current_buf()
    local file = vim.api.nvim_buf_get_name(buf)
    if file == "" then
        print("Файл не сохранён!")
        return
    end

	local opts = ""
	if strict_mode then
		opts = opts .. "--strict "
	end

	if codespell_mode then
		opts = opts .. "--codespell "
	end

    local handle = io.popen("perl /path/to/checkpatch.pl " .. file .. opts)
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

	-- reset the diagnostics and show the new ones
    vim.diagnostic.reset(M.ns, buf)
    vim.diagnostic.show(M.ns, buf, diagnostics, { handler = "checkpatch_handler" })

    print("checkpatch: " .. #diagnostics .. " issues found")
end

vim.api.nvim_create_user_command("checkpatch", function(opts)
    local args = opts.fargs
    local strict_mode = vim.tbl_contains(args, "strict")
    local log_mode = vim.tbl_contains(args, "log")
    local codespell_mode = vim.tbl_contains(args, "codespell")

    print("strict_mode:", strict_mode)
    print("log_mode:", log_mode)
    print("codespell_mode:", codespell_mode)

    M.run(strict_mode, codespell_mode, log_mode)
end, { desc = "Highlights the checkpatch msg in buf", nargs = "*" })

-- auto-exec on .c safe
vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = "*.c",
    callback = function ()
		M.run(false, false, false)
	end
})

return M
