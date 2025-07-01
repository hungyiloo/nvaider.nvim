local M = {
  config = {
    cmd = "aider",
    args = {},
  },
  state = {
    job_id = nil,
    buf_nr = nil,
    win_id = nil,
  },
}

-- ensure the aider process is running
local function ensure_running()
  M.start()
  if not M.state.job_id then
    vim.notify("Aider is not running", vim.log.levels.ERROR)
    return false
  end
  return true
end

function M.start()
  if M.state.job_id then return end
  local buf = vim.api.nvim_create_buf(false, true)
  local args = vim.list_extend({ M.config.cmd }, M.config.args)
  vim.api.nvim_buf_call(buf, function()
    M.state.job_id = vim.fn.jobstart(args, {
      term = true,
      cwd = vim.fn.getcwd(),
      on_exit = function()
        M.state.job_id = nil
        if M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id) then
          vim.api.nvim_win_close(M.state.win_id, true)
        end
        M.state.win_id = nil
      end,
    })
    vim.notify("Aider Started")
  end)
  M.state.buf_nr = buf
end

function M.stop()
  if not M.state.job_id then return end
  vim.fn.jobstop(M.state.job_id)
  M.state.job_id = nil
  if M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id) then
    vim.api.nvim_win_close(M.state.win_id, true)
  end
  M.state.win_id = nil
end

function M.toggle()
  if not M.state.job_id then M.start() end
  if M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id) then
    vim.api.nvim_win_close(M.state.win_id, true)
    M.state.win_id = nil
  else
    -- open a side window for the aider terminal
    vim.cmd('rightbelow vsplit')
    M.state.win_id = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(M.state.win_id, M.state.buf_nr)
    -- disable line numbers in the aider window
    vim.api.nvim_win_set_option(M.state.win_id, 'number', false)
    vim.api.nvim_win_set_option(M.state.win_id, 'relativenumber', false)
    local win_width = math.floor(vim.o.columns * 0.35)
    vim.api.nvim_win_set_width(M.state.win_id, win_width)
    -- allow <Esc> to exit terminal mode
    vim.api.nvim_buf_set_keymap(M.state.buf_nr, 't', '<Esc>', [[<C-\><C-n>]], {noremap=true, silent=true})
    vim.cmd('startinsert')
  end
end

function M.send(text)
  if not ensure_running() then return end
  if text == '' then
    vim.ui.input({ prompt = 'Aider> ' }, function(input)
      if not input or input == '' then return end
      vim.fn.chansend(M.state.job_id, input .. '\n')
    end)
    return
  end
  vim.fn.chansend(M.state.job_id, text .. '\n')
end

function M.add()
  if not ensure_running() then return end
  local file = vim.fn.expand('%:p')
  M.send("/add " .. file)
end

function M.drop()
  if not ensure_running() then return end
  local file = vim.fn.expand('%:p')
  M.send("/drop " .. file)
end

function M.dropall()
  if not ensure_running() then return end
  M.send("/drop")
end

function M.reset()
  if not ensure_running() then return end
  M.send("/reset")
end

function M.show()
  if not ensure_running() then return end
  if M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id) then return end
  local current_win = vim.api.nvim_get_current_win()
  vim.cmd('rightbelow vsplit')
  M.state.win_id = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(M.state.win_id, M.state.buf_nr)
  vim.api.nvim_win_set_option(M.state.win_id, 'number', false)
  vim.api.nvim_win_set_option(M.state.win_id, 'relativenumber', false)
  local win_width = math.floor(vim.o.columns * 0.35)
  vim.api.nvim_win_set_width(M.state.win_id, win_width)
  vim.api.nvim_buf_set_keymap(M.state.buf_nr, 't', '<Esc>', [[<C-\><C-n>]], {noremap=true, silent=true})
  vim.api.nvim_set_current_win(current_win)
end

function M.hide()
  if M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id) then
    vim.api.nvim_win_close(M.state.win_id, true)
    M.state.win_id = nil
  end
end

function M.setup(opts)
  M.config = vim.tbl_extend('force', M.config, opts or {})
  if M._initialized then return end
  M._initialized = true
  vim.api.nvim_create_user_command('Aider', function(cmd_opts)
    local args = vim.fn.split(cmd_opts.args)
    local sub = args[1]
    if sub == 'start' then
      M.start()
    elseif sub == 'stop' then
      M.stop()
    elseif sub == 'toggle' then
      M.toggle()
    elseif sub == 'add' then
      M.add()
    elseif sub == 'drop' then
      M.drop()
    elseif sub == 'dropall' then
      M.dropall()
    elseif sub == 'reset' then
      M.reset()
    elseif sub == 'send' then
      table.remove(args, 1)
      local txt = table.concat(args, ' ')
      M.send(txt)
    elseif sub == 'show' then
      M.show()
    elseif sub == 'hide' then
      M.hide()
    else
      vim.notify('Unknown subcommand: ' .. tostring(sub), vim.log.levels.ERROR)
    end
  end, {
    nargs = '*',
    complete = function(argLead, cmdLine, cursorPos)
      local subs = { 'start', 'stop', 'toggle', 'add', 'drop', 'dropall', 'reset', 'send' }
      return vim.tbl_filter(function(item) return item:match('^' .. argLead) end, subs)
    end,
  })
end

-- auto-initialize with defaults
M.setup()

return M
