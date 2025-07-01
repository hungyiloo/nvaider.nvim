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

function M.start()
  if M.state.job_id then return end
  local buf = vim.api.nvim_create_buf(false, true)
  local args = vim.tbl_flatten({ M.config.cmd, M.config.args })
  local cur_win = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_buf(buf)
  M.state.job_id = vim.fn.termopen(args, {
    cwd = vim.fn.getcwd(),
    on_exit = function() M.state.job_id = nil end,
  })
  vim.api.nvim_set_current_win(cur_win)
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
    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)
    M.state.win_id = vim.api.nvim_open_win(M.state.buf_nr, true, {
      relative = 'editor',
      width = width,
      height = height,
      row = row,
      col = col,
      style = 'minimal',
    })
  end
end

function M.send(text)
  if not M.state.job_id then M.start() end
  if text == '' then
    text = vim.fn.input('Aider> ')
  end
  vim.fn.chansend(M.state.job_id, text .. '\n')
end

function M.add()
  local file = vim.fn.expand('%:p')
  M.send("add " .. file)
end

function M.drop()
  local file = vim.fn.expand('%:p')
  M.send("drop " .. file)
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
    elseif sub == 'send' then
      table.remove(args, 1)
      local txt = table.concat(args, ' ')
      M.send(txt)
    else
      vim.notify('Unknown subcommand: ' .. tostring(sub), vim.log.levels.ERROR)
    end
  end, {
    nargs = '*',
    complete = function(_, line)
      local subs = { 'start', 'stop', 'toggle', 'add', 'drop', 'send' }
      return vim.tbl_filter(function(item) return item:match('^' .. line) end, subs)
    end,
  })
end

-- auto-initialize with defaults
M.setup()

return M
