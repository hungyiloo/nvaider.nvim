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

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "nvaider" })
end

local function reset_state()
  M.state.job_id = nil
  M.state.buf_nr = nil
  M.state.win_id = nil
  if M.state.check_timer then
    M.state.check_timer:stop()
    M.state.check_timer:close()
    M.state.check_timer = nil
  end
end

local function is_running()
  if M.state.buf_nr and not vim.api.nvim_buf_is_valid(M.state.buf_nr) then
    reset_state()
  end
  if M.state.job_id then return true end
  return false
end

-- ensure the aider process is running
local function ensure_running()
  if not is_running() then
    M.start()
    if not is_running() then
      notify("Aider could not start", vim.log.levels.ERROR)
      return false
    end
  end
  return true
end

local function get_terminal_width()
  return math.floor(vim.o.columns * 0.35)
end

local function close_window()
  if M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id) then
    vim.api.nvim_win_close(M.state.win_id, true)
    M.state.win_id = nil
  end
end

local function is_window_showing()
  return M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id)
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

-- debounce state for question notifications (in ms)
local last_question_notify = 0
local QUESTION_DEBOUNCE_MS = 1000
local function handle_stdout_prompt(data)
  local last_line = ""
  for _, line in ipairs(data) do
    -- strip ANSI escape/control characters from terminal output
    local text = (last_line .. line):gsub("\n", ""):gsub("\27%[%??[0-9;]*[ABCDHJKlmsu]", "")
    text = string.sub(text, 1, #text - 1) -- last character of the line seems to be junk

    -- detect unanswered questions based on yes/no pattern and an ending colon
    if (text:match("%(Y%)") or text:match("%(N%)")) and text:match(":") then
      local now = vim.loop.now()
      if now - last_question_notify > QUESTION_DEBOUNCE_MS then
        notify("Aider might have a question for you. :Aider focus to answer it.")
        last_question_notify = now
      end
    end
    last_line = line
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
    vim.cmd('silent! checktime')
    -- clean up
    M.state.check_timer:stop()
    M.state.check_timer:close()
    M.state.check_timer = nil
  end))
end

function M.start(args_override)
  if M._starting then
    return
  end
  M._starting = true

  local function do_start()
    local buf = vim.api.nvim_create_buf(false, true)
    -- treat empty args_override as nil
    if args_override ~= nil and #args_override == 0 then
      args_override = nil
    end
    local args = vim.list_extend({ M.config.cmd }, args_override or M.config.args)
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
          close_window()
          reset_state()
        end,
      })
      notify("Starting aider")
      M._starting = false
    end)
    M.state.buf_nr = buf
  end

  if is_running() then
    -- Restart: stop current instance and start new one with potentially different args
    local old_job_id = M.state.job_id
    local was_window_showing = is_window_showing()
    close_window()
    reset_state()

    -- Stop the old job and wait for it to exit before starting new one
    if old_job_id then
      vim.fn.jobstop(old_job_id)
    end
    notify("Restart trigerred…")

    -- Poll until the job actually exits, then start new one
    local function wait_for_exit()
      local restart_timer = vim.uv.new_timer()
      if restart_timer then
        restart_timer:start(50, 50, vim.schedule_wrap(function()
          -- Check if job is still running
          if old_job_id and vim.fn.jobwait({old_job_id}, 0)[1] == -1 then
            -- Job still running, keep waiting
            return
          end

          -- Job has exited, clean up timer and start new instance
          restart_timer:stop()
          restart_timer:close()
          do_start()
          if was_window_showing then
            open_window(false)
          end
        end))
      end
    end

    wait_for_exit()
  else
    do_start()
  end
end

function M.stop()
  if not M.state.job_id then return end
  vim.fn.jobstop(M.state.job_id)
  close_window()
  reset_state()
  notify("Stopped aider")
end

function M.toggle()
  if not ensure_running() then return end
  if is_window_showing() then
    close_window()
  else
    local current_win = open_window(false)
    vim.api.nvim_set_current_win(current_win)
  end
end

function M.send(text)
  if not ensure_running() then return end
  if text:find('\n') then
    text = "{nvaider\n" .. text .. "\nnvaider}"
  end
  vim.fn.chansend(M.state.job_id, text .. '\n')
end

function M.ask(text)
  M.send('/ask ' .. text)
end

function M.add()
  if not ensure_running() then return end
  local file = vim.fn.expand('%:p')
  M.send("/add " .. file)
  notify("Added file: " .. file)
end

function M.read()
  if not ensure_running() then return end
  local file = vim.fn.expand('%:p')
  M.send("/read-only " .. file)
  notify("Read-only file added: " .. file)
end

function M.drop()
  if not ensure_running() then return end
  local file = vim.fn.expand('%:p')
  M.send("/drop " .. file)
  notify("Dropped file: " .. file)
end

function M.dropall()
  if not ensure_running() then return end
  M.send("/drop")
  notify("All files dropped")
end

function M.reset()
  if not ensure_running() then return end
  M.send("/reset")
end

function M.abort()
  if not ensure_running() then return end
  vim.fn.chansend(M.state.job_id, "\003") -- Ctrl+C
  notify("Sent abort signal to aider")
end

function M.commit()
  if not ensure_running() then return end
  M.send("/commit")
  notify("Committed changes")
end

function M.show()
  if not ensure_running() then return end
  if is_window_showing() then return end
  local current_win = open_window(false)
  vim.api.nvim_set_current_win(current_win)
end

function M.hide()
  close_window()
end

function M.focus()
  if not ensure_running() then return end
  if is_window_showing() then
    vim.api.nvim_set_current_win(M.state.win_id)
    vim.cmd('startinsert')
  else
    open_window(true)
  end
end

function M.dispatch(sub, args)
  local function handle_user_input(cmd_fn, prompt)
    local txt = table.concat(args or {}, ' ')
    if txt == '' then
      local mode = vim.fn.mode()
      if mode == 'v' or mode == 'V' or mode == '\22' then
        local esc = vim.api.nvim_replace_termcodes('<esc>', true, false, true)
        vim.api.nvim_feedkeys(esc, 'x', false)
        local bufnr = vim.api.nvim_get_current_buf()
        local _, from_row, from_col = unpack(vim.fn.getpos("'<"))
        local _, to_row, to_col = unpack(vim.fn.getpos("'>"))
        from_col = from_col - 1
        from_row = from_row - 1
        to_col = math.min(to_col, string.len(vim.fn.getline(to_row)))
        to_row = to_row - 1
        local text = vim.api.nvim_buf_get_text(bufnr, from_row, from_col, to_row, to_col, {})
        cmd_fn(table.concat(text, '\n'))
      else
        vim.ui.input({ prompt = prompt }, function(input)
          if not input or input == '' then return end
          cmd_fn(input)
        end)
      end
    else
      cmd_fn(txt)
    end
  end

  if sub == 'start' then
    M.start(args)
  elseif sub == 'launch' then
    local current_args = table.concat(M.config.args, ' ')
    vim.ui.input({
      prompt = 'aider args> ',
      default = current_args
    }, function(input)
      if not input then return end
      local launch_args = vim.fn.split(input)
      M.start(launch_args)
    end)
  elseif sub == 'stop' then
    M.stop()
  elseif sub == 'toggle' then
    M.toggle()
  elseif sub == 'add' then
    M.add()
  elseif sub == 'read' then
    M.read()
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
    handle_user_input(M.send, 'aider> ')
  elseif sub == 'ask' then
    handle_user_input(M.ask, 'ask aider> ')
  elseif sub == 'show' then
    M.show()
  elseif sub == 'focus' then
    M.focus()
  elseif sub == 'hide' then
    M.hide()
  else
    notify('Unknown subcommand: ' .. tostring(sub), vim.log.levels.ERROR)
  end
end

function M.setup(opts)
  M.config = vim.tbl_extend('force', M.config, opts or {})
  if M._initialized then return end
  M._initialized = true
  vim.api.nvim_create_user_command('Aider', function(cmd_opts)
    local args = vim.fn.split(cmd_opts.args)
    local sub = args[1]
    table.remove(args, 1)
    M.dispatch(sub, args)
  end, {
    nargs = '*',
    range = true,
    complete = function(argLead, cmdLine, cursorPos)
      local subs = { 'start', 'launch', 'stop', 'toggle', 'add', 'read', 'drop', 'dropall', 'reset', 'abort', 'commit', 'send', 'ask', 'show', 'focus', 'hide' }
      return vim.tbl_filter(function(item) return item:match('^' .. argLead) end, subs)
    end,
  })
end

-- auto-initialize with defaults
M.setup()


return M
