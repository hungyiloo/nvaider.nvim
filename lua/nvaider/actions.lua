local job = require('nvaider.job')
local state = require('nvaider.state')
local util = require('nvaider.util')

local M = {}

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

function M.add()
  job.ensure_running(function(success)
    if not success then return end
    local file = vim.fn.expand('%:p')
    job.send_text_with_cr("/add " .. file)
    util.notify("Added file: " .. file)
  end)
end

function M.read()
  job.ensure_running(function(success)
    if not success then return end
    local file = vim.fn.expand('%:p')
    job.send_text_with_cr("/read-only " .. file)
    util.notify("Read-only file added: " .. file)
  end)
end

function M.drop()
  job.ensure_running(function(success)
    if not success then return end
    local file = vim.fn.expand('%:p')
    job.send_text_with_cr("/drop " .. file)
    util.notify("Dropped file: " .. file)
  end)
end

function M.drop_all()
  job.ensure_running(function(success)
    if not success then return end
    job.send_text_with_cr("/drop")
    util.notify("All files dropped")
  end)
end

function M.reset()
  job.ensure_running(function(success)
    if not success then return end
    job.send_text_with_cr("/reset")
  end)
end

function M.commit()
  job.ensure_running(function(success)
    if not success then return end
    job.send_text_with_cr("/commit")
    util.notify("Committed changes")
  end)
end

function M.rewrite_args()
  local current_args = table.concat(state.get_state().last_args or {}, ' ')
  vim.ui.input(
    {
      prompt = 'aider args> ',
      default = current_args
    },
    function(input)
      if not input then return end
      local launch_args = vim.fn.split(input)
      job.start(launch_args)
    end
  )
end

function M.send(args)
  handle_user_input(job.send_text_with_cr, 'aider> ', args)
end

function M.ask(args)
  handle_user_input(function (input) job.send_text_with_cr('/ask ' .. input) end, 'aider ask> ', args)
end

function M.architect(args)
  handle_user_input(function (input) job.send_text_with_cr('/architect ' .. input) end, 'aider architect> ', args)
end

return M
