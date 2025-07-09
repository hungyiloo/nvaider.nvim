# 🤖 `nvaider.nvim`

> [!NOTE] 
> This project is still under active development and the interfaces are unstable and may change. 
> However, it is more than usable, with many of the commits in this repo being made using itself.

A Neovim plugin that seamlessly integrates [aider](https://github.com/paul-gauthier/aider) -- the AI pair programming tool -- directly into your editor. Run aider in a side terminal, manage tracked files, and send commands without leaving Neovim.

![screenshot](https://github.com/user-attachments/assets/d9df533a-2c11-44b2-8279-c4e8f828c68e)

## Features

- 🚀 **Single command interface** - Everything through `:Aider <subcommand>`
- 📁 **Profile management** - Define different aider configurations for different situations
- 🖥️ **Integrated terminal** - Aider runs in a side window within Neovim
- 📂 **File management** - Add, drop, and manage tracked files from within your editor
- 💬 **Direct communication** - Send messages and questions to aider without switching contexts
- ⌨️ **Flexible input** - Send text via command args, prompts, or visual selections
- 🔄 **Smart notifications** - Get notified when aider needs your attention
- 📑 **Per-tab instances** - run an instance of aider on each tab for easy context switching

## Installation

> [!IMPORTANT]
> - [aider](https://github.com/paul-gauthier/aider) must be installed and available in your PATH
> - Neovim must be on version 0.11+ 

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
require("lazy").setup({
  {
    "hungyiloo/nvaider.nvim",
    cmd = "Aider",

    -- nvaider will work without any configured opts, especially if you have an aider YAML/env setup
    opts = {
      -- The aider binary or command to run (default: "aider")
      cmd = "aider",

      -- Define named profiles with different argument sets
      profiles = {
        -- If only one profile is defined, nvaider will automatically use it
        default = { "--model", "sonnet", "--watch-files" },

        -- Multiple profiles will prompt you to choose on startup
        claude = { "--model", "claude-3-5-sonnet-20241022", "--cache-prompts", "--watch-files" },
        gpt4 = { "--model", "gpt-4o", "--watch-files", "--no-auto-commits" },
        ollama = { "--model", "ollama/qwen2.5-coder:32b" },
        minimal = {}
      },

      -- Window positioning and sizing
      window = {
        position = "right",  -- "top", "bottom", "left", "right"
        width = 0.35,        -- for left/right positions (fraction of total width)
        height = 0.3,        -- for top/bottom positions (fraction of total height)
      },
    },

    -- These are just suggested key mappings. Feel free to ignore.
    keys = {
      -- Essential mappings
      { "<leader>a<space>", ":Aider toggle<cr>", desc = "Toggle aider window" },
      { "<leader>aa", ":Aider add<cr>", desc = "Add current file to aider" },
      { "<leader>a.", ":Aider send<cr>", desc = "Send message to aider" },
      { "<leader>a?", ":Aider ask<cr>", desc = "Ask aider a question" },

      -- File management
      { "<leader>ar", ":Aider read<cr>", desc = "Add file as read-only" },
      { "<leader>ad", ":Aider drop<cr>", desc = "Drop current file" },
      { "<leader>aD", ":Aider drop_all<cr>", desc = "Drop all files" },

      -- Instance management
      { "<leader>a<cr>", ":Aider start<cr>", desc = "Start/restart aider" },
      { "<leader>aq", ":Aider stop<cr>", desc = "Stop aider" },
      { "<leader>aQ", ":Aider stop_all<cr>", desc = "Stop all aider instances" },
      { "<leader>af", ":Aider focus<cr>", desc = "Focus aider terminal" },

      -- Advanced
      { "<leader>a>", ":Aider architect<cr>", desc = "Architect with aider" },
      { "<leader>ac", ":Aider commit<cr>", desc = "Commit with aider" },
      { "<leader>aR", ":Aider reset<cr>", desc = "Reset aider session" },
      { "<leader>ax", ":Aider abort<cr>", desc = "Abort current operation" },
      { "<leader>a!", ":Aider rewrite_args<cr>", desc = "Change aider arguments" },

      -- Visual mode mappings
      { mode = "x", "<leader>a.", function() require("nvaider").send() end, desc = "Send selection to aider" },
      { mode = "x", "<leader>a?", function() require("nvaider").ask() end, desc = "Ask about selection" },
      { mode = "x", "<leader>a>", function() require("nvaider").architect() end, desc = "Architect with selection" },
    }
  },
})
```

## Quick Start

1. **Start aider**: `:Aider start` (or use your configured keybinding)
2. **Add files**: `:Aider add` to track the current file
3. **Send messages**: `:Aider send` and type your request
4. **Toggle window**: `:Aider toggle` to show/hide the aider terminal

## Usage Examples

Basic workflow:
```vim
:Aider start              " Start aider with your default profile
:Aider add                " Add current file to aider's context
:Aider send Fix the bug in the login function
:Aider commit             " Commit the changes aider made
```

Working with multiple files:
```vim
:Aider add                " Add current file
" Switch to another file
:Aider add                " Add this file too
:Aider send Refactor these two files to use a shared utility
```

Using visual selections:
```vim
" Select some text or code in visual mode, then:
<leader>a.                " Send the selected text straight to aider
<leader>a?                " Send the selected text to aider in /ask mode
<leader>a>                " Send the selected text to aider in /architect mode
```

## Command Reference

All functionality is accessed through the `:Aider` command with subcommands:

```
:Aider <subcommand> [optional arguments, e.g. input text]
```

Tab completion is available for all subcommands.

Managing the aider instance:

- **`start [args...]`** - Start aider with optional argument overrides. If multiple profiles are configured, you'll be prompted to choose one.
- **`stop`** - Stop the aider process and close any open windows.
- **`stop_all`** - Stop all aider instances across all tabs and clean up all state.
- **`rewrite_args`** - Modify the arguments for the current aider session. Prompts for new arguments and restarts aider.

Window and focus management:

- **`toggle`** - Show or hide the aider terminal window.
- **`show`** - Open the aider terminal window (if not already visible).
- **`hide`** - Close the aider terminal window.
- **`focus`** - Open the aider terminal window and enter insert mode for immediate typing.

Managing tracked files:

- **`add`** - Add the current file to aider's context for editing.
- **`read`** - Add the current file as read-only (aider can see it but won't modify it).
- **`drop`** - Remove the current file from aider's context.
- **`drop_all`** - Remove all files from aider's context.

Sending input to aider:

- **`send [text]`** - Send a message to aider. If no text is provided, you'll be prompted to enter it. In visual mode, sends the selected text.
- **`ask [text]`** - Send a question to aider using the `/ask` command. Prompts for input if no text provided.
- **`architect [text]`** - Send design instructions to aider using the `/architect` command. Prompts for input if no text provided.

Advanced operations:

- **`commit`** - Tell aider to commit the current changes.
- **`reset`** - Reset aider's conversation history and context.
- **`abort`** - Send Ctrl+C to aider to interrupt the current operation.

## Configuration

Options:

| Option     | Type   | Default                    | Description                                 |
| ---------- | ------ | -------------------------- | ------------------------------------------- |
| `cmd`      | string | `"aider"`                  | The command or executable for aider.       |
| `profiles` | table  | `{ default = {} }`         | Named profiles with different argument sets.|
| `window`   | table  | See below                  | Window positioning and sizing options.      |


`window`:

| Option       | Type   | Default   | Description                                           |
| ------------ | ------ | --------- | ----------------------------------------------------- |
| `position`   | string | `"right"` | Window position: `"top"`, `"bottom"`, `"left"`, `"right"` |
| `width`      | number | `0.35`    | Window width as fraction of total width (for left/right positions) |
| `height`     | number | `0.3`     | Window height as fraction of total height (for top/bottom positions) |


```lua
opts = {
  -- profiles let you define different aider configurations for different workflows
  profiles = {
    -- Quick coding with Claude
    claude = { "--model", "claude-3-5-sonnet-20241022", "--cache-prompts" },
    
    -- GPT-4 with auto-commits disabled
    gpt4 = { "--model", "gpt-4o", "--no-auto-commits", "--watch-files" },
    
    -- Local model via Ollama
    local = { "--model", "ollama/qwen2.5-coder:32b" },
    
    -- Minimal setup
    basic = {},
  },

  -- Configure window positioning and sizing
  window = {
    position = "right",  -- Open aider terminal at bottom of screen
    height = 0.35,       -- Use 35% of screen height
  }
}
```

## Tips and Tricks

- **Multi-line input**: When sending messages, you can include newlines. nvaider will automatically wrap them for aider.
- **Visual selections**: Select text or code and use the send/ask/architect commands to work with larger instructions and input. _(hint: use a scratch buffer to compose code examples and instructions together into one prompt or question)_
- **File watching**: Use `--watch-files` in your profiles to have aider automatically detect "ai!" comments in your code to magically trigger changes.
- **Smart notifications**: nvaider detects when aider is asking questions and notifies you. _(hint: use `:Aider send` to send a simple `y` or `n`)_
- **Send any input**: `:Aider send` isn't just for prompts; you can also send arbitrary commands like `/help` or `/architect` to aider.


## Troubleshooting

- **Aider won't start**: Check that `aider` is installed and in your PATH
- **No response from aider**: Use `:Aider focus` to check if aider is waiting for input
- **Window issues**: Try `:Aider stop`, deleting any leftover stuck windows, then `:Aider start` to reset the session
