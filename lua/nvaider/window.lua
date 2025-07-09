local config = require('nvaider.config')
local state = require('nvaider.state')

local M = {}

function M.get_window_size()
  local pos = config.window.position
  if pos == "left" or pos == "right" then
    return math.floor(vim.o.columns * config.window.width)
  else -- top or bottom
    return math.floor(vim.o.lines * config.window.height)
  end
end

function M.is_window_showing()
  local s = state.get_state()
  return s.win_id and vim.api.nvim_win_is_valid(s.win_id)
end

function M.open_window(enter_insert)
  local s = state.get_state()
  local current_win = vim.api.nvim_get_current_win()
  local pos = config.window.position

  -- Create split based on position
  if pos == "right" then
    vim.cmd('rightbelow vsplit')
  elseif pos == "left" then
    vim.cmd('leftabove vsplit')
  elseif pos == "bottom" then
    vim.cmd('rightbelow split')
  elseif pos == "top" then
    vim.cmd('leftabove split')
  end

  s.win_id = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(s.win_id, s.buf_nr)
  vim.api.nvim_set_option_value('number', false, { win = s.win_id })
  vim.api.nvim_set_option_value('relativenumber', false, { win = s.win_id })

  -- Set window size based on position
  local size = M.get_window_size()
  if pos == "left" or pos == "right" then
    vim.api.nvim_win_set_width(s.win_id, size)
  else -- top or bottom
    vim.api.nvim_win_set_height(s.win_id, size)
  end

  vim.api.nvim_buf_set_keymap(s.buf_nr, 't', '<Esc>', [[<C-\><C-n>]], {noremap=true, silent=true})
  if enter_insert then vim.cmd('startinsert') end
  return current_win
end

function M.close_window()
  local s = state.get_state()
  if s.win_id and vim.api.nvim_win_is_valid(s.win_id) then
    vim.api.nvim_win_close(s.win_id, true)
    s.win_id = nil
  end
end

function M.scroll_to_latest()
  local s = state.get_state()
  if s.win_id and vim.api.nvim_win_is_valid(s.win_id) then
    if vim.api.nvim_get_current_win() ~= s.win_id then
      pcall(vim.api.nvim_win_call, s.win_id, function()
        local line_count = vim.api.nvim_buf_line_count(s.buf_nr)
        vim.api.nvim_win_set_cursor(s.win_id, {line_count, 0})
      end)
    end
  end
end

function M.show()
  local job = require('nvaider.job')
  job.ensure_running(function(success)
    if not success then return end
    if M.is_window_showing() then return end
    local current_win = M.open_window(false)
    vim.api.nvim_set_current_win(current_win)
  end)
end

function M.hide()
  M.close_window()
end

function M.focus()
  local job = require('nvaider.job')
  job.ensure_running(function(success)
    if not success then return end
    if M.is_window_showing() then
      vim.api.nvim_set_current_win(state.get_state().win_id)
      vim.cmd('startinsert')
    else
      M.open_window(true)
    end
  end)
end

function M.toggle()
  if not state.is_running() then
    local job = require('nvaider.job')
    job.start()
  else
    if M.is_window_showing() then
      M.close_window()
    else
      local current_win = M.open_window(false)
      vim.api.nvim_set_current_win(current_win)
    end
  end
end

return M
