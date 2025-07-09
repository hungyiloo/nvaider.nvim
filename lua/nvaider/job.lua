local util = require('nvaider.util')
local state = require('nvaider.state')
local config = require('nvaider.config')

local M = {}

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
        util.notify(
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

local function debounce_check()
  local s = state.get_state()
  s.check_timer = util.cleanup_timer(s.check_timer)
  s.check_timer = vim.uv.new_timer()
  s.check_timer:start(100, 0, vim.schedule_wrap(function()
    vim.cmd('silent! checktime')
    -- clean up
    s.check_timer = util.cleanup_timer(s.check_timer)
  end))
end

function M.start(args_override)
  if M._starting then
    return
  end
  M._starting = true

  local function do_start()
    local window = require('nvaider.window')
    local buf = vim.api.nvim_create_buf(false, true)

    local function start_with_args(final_args)
      local s = state.get_state()
      s.last_args = final_args
      local args = vim.list_extend({ config.cmd }, final_args)
      vim.api.nvim_buf_call(buf, function()
        s.job_id = vim.fn.jobstart(args, {
          term = true,
          width = window.get_window_size(),
          cwd = vim.fn.getcwd(),
          on_stdout = function(_, data, _)
            handle_stdout_prompt(data)
            window.scroll_to_latest()
            debounce_check()
          end,
          on_exit = function()
            state.reset_state(false, true)
          end,
        })
        util.notify("Starting " .. table.concat(args, ' '))
        M._starting = false
      end)
      s.buf_nr = buf
      window.show()
    end

    if args_override then
      start_with_args(args_override)
    else
      local profiles = config.profiles or {}
      local profile_names = vim.tbl_keys(profiles)
      table.sort(profile_names)
      if #profile_names == 0 then
        start_with_args({})
      elseif #profile_names == 1 then
        start_with_args(profiles[profile_names[1]])
      else
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

  if state.is_running() then
    local old_job_id = state.get_state().job_id
    state.reset_state(false, true)

    if old_job_id then
      vim.fn.jobstop(old_job_id)
    end
    util.notify("Restart trigerred…")

    local function wait_for_exit()
      local restart_timer = vim.uv.new_timer()
      if restart_timer then
        restart_timer:start(50, 50, vim.schedule_wrap(function()
          if old_job_id and vim.fn.jobwait({old_job_id}, 0)[1] == -1 then
            return
          end
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

function M.ensure_running(callback)
  if state.is_running() then
    callback(true)
    return
  end

  M.start()

  local attempts = 0
  local max_attempts = 50 -- 5 seconds max
  local check_timer = vim.uv.new_timer()

  if not check_timer then return end
  check_timer:start(100, 100, vim.schedule_wrap(function()
    attempts = attempts + 1

    if state.is_running() then
      check_timer:stop()
      check_timer:close()
      callback(true)
    elseif attempts >= max_attempts then
      check_timer:stop()
      check_timer:close()
      util.notify("Aider could not start", vim.log.levels.ERROR)
      callback(false)
    end
  end))
end

function M.stop()
  local s = state.get_state()
  if not s.job_id then return end
  state.reset_state(true, true)
  util.notify("Stopped aider")
end

function M.stop_all()
  local stopped_count = 0
  for tab_id, s in pairs(state.tab_states) do
    if s.job_id then
      stopped_count = stopped_count + 1
    end
    state.reset_state(true, true, tab_id)
  end
  state.tab_states = {}
  if stopped_count > 0 then
    util.notify("Stopped " .. stopped_count .. " aider instance(s) across all tabs")
  else
    util.notify("No aider instances were running")
  end
end

function M.send_text_with_cr(text)
  M.ensure_running(function(success)
    if not success then return end
    if text:find('\n') then
      text = "{nvaider\n" .. text .. "\nnvaider}"
    end
    vim.fn.chansend(state.get_state().job_id, text .. '\n')
  end)
end

function M.abort()
  M.ensure_running(function(success)
    if not success then return end
    vim.fn.chansend(state.get_state().job_id, "\003") -- Ctrl+C
    util.notify("Sent abort signal to aider")
  end)
end

return M
