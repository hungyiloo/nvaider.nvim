local util = require('nvaider.util')
local state = require('nvaider.state')
local job = require('nvaider.job')
local window = require('nvaider.window')
local actions = require('nvaider.actions')

local M = {
  config = require('nvaider.config')
}

-- Export functions to be available for user commands
M.start = job.start
M.stop = job.stop
M.stop_all = job.stop_all
M.abort = job.abort
M.add = actions.add
M.read = actions.read
M.drop = actions.drop
M.drop_all = actions.drop_all
M.reset = actions.reset
M.commit = actions.commit
M.rewrite_args = actions.rewrite_args
M.send = actions.send
M.ask = actions.ask
M.architect = actions.architect
M.show = window.show
M.hide = window.hide
M.focus = window.focus
M.toggle = window.toggle

local function dispatch(sub, args)
  -- treat empty args as nil
  if args ~= nil and #args == 0 then
    args = nil
  end

  if sub == 'start' then
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
  elseif sub == 'architect' then
    M.architect(args)
  elseif sub == 'show' then
    M.show()
  elseif sub == 'focus' then
    M.focus()
  elseif sub == 'hide' then
    M.hide()
  else
    util.notify('Unknown subcommand: ' .. tostring(sub), vim.log.levels.ERROR)
  end
end

function M.setup(opts)
  if opts then
    M.config.update(opts)
  end
  if M._initialized then return end
  M._initialized = true

  -- Cleanup aider state when tab is closed
  vim.api.nvim_create_autocmd("TabClosed", {
    callback = function(args)
      local tab_id = tonumber(args.match)
      if tab_id ~= nil and state.tab_states[tab_id] then
        state.reset_state(true, false, tab_id)
        state.tab_states[tab_id] = nil
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
        local subs = { 'start', 'rewrite_args', 'stop', 'stop_all', 'toggle', 'add', 'read', 'drop', 'drop_all', 'reset', 'abort', 'commit', 'send', 'ask', 'architect', 'show', 'focus', 'hide' }
        return vim.tbl_filter(function(item) return item:match('^' .. argLead) end, subs)
      end,
    })
end

-- auto-initialize with defaults


return M
