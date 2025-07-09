local M = {}

function M.notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "nvaider" })
end

function M.cleanup_timer(timer)
  if timer then
    timer:stop()
    timer:close()
  end
  return nil
end

return M
