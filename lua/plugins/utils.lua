local M = {}

function M.write_log(data)
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

function M.file_exists(path)
    local f = io.open(path, "r")
    if f then f:close() end
    return f ~= nil
end

function M.install_checkpatch()
    local script_dir = vim.fn.stdpath("data") .. "/checkpatch-scripts"
    vim.fn.mkdir(script_dir, "p")

    local checkpatch_file = script_dir .. "/checkpatch.pl"
    local spelling_file = script_dir .. "/spelling.txt"
    local const_structs_file = script_dir .. "/const_structs.checkpatch"

    -- Download helper (synchronous)
    local function curl_get(url, dest)
        vim.fn.system({"curl", "-sSL", "-o", dest, url})
        if vim.v.shell_error ~= 0 then
            print("Failed to download: " .. url)
            return false
        end
        return true
    end

    -- Ensure main script
    if not M.file_exists(checkpatch_file) then
        if curl_get(
            "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/scripts/checkpatch.pl",
            checkpatch_file) then
            vim.fn.system({"chmod", "+x", checkpatch_file})
        end
    end

    -- Ensure aux files that checkpatch expects when certain flags are used
    if not M.file_exists(spelling_file) then
        curl_get(
            "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/scripts/spelling.txt",
            spelling_file)
    end

    if not M.file_exists(const_structs_file) then
        curl_get(
            "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/scripts/const_structs.checkpatch",
            const_structs_file)
    end

    return checkpatch_file
end

function M.get_remarks()
    local bufnr = vim.api.nvim_get_current_buf()
    -- Explicitly scope to our namespace to avoid mixing with other sources
    local diag = vim.diagnostic.get(bufnr, {
        namespace = require("plugins.checkpatch").ns
    })
    local filteredDiag = table.filter(diag, function(element, key, index)
        return element.source == "checkpatch"
    end)
    return filteredDiag
end

table.filter = function(array, filterIterator)
    local result = {}

    for key, value in pairs(array) do
        if filterIterator(value, key, array) then
            table.insert(result, value)
        end
    end

    return result
end

--- WIP
function M.DiagnosticIndicator()
    local counts = vim.diagnostic.get_count(0)

    if not counts or (counts.remark == 0 and counts.warn == 0) then return "" end

    local parts = {}
    if counts.error and counts.error > 0 then
        table.insert(parts, " " .. counts.remark)
    end
    if counts.warn and counts.warn > 0 then
        table.insert(parts, " " .. counts.warn)
    end

    return table.concat(parts, " ")
end

return M
