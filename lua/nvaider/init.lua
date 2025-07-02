local M = {
  config = {
    cmd = "aider",
    args = {},
  },
  state = {
    job_id = nil,
    buf_nr = nil,
    win_id = nil,
    --- @type uv.uv_timer_t?
    check_timer = nil,
  },
}

local ns = vim.api.nvim_create_namespace("nvaider_change_highlight")
local old_lines = {}

local function snapshot_buffer()
  old_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

-- can this function indicate the changes in the gutter instead of flashing a highlight? sometimes the changes happen off screen and I can't see the flash. ai?
local function highlight_changes()
  local bufnr = vim.api.nvim_get_current_buf()
  local new_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for i, new in ipairs(new_lines) do
    if old_lines[i] ~= new then
      vim.api.nvim_buf_add_highlight(bufnr, ns, "Visual", i-1, 0, -1)
    end
  end
  vim.defer_fn(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    end
  end, 500)
end

local function is_running()
  if M.state.buf_nr and not vim.api.nvim_buf_is_valid(M.state.buf_nr) then
    M.state.job_id = nil
    M.state.buf_nr = nil
    M.state.win_id = nil
  end
  if M.state.job_id then return true end
  return false
end

-- ensure the aider process is running
local function ensure_running()
  if not is_running() then
    M.start()
    if not is_running() then
      vim.notify("Aider could not start", vim.log.levels.ERROR, { title = "nvaider" })
      return false
    end
  end
  return true
end

local function get_terminal_width()
  return math.floor(vim.o.columns * 0.35)
end

local function open_window(enter_insert)
  local current_win = vim.api.nvim_get_current_win()
  vim.cmd('rightbelow vsplit')
  M.state.win_id = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(M.state.win_id, M.state.buf_nr)
  vim.api.nvim_set_option_value('number', false, { win = M.state.win_id })
  vim.api.nvim_set_option_value('relativenumber', false, { win = M.state.win_id })
  local win_width = get_terminal_width()
  vim.api.nvim_win_set_width(M.state.win_id, win_width)
  vim.api.nvim_buf_set_keymap(M.state.buf_nr, 't', '<Esc>', [[<C-\><C-n>]], {noremap=true, silent=true})
  if enter_insert then vim.cmd('startinsert') end
  return current_win
end

local function handle_stdout_prompt(data)
  for _, line in ipairs(data) do
    -- strip ANSI escape/control characters from terminal output
    line = line:gsub("\27%[%??[0-9;]*[ABCDHJKlmsu]", "")
    line = string.sub(line, 1, #line - 1) -- last character of the line seems to be junk

    -- detect unanswered questions based on yes/no pattern and an ending colon
    if line:match("%? %(Y%)es/%(N%)o") and line:match(":$") then
      vim.schedule(function()
        vim.ui.input({ prompt = line .. " " }, function(input)
          if input then
            vim.fn.chansend(M.state.job_id, input:sub(1,1):upper() .. "\n")
          end
        end)
      end)
    end
  end
end

local function scroll_to_latest()
  if M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id) then
    if vim.api.nvim_get_current_win() ~= M.state.win_id then
      vim.api.nvim_win_call(M.state.win_id, function() vim.cmd('normal! G') end)
    end
  end
end

local function debounce_check()
  if M.state.check_timer then
    M.state.check_timer:stop()
    M.state.check_timer:close()
  end
  M.state.check_timer = vim.uv.new_timer()
  M.state.check_timer:start(100, 0, vim.schedule_wrap(function()
    snapshot_buffer()
    vim.cmd('silent! checktime')
    -- clean up
    M.state.check_timer:stop()
    M.state.check_timer:close()
    M.state.check_timer = nil
  end))
end

function M.start()
  if M._starting then
    return
  end
  M._starting = true
  if is_running() then
    M._starting = false
    M.focus()
    return
  end
  local buf = vim.api.nvim_create_buf(false, true)
  local args = vim.list_extend({ M.config.cmd }, M.config.args)
  vim.api.nvim_buf_call(buf, function()
    M.state.job_id = vim.fn.jobstart(args, {
      term = true,
      width = get_terminal_width(),
      cwd = vim.fn.getcwd(),
      on_stdout = function(_, data, _)
        handle_stdout_prompt(data)
        scroll_to_latest()
        debounce_check()
      end,
      on_exit = function()
        M.state.job_id = nil
        if M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id) then
          vim.api.nvim_win_close(M.state.win_id, true)
        end
        M.state.win_id = nil
      end,
    })
    vim.notify("Starting aider", vim.log.levels.INFO, { title = "nvaider" })
    M._starting = false
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
  local current_win = open_window(false)
  vim.api.nvim_set_current_win(current_win)
  end
end

function M.send(text)
  if not ensure_running() then return end
  if text == '' then
    vim.ui.input({ prompt = 'aider> ' }, function(input)
      if not input or input == '' then return end
      vim.fn.chansend(M.state.job_id, input .. '\n')
    end)
    return
  end
  vim.fn.chansend(M.state.job_id, text .. '\n')
end

function M.ask(text)
  if not ensure_running() then return end
  if text == '' then
    vim.ui.input({ prompt = 'ask aider> ' }, function(input)
      if not input or input == '' then return end
      vim.fn.chansend(M.state.job_id, '/ask ' .. input .. '\n')
    end)
    return
  end
  vim.fn.chansend(M.state.job_id, '/ask ' .. text .. '\n')
end

function M.add()
  if not ensure_running() then return end
  local file = vim.fn.expand('%:p')
  M.send("/add " .. file)
  vim.notify("Added file: " .. file, vim.log.levels.INFO, { title = "nvaider" })
end

function M.drop()
  if not ensure_running() then return end
  local file = vim.fn.expand('%:p')
  M.send("/drop " .. file)
  vim.notify("Dropped file: " .. file, vim.log.levels.INFO, { title = "nvaider" })
end

function M.dropall()
  if not ensure_running() then return end
  M.send("/drop")
  vim.notify("All files dropped", vim.log.levels.INFO, { title = "nvaider" })
end

function M.reset()
  if not ensure_running() then return end
  M.send("/reset")
end

function M.abort()
  if not ensure_running() then return end
  vim.fn.chansend(M.state.job_id, "\003") -- Ctrl+C
  vim.notify("Sent abort signal to aider", vim.log.levels.INFO, { title = "nvaider" })
end

function M.commit()
  if not ensure_running() then return end
  M.send("/commit")
  vim.notify("Committed changes", vim.log.levels.INFO, { title = "nvaider" })
end

function M.show()
  if not ensure_running() then return end
  if M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id) then return end
  local current_win = open_window(false)
  vim.api.nvim_set_current_win(current_win)
end

function M.hide()
  if M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id) then
    vim.api.nvim_win_close(M.state.win_id, true)
    M.state.win_id = nil
  end
end

function M.focus()
  if not ensure_running() then return end
  if M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id) then
    vim.api.nvim_set_current_win(M.state.win_id)
    vim.cmd('startinsert')
  else
    open_window(true)
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
    elseif sub == 'abort' then
      M.abort()
    elseif sub == 'commit' then
      M.commit()
    elseif sub == 'send' then
      table.remove(args, 1)
      local txt = table.concat(args, ' ')
      M.send(txt)
    elseif sub == 'ask' then
      table.remove(args, 1)
      local txt = table.concat(args, ' ')
      M.ask(txt)
    elseif sub == 'show' then
      M.show()
    elseif sub == 'focus' then
      M.focus()
    elseif sub == 'hide' then
      M.hide()
    else
      vim.notify('Unknown subcommand: ' .. tostring(sub), vim.log.levels.ERROR, { title = "nvaider" })
    end
  end, {
    nargs = '*',
    complete = function(argLead, cmdLine, cursorPos)
      local subs = { 'start', 'stop', 'toggle', 'add', 'drop', 'dropall', 'reset', 'abort', 'commit', 'send', 'ask', 'show', 'focus', 'hide' }
      return vim.tbl_filter(function(item) return item:match('^' .. argLead) end, subs)
    end,
  })
end

-- auto-initialize with defaults
M.setup()

vim.api.nvim_create_autocmd("FileChangedShellPost", {
  callback = highlight_changes,
})

return M
