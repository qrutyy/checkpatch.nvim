function parse_checkpatch(output)
    local diagnostics = {}

    for line in output:gmatch("[^\r\n]+") do
        -- Match: <path>:<line>: <SEVERITY>: <message>
        local lnum, sev, msg = line:match("^.-:(%d+):%s*([A-Z]+):%s*(.+)$")
        if lnum and sev and msg then
            -- skip noisy commit log messages
            if not string.find(msg, "Commit log lines", 1, true) then
                local severity = (sev == "ERROR" and vim.diagnostic.severity.ERROR)
                or (sev == "WARNING" and vim.diagnostic.severity.WARN)
                or nil

                if severity then
                    local lnum0 = math.max(tonumber(lnum) - 1, 0)
                    local start_col = 0
                    local end_col = 1
                    table.insert(diagnostics, {
                        lnum = lnum0,
                        end_lnum = lnum0,
                        col = start_col,
                        end_col = end_col,
                        message = (msg:gsub("%s+$", "")),
                        severity = severity,
                        source = "checkpatch",
                    })
                end
            end
        end
    end

    return diagnostics
end
