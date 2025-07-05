# 🤖 `nvaider.nvim`

> [!WARNING] 
> This project is still under active development and the interfaces are unstable and may change. 
> However, it is more than usable, with many of the commits in this repo being made using nvaider.nvim itself.

A Neovim plugin that seamlessly integrates [aider](https://github.com/paul-gauthier/aider) - the AI pair programming tool - directly into your editor. Run aider in a side terminal, manage tracked files, and send commands without leaving Neovim.

![screenshot](https://github.com/user-attachments/assets/d9df533a-2c11-44b2-8279-c4e8f828c68e)

## Features

- 🚀 **Single command interface** - Everything through `:Aider <subcommand>`
- 📁 **Profile management** - Define different aider configurations for different workflows
- 🖥️ **Integrated terminal** - Aider runs in a side window within Neovim
- 📂 **File management** - Add, drop, and manage tracked files from within your editor
- 💬 **Direct communication** - Send messages and questions to aider without switching contexts
- 🔄 **Smart notifications** - Get notified when aider needs your attention
- ⌨️ **Flexible input** - Send text via command args, prompts, or visual selections

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
require("lazy").setup({
  {
    "hungyiloo/nvaider.nvim",
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
    },
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
      { "<leader>a<backspace>", ":Aider stop<cr>", desc = "Stop aider" },
      { "<leader>af", ":Aider focus<cr>", desc = "Focus aider terminal" },
      
      -- Advanced
      { "<leader>ac", ":Aider commit<cr>", desc = "Commit with aider" },
      { "<leader>aR", ":Aider reset<cr>", desc = "Reset aider session" },
      { "<leader>ax", ":Aider abort<cr>", desc = "Abort current operation" },
      { "<leader>a!", ":Aider rewrite_args<cr>", desc = "Change aider arguments" },
      
      -- Visual mode mappings
      { mode = "x", "<leader>a.", function() require("nvaider").send() end, desc = "Send selection to aider" },
      { mode = "x", "<leader>a?", function() require("nvaider").ask() end, desc = "Ask about selection" },
    }
  },
})
```

### Prerequisites

- [aider](https://github.com/paul-gauthier/aider) installed and available in your PATH
- Neovim 0.8+ (uses `vim.ui.input` and `vim.notify`)

## Quick Start

1. **Start aider**: `:Aider start` (or use your configured keybinding)
2. **Add files**: `:Aider add` to track the current file
3. **Send messages**: `:Aider send` and type your request
4. **Toggle window**: `:Aider toggle` to show/hide the aider terminal

## Usage Examples

### Basic Workflow
```vim
:Aider start              " Start aider with your default profile
:Aider add                " Add current file to aider's context
:Aider send Fix the bug in the login function
:Aider commit             " Commit the changes aider made
```

### Working with Multiple Files
```vim
:Aider add                " Add current file
" Switch to another file
:Aider add                " Add this file too
:Aider send Refactor these two files to use a shared utility
```

### Using Visual Selections
```vim
" Select some code in visual mode, then:
<leader>a.                " Send the selected code with a message
<leader>a?                " Ask a question about the selected code
```

## Command Reference

All functionality is accessed through the `:Aider` command with subcommands:

```
:Aider <subcommand> [optional arguments]
```

Tab completion is available for all subcommands.

### Managing the Aider Instance

- **`start [args...]`** - Start aider with optional argument overrides. If multiple profiles are configured, you'll be prompted to choose one.
- **`stop`** - Stop the aider process and close any open windows.
- **`rewrite_args`** - Modify the arguments for the current aider session. Prompts for new arguments and restarts aider.

### Window and Focus Management

- **`toggle`** - Show or hide the aider terminal window.
- **`show`** - Open the aider terminal window (if not already visible).
- **`hide`** - Close the aider terminal window.
- **`focus`** - Open the aider terminal window and enter insert mode for immediate typing.

### Managing Tracked Files

- **`add`** - Add the current file to aider's context for editing.
- **`read`** - Add the current file as read-only (aider can see it but won't modify it).
- **`drop`** - Remove the current file from aider's context.
- **`drop_all`** - Remove all files from aider's context.

### Sending Input to Aider

- **`send [text]`** - Send a message to aider. If no text is provided, you'll be prompted to enter it. In visual mode, sends the selected text.
- **`ask [text]`** - Send a question to aider using the `/ask` command. Prompts for input if no text provided.

### Advanced Operations

- **`commit`** - Tell aider to commit the current changes.
- **`reset`** - Reset aider's conversation history and context.
- **`abort`** - Send Ctrl+C to aider to interrupt the current operation.

## Configuration

### Options

| Option     | Type   | Default                    | Description                                 |
| ---------- | ------ | -------------------------- | ------------------------------------------- |
| `cmd`      | string | `"aider"`                  | The command or executable for aider.       |
| `profiles` | table  | `{ default = {} }`         | Named profiles with different argument sets.|

### Profile Examples

Profiles let you define different aider configurations for different workflows:

```lua
opts = {
  profiles = {
    -- Quick coding with Claude
    claude = { "--model", "claude-3-5-sonnet-20241022", "--cache-prompts" },
    
    -- GPT-4 with auto-commits disabled
    gpt4 = { "--model", "gpt-4o", "--no-auto-commits", "--watch-files" },
    
    -- Local model via Ollama
    local = { "--model", "ollama/qwen2.5-coder:32b" },
    
    -- Minimal setup
    basic = {},
  }
}
```

## Tips and Tricks

- **Smart notifications**: nvaider detects when aider is asking questions and notifies you to check the terminal.
- **Multi-line input**: When sending messages, you can include newlines. nvaider will automatically wrap them for aider.
- **Visual selections**: Select code and use the send/ask commands to work with specific code snippets.
- **File watching**: Use `--watch-files` in your profiles to have aider automatically detect file changes.
- **Window management**: The aider terminal remembers its size and position between sessions.

## Troubleshooting

- **Aider won't start**: Check that `aider` is installed and in your PATH
- **No response from aider**: Use `:Aider focus` to check if aider is waiting for input
- **Window issues**: Try `:Aider stop` and `:Aider start` to reset the session
