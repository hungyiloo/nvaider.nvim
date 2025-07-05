local M = {
  config = {
    cmd = "aider",
    profiles = {
      default = {},
    },
  },
  state = {
    last_args = nil,
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

local function handle_user_input(cmd_fn, prompt, args)
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

-- debounce state for question notifications
local pending_question = nil
local question_timer = nil
local QUESTION_DEBOUNCE_MS = 500

local function handle_stdout_prompt(data)
  local last_line = ""
  local has_question = false
  local question_text = ""

  for _, line in ipairs(data) do
    -- strip ANSI escape/control characters from terminal output
    local text = (last_line .. line):gsub("\n", ""):gsub("\27%[%??[0-9;]*[ABCDHJKlmsu]", "")
    text = string.sub(text, 1, #text - 1) -- last character of the line seems to be junk

    -- detect unanswered questions based on yes/no pattern and an ending colon
    if (text:match("%(Y%)") or text:match("%(N%)")) and text:match(":") then
      has_question = true
      question_text = text
    end
    last_line = line
  end

  -- Cancel any existing timer
  if question_timer then
    question_timer:stop()
    question_timer:close()
    question_timer = nil
  end

  if has_question then
    -- Store the question and start a timer
    pending_question = question_text
    question_timer = vim.uv.new_timer()
    if not question_timer then return end
    question_timer:start(QUESTION_DEBOUNCE_MS, 0, vim.schedule_wrap(function()
      -- Timer expired, show the notification
      if pending_question then
        notify("Aider might have a question for you.\n\n" .. pending_question .. "\n\nUse :Aider send or focus to answer it.")
        pending_question = nil
      end
      question_timer:stop()
      question_timer:close()
      question_timer = nil
    end))
  else
    -- Non-question output received, cancel any pending question notification
    pending_question = nil
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

    local function start_with_args(final_args)
      M.last_args = final_args
      local args = vim.list_extend({ M.config.cmd }, final_args)
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
        notify("Starting " .. table.concat(args, ' '))
        M._starting = false
      end)
      M.state.buf_nr = buf
      M.show()
    end

    -- treat empty args_override as nil
    if args_override ~= nil and #args_override == 0 then
      args_override = nil
    end

    if args_override then
      start_with_args(args_override)
    else
      local profiles = M.config.profiles or {}
      local profile_names = vim.tbl_keys(profiles)
      table.sort(profile_names)
      if #profile_names == 0 then
        -- No profiles defined, use empty args
        start_with_args({})
      elseif #profile_names == 1 then
        -- Only one profile, use it directly
        start_with_args(profiles[profile_names[1]])
      else
        -- Multiple profiles, let user select
        vim.ui.select(profile_names, {
          prompt = 'Select nvaider profile:',
        }, function(choice)
          if not choice then
            M._starting = false
            return
          end
          start_with_args(profiles[choice])
        end)
      end
    end
  end

  if is_running() then
    -- Restart: stop current instance and start new one with potentially different args
    local old_job_id = M.state.job_id
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
  if not is_running() then
    M.start()
  else
    if is_window_showing() then
      close_window()
    else
      local current_win = open_window(false)
      vim.api.nvim_set_current_win(current_win)
    end
  end
end

local function send_text_with_cr(text)
  if not ensure_running() then return end
  if text:find('\n') then
    text = "{nvaider\n" .. text .. "\nnvaider}"
  end
  vim.fn.chansend(M.state.job_id, text .. '\n')
end

function M.add()
  if not ensure_running() then return end
  local file = vim.fn.expand('%:p')
  send_text_with_cr("/add " .. file)
  notify("Added file: " .. file)
end

function M.read()
  if not ensure_running() then return end
  local file = vim.fn.expand('%:p')
  send_text_with_cr("/read-only " .. file)
  notify("Read-only file added: " .. file)
end

function M.drop()
  if not ensure_running() then return end
  local file = vim.fn.expand('%:p')
  send_text_with_cr("/drop " .. file)
  notify("Dropped file: " .. file)
end

function M.drop_all()
  if not ensure_running() then return end
  send_text_with_cr("/drop")
  notify("All files dropped")
end

function M.reset()
  if not ensure_running() then return end
  send_text_with_cr("/reset")
end

function M.abort()
  if not ensure_running() then return end
  vim.fn.chansend(M.state.job_id, "\003") -- Ctrl+C
  notify("Sent abort signal to aider")
end

function M.commit()
  if not ensure_running() then return end
  send_text_with_cr("/commit")
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

function M.rewrite_args()
  local current_args = table.concat(M.last_args or {}, ' ')
  vim.ui.input(
    {
      prompt = 'aider args> ',
      default = current_args
    },
    function(input)
      if not input then return end
      local launch_args = vim.fn.split(input)
      M.start(launch_args)
    end
  )
end

function M.send(args)
  handle_user_input(send_text_with_cr, 'aider> ', args)
end

function M.ask(args)
  handle_user_input(function (input) send_text_with_cr('/ask ' .. input) end, 'ask aider> ', args)
end

local function dispatch(sub, args)
  if sub == 'start' then
    M.start(args)
  elseif sub == 'rewrite_args' then
    M.rewrite_args(args)
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
  elseif sub == 'drop_all' then
    M.drop_all()
  elseif sub == 'reset' then
    M.reset()
  elseif sub == 'abort' then
    M.abort()
  elseif sub == 'commit' then
    M.commit()
  elseif sub == 'send' then
    M.send(args)
  elseif sub == 'ask' then
    M.ask(args)
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
    dispatch(sub, args)
  end, {
    nargs = '*',
    range = true,
    complete = function(argLead, cmdLine, cursorPos)
      local subs = { 'start', 'rewrite_args', 'stop', 'toggle', 'add', 'read', 'drop', 'drop_all', 'reset', 'abort', 'commit', 'send', 'ask', 'show', 'focus', 'hide' }
      return vim.tbl_filter(function(item) return item:match('^' .. argLead) end, subs)
    end,
  })
end

-- auto-initialize with defaults
M.setup()


return M
