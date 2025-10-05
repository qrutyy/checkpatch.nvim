function parse_checkpatch(output)
    local diagnostics = {}
    for line in output:gmatch("[^\r\n]+") do

		-- WARNING msgs
        local lnum, msg_w = line:match("[Ww]ARNING:%s*line%s*(%d+)%s*:%s*(.*)")
        if lnum and msg_w then
            table.insert(diagnostics, {
                lnum = tonumber(lnum) - 1,
                col = 0,
                message = msg_w,
                severity = vim.diagnostic.severity.WARN,
                source = "checkpatch"
            })
			print("added msg:", msg_w)
        end

        -- ERROR msgs
        local lnum_e, msg_e = line:match("[Ee]RROR:%s*line%s*(%d+)%s*:%s*(.*)")
        if lnum_e and msg_e then
            table.insert(diagnostics, {
                lnum = tonumber(lnum_e) - 1,
                col = 0,
                message = msg_e,
                severity = vim.diagnostic.severity.ERROR,
                source = "checkpatch"
            })
			print("added msg:", msg_e)
        end
    end
    return diagnostics
end

