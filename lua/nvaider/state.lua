local util = require('nvaider.util')

local M = {}

-- Per-tab state tracking
local tab_states = {}
M.tab_states = tab_states

function M.get_state(tab_id)
  tab_id = tab_id or vim.api.nvim_get_current_tabpage()
  if not tab_states[tab_id] then
    tab_states[tab_id] = {
      last_args = nil,
      job_id = nil,
      buf_nr = nil,
      win_id = nil,
      --- @type uv.uv_timer_t?
      check_timer = nil,
    }
  end
  return tab_states[tab_id]
end

function M.reset_state(stop_job, close_win, tab_id)
  local state = M.get_state(tab_id)

  if stop_job and state.job_id then
    vim.fn.jobstop(state.job_id)
  end

  if close_win and state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
    vim.api.nvim_win_close(state.win_id, true)
  end

  state.job_id = nil
  state.buf_nr = nil
  state.win_id = nil
  state.check_timer = util.cleanup_timer(state.check_timer)
end

function M.is_running()
  local state = M.get_state()
  if state.buf_nr and not vim.api.nvim_buf_is_valid(state.buf_nr) then
    M.reset_state()
  end
  if state.job_id then return true end
  return false
end

return M
