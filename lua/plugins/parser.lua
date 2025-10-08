local M = {}

local function parse_patch_hunks(patch_path)
    local hunks = {}
    local current = nil
    local patch_lines = {}
    local lineno = 0

    for line in io.lines(patch_path) do
        table.insert(patch_lines, line)
        lineno = lineno + 1

        -- searching for pattern @@ -a,b +c,d @@
        local old_start, _, new_start, _ = line:match(
                                               "^@@%s*%-(%d+),?(%d*)%s*%+(%d+),?(%d*)%s*@@")
        if old_start and new_start then
            current = {
                patch_line = lineno,
                old_line = tonumber(old_start),
                new_line = tonumber(new_start)
            }
            table.insert(hunks, current)
        end
    end

    return hunks, patch_lines
end

function M.parse_result(output, diff_mode, patch_file)
    local diagnostics = {}

    -- parse patch and build patch_string -> src map
    local hunks, _ = {}, {}
    if diff_mode and patch_file then hunks, _ = parse_patch_hunks(patch_file) end

    for line in output:gmatch("[^\r\n]+") do
        local patch_lnum, sev, msg =
            line:match("^.-:(%d+):%s*([A-Z]+):%s*(.+)$")

        if patch_lnum and sev and msg then
            local severity = ({
                CHECK = vim.diagnostic.severity.HINT,
                ERROR = vim.diagnostic.severity.ERROR,
                WARNING = vim.diagnostic.severity.WARN,
                INFO = vim.diagnostic.severity.INFO
            })[sev]

            local lnum0 = tonumber(patch_lnum) - 2
            if severity and diff_mode then
                local found = false
                local prev = 0
				
				-- idc that looks shitty
                if diff_mode and hunks then
                    for _, h in pairs(hunks) do
                        found = false
                        if lnum0 < h.patch_line then
                            lnum0 = prev
                            found = true
                            -- print(lnum0, h.patch_line, prev)
                            break
                        end
                        prev = h.new_line
                    end
                    if found then
                        table.insert(diagnostics, {
                            lnum = lnum0 - 1,
                            end_lnum = lnum0 - 1,
                            col = 0,
                            end_col = 1,
                            message = "CP: " .. msg:gsub("%s+$", ""),
                            severity = severity,
                            source = "checkpatch"
                        })
                    end
                end
            elseif severity then
                table.insert(diagnostics, {
                    lnum = lnum0 + 1,
                    end_lnum = lnum0 + 1,
                    col = 0,
                    end_col = 1,
                    message = ("CP: " .. msg:gsub("%s+$", "")),
                    severity = severity,
                    source = "checkpatch"
                })
            end
        end
    end

    return diagnostics
end

return M
