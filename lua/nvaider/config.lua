local M = {
  cmd = "aider",
  profiles = {
    default = {},
  },
  window = {
    position = "right", -- "top", "bottom", "left", "right"
    width = 0.35,       -- for left/right positions (fraction of total width)
    height = 0.3,       -- for top/bottom positions (fraction of total height)
  },
}

function M.update(opts)
  for key, value in pairs(opts) do
    if type(value) == "table" and type(M[key]) == "table" then
      M[key] = vim.tbl_deep_extend('force', M[key], value)
    else
      M[key] = value
    end
  end
end

return M
