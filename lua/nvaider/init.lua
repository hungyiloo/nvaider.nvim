local M = {
  config = {
    cmd = "aider",
    profiles = {
      default = {},
    },
  },
}

-- Per-tab state tracking
local tab_states = {}

local function get_state()
  local tab_id = vim.api.nvim_get_current_tabpage()
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

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "nvaider" })
end

local function cleanup_timer(timer)
  if timer then
    timer:stop()
    timer:close()
  end
  return nil
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

local function get_terminal_width()
  return math.floor(vim.o.columns * 0.35)
end

local function is_window_showing()
  local state = get_state()
  return state.win_id and vim.api.nvim_win_is_valid(state.win_id)
end

local function open_window(enter_insert)
  local state = get_state()
  local current_win = vim.api.nvim_get_current_win()
  vim.cmd('rightbelow vsplit')
  state.win_id = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.win_id, state.buf_nr)
  vim.api.nvim_set_option_value('number', false, { win = state.win_id })
  vim.api.nvim_set_option_value('relativenumber', false, { win = state.win_id })
  local win_width = get_terminal_width()
  vim.api.nvim_win_set_width(state.win_id, win_width)
  vim.api.nvim_buf_set_keymap(state.buf_nr, 't', '<Esc>', [[<C-\><C-n>]], {noremap=true, silent=true})
  if enter_insert then vim.cmd('startinsert') end
  return current_win
end

local function close_window()
  local state = get_state()
  if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
    vim.api.nvim_win_close(state.win_id, true)
    state.win_id = nil
  end
end

local function reset_state(stop_job, close_win)
  local state = get_state()

  if stop_job and state.job_id then
    vim.fn.jobstop(state.job_id)
  end

  if close_win then
    close_window()
  end

  state.job_id = nil
  state.buf_nr = nil
  state.win_id = nil
  state.check_timer = cleanup_timer(state.check_timer)
end

local function is_running()
  local state = get_state()
  if state.buf_nr and not vim.api.nvim_buf_is_valid(state.buf_nr) then
    reset_state()
  end
  if state.job_id then return true end
  return false
end

-- ensure the aider process is running
local function ensure_running(callback)
  if is_running() then
    callback(true)
    return
  end

  -- Start aider and wait for it to actually start
  M.start()

  -- Poll until job is running or timeout
  local attempts = 0
  local max_attempts = 50 -- 5 seconds max
  local check_timer = vim.uv.new_timer()

  if not check_timer then return end
  check_timer:start(100, 100, vim.schedule_wrap(function()
    attempts = attempts + 1

    if is_running() then
      check_timer:stop()
      check_timer:close()
      callback(true)
    elseif attempts >= max_attempts then
      check_timer:stop()
      check_timer:close()
      notify("Aider could not start", vim.log.levels.ERROR)
      callback(false)
    end
  end))
end

-- debounce state for question notifications
local pending_question = nil
local question_timer = nil
local QUESTION_DEBOUNCE_MS = 500

local function handle_stdout_prompt(data)
  local accumulated_text = ""
  local has_question = false
  local question_text = ""

  for _, line in ipairs(data) do
    -- strip ANSI escape/control characters from terminal output
    local clean_line = line:gsub("\27%[%??[0-9;]*[ABCDHJKlmsuh]", "")

    -- accumulate text across lines
    accumulated_text = accumulated_text .. "\n" .. clean_line

    -- detect unanswered questions based on yes/no pattern and an ending colon
    if (accumulated_text:match("%(Y%)") or accumulated_text:match("%(N%)")) and accumulated_text:match(":") then
      has_question = true
      question_text = accumulated_text:gsub("^%s*", ""):gsub("%s*$", "")
    end
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
        notify(
          "Aider might need your input; use [:Aider send] or [:Aider focus].\n\n" .. pending_question:gsub("^", "> "),
          vim.log.levels.WARN
        )
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
  local state = get_state()
  if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
    if vim.api.nvim_get_current_win() ~= state.win_id then
      pcall(vim.api.nvim_win_call, state.win_id, function() vim.cmd('normal! G') end)
    end
  end
end

local function debounce_check()
  local state = get_state()
  state.check_timer = cleanup_timer(state.check_timer)
  state.check_timer = vim.uv.new_timer()
  state.check_timer:start(100, 0, vim.schedule_wrap(function()
    vim.cmd('silent! checktime')
    -- clean up
    state.check_timer = cleanup_timer(state.check_timer)
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
      local state = get_state()
      state.last_args = final_args
      local args = vim.list_extend({ M.config.cmd }, final_args)
      vim.api.nvim_buf_call(buf, function()
        state.job_id = vim.fn.jobstart(args, {
          term = true,
          width = get_terminal_width(),
          cwd = vim.fn.getcwd(),
          on_stdout = function(_, data, _)
            handle_stdout_prompt(data)
            scroll_to_latest()
            debounce_check()
          end,
          on_exit = function()
            reset_state(false, true)
          end,
        })
        notify("Starting " .. table.concat(args, ' '))
        M._starting = false
      end)
      state.buf_nr = buf
      M.show()
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
    local old_job_id = get_state().job_id
    reset_state(false, true)

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
  local state = get_state()
  if not state.job_id then return end
  reset_state(true, true)
  notify("Stopped aider")
end

function M.stop_all()
  local stopped_count = 0
  for tab_id, state in pairs(tab_states) do
    if state.job_id then
      stopped_count = stopped_count + 1
    end
    -- Temporarily set current tab state to clean up this specific state
    local current_tab = vim.api.nvim_get_current_tabpage()
    tab_states[current_tab] = state
    reset_state(true, true)
  end
  tab_states = {}
  if stopped_count > 0 then
    notify("Stopped " .. stopped_count .. " aider instance(s) across all tabs")
  else
    notify("No aider instances were running")
  end
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
  ensure_running(function(success)
    if not success then return end
    if text:find('\n') then
      text = "{nvaider\n" .. text .. "\nnvaider}"
    end
    vim.fn.chansend(get_state().job_id, text .. '\n')
  end)
end

function M.add()
  ensure_running(function(success)
    if not success then return end
    local file = vim.fn.expand('%:p')
    send_text_with_cr("/add " .. file)
    notify("Added file: " .. file)
  end)
end

function M.read()
  ensure_running(function(success)
    if not success then return end
    local file = vim.fn.expand('%:p')
    send_text_with_cr("/read-only " .. file)
    notify("Read-only file added: " .. file)
  end)
end

function M.drop()
  ensure_running(function(success)
    if not success then return end
    local file = vim.fn.expand('%:p')
    send_text_with_cr("/drop " .. file)
    notify("Dropped file: " .. file)
  end)
end

function M.drop_all()
  ensure_running(function(success)
    if not success then return end
    send_text_with_cr("/drop")
    notify("All files dropped")
  end)
end

function M.reset()
  ensure_running(function(success)
    if not success then return end
    send_text_with_cr("/reset")
  end)
end

function M.abort()
  ensure_running(function(success)
    if not success then return end
    vim.fn.chansend(get_state().job_id, "\003") -- Ctrl+C
    notify("Sent abort signal to aider")
  end)
end

function M.commit()
  ensure_running(function(success)
    if not success then return end
    send_text_with_cr("/commit")
    notify("Committed changes")
  end)
end

function M.show()
  ensure_running(function(success)
    if not success then return end
    if is_window_showing() then return end
    local current_win = open_window(false)
    vim.api.nvim_set_current_win(current_win)
  end)
end

function M.hide()
  close_window()
end

function M.focus()
  ensure_running(function(success)
    if not success then return end
    if is_window_showing() then
      vim.api.nvim_set_current_win(get_state().win_id)
      vim.cmd('startinsert')
    else
      open_window(true)
    end
  end)
end

function M.rewrite_args()
  local current_args = table.concat(get_state().last_args or {}, ' ')
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
    -- treat empty args as nil
    if args ~= nil and #args == 0 then
      args = nil
    end
    M.start(args)
  elseif sub == 'rewrite_args' then
    M.rewrite_args()
  elseif sub == 'stop' then
    M.stop()
  elseif sub == 'stop_all' then
    M.stop_all()
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

  -- Cleanup aider state when tab is closed
  vim.api.nvim_create_autocmd("TabClosed", {
    callback = function(args)
      local tab_id = tonumber(args.match)
      if tab_id ~= nil and tab_states[tab_id] then
        -- Temporarily set current tab state to clean up this specific state
        local current_tab = vim.api.nvim_get_current_tabpage()
        local original_state = tab_states[current_tab]
        tab_states[current_tab] = tab_states[tab_id]
        reset_state(true, false)
        tab_states[current_tab] = original_state
        tab_states[tab_id] = nil
      end
    end
  })

  vim.api.nvim_create_user_command('Aider', function(cmd_opts)
    local args = vim.fn.split(cmd_opts.args)
    local sub = args[1]
    table.remove(args, 1)
    dispatch(sub, args)
  end, {
      nargs = '*',
      range = true,
      complete = function(argLead, cmdLine, cursorPos)
        local subs = { 'start', 'rewrite_args', 'stop', 'stop_all', 'toggle', 'add', 'read', 'drop', 'drop_all', 'reset', 'abort', 'commit', 'send', 'ask', 'show', 'focus', 'hide' }
        return vim.tbl_filter(function(item) return item:match('^' .. argLead) end, subs)
      end,
    })
end

-- auto-initialize with defaults
M.setup()


return M
