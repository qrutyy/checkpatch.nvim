-- load module and register default keymaps unless globally disabled
local ok, mod = pcall(require, "plugins.checkpatch")
if ok then
  if not vim.g.checkpatch_disable_defaults then
    mod.setup()
  end
end
