# 🤖 `nvaider.nvim`

> [!WARNING] 
> This project is still under active development and the interfaces are unstable and may change. 
> However, I dogfood this plugin every day for work purposes and it's stable under my usage patterns.

A minimalist Neovim plugin to integrate the [aider](https://github.com/your/aider) CLI via a side terminal and a single `:Aider` command with subcommands.

![screenshot](https://github.com/user-attachments/assets/d9df533a-2c11-44b2-8279-c4e8f828c68e)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
require("lazy").setup({
  {
    "hungyiloo/nvaider.nvim",

    -- All opts are optional
    opts = {
      -- The aider binary or command to run
      cmd = "aider",

      -- Define named profiles with different argument sets
      profiles = {
        -- If only one profile is defined, nvaider will automatically use it without asking
        default = { "--model", "sonnet", "--watch-files" },

        -- Otherwise, you can add more profiles and nvaider will prompt you for a choice on each start
        claude = { "--model", "claude-3-5-sonnet-20241022", "--cache-prompts", "--watch-files" },
        gpt4 = { "--model", "gpt-4o", "--watch-files", "--no-auto-commits" },
        ollama = { "--model", "ollama/qwen2.5-coder:32b" },
        empty = {}
      },
    },
    -- optional key mappings
    keys = {
      { mode = "n", "<leader>a<space>", ":Aider toggle<cr>", desc = "Toggle aider", noremap = true, silent = true },
      { mode = "n", "<leader>aa", ":Aider add<cr>", desc = "Add file", noremap = true, silent = true },
      { mode = "n", "<leader>ad", ":Aider drop<cr>", desc = "Drop file", noremap = true, silent = true },
      { mode = "n", "<leader>ar", ":Aider read<cr>", desc = "Add read-only file", noremap = true, silent = true },
      { mode = "n", "<leader>aD", ":Aider dropall<cr>", desc = "Drop all files", noremap = true, silent = true },
      { mode = "n", "<leader>aR", ":Aider reset<cr>", desc = "Reset aider", noremap = true, silent = true },
      { mode = "n", "<leader>a.", ":Aider send<cr>", desc = "Send to aider", noremap = true, silent = true },
      { mode = "n", "<leader>a?", ":Aider ask<cr>", desc = "Ask aider", noremap = true, silent = true },
      { mode = "x", "<leader>a.", function () require("nvaider").send() end, desc = "Send to aider", noremap = true, silent = true },
      { mode = "x", "<leader>a?", function () require("nvaider").ask() end, desc = "Ask aider", noremap = true, silent = true },
      { mode = "n", "<leader>ac", ":Aider commit<cr>", desc = "Commit changes with aider", noremap = true, silent = true },
      { mode = "n", "<leader>af", ":Aider focus<cr>", desc = "Focus input on aider", noremap = true, silent = true },
      { mode = "n", "<leader>a<cr>", ":Aider start<cr>", desc = "Start/restart aider", noremap = true, silent = true },
      { mode = "n", "<leader>a!", ":Aider launch<cr>", desc = "Start aider with arg overrides", noremap = true, silent = true },
      { mode = "n", "<leader>a<backspace>", ":Aider stop<cr>", desc = "Stop aider", noremap = true, silent = true },
      { mode = "n", "<leader>ax", ":Aider abort<cr>", desc = "Send C-c to aider", noremap = true, silent = true },
    }
  },
})
```

## Usage

The plugin defines a single user command:

  :Aider <subcommand> <optional input text>

Available subcommands:

- 🚀 `start`  
  Starts aider. If multiple profiles are configured, prompts you to select one.
- 🚀 `launch`  
  Prompts for custom aider arguments and starts aider with those arguments (use this to edit the current running args).  
- 🛑 `stop`  
  Stops aider process and closes any open window.  
- 🔄 `toggle`  
  Toggles a side window displaying aider terminal.  
- 👀 `show`  
  Opens a side window displaying aider terminal.  
- 🙈 `hide`  
  Closes the side window displaying aider terminal.  
- 🔍 `focus`  
  Opens the side window displaying aider terminal and enters input mode.  
- ➕ `add`  
  Sends `/add <current-file-path>` to aider.  
- 📖 `read`  
  Sends `/read-only <current-file-path>` to aider, tracking the file in read-only mode.  
- 🗑️ `drop`  
  Sends `/drop <current-file-path>` to aider.  
- 🗑️ `dropall`  
  Sends `/drop` to aider, removing all tracked files.  
- ♻️ `reset`  
  Sends `/reset` to aider, clearing all state.  
- 🚫 `abort`  
  Sends an abort signal (Ctrl+C) to the running aider process.  
- ✅ `commit`  
  Sends `/commit` to aider and notifies on completion.  
- 📤 `send [text]`  
  Sends arbitrary text. If no text is provided, prompts you for input.  
- ❓ `ask [text]`  
  Sends `/ask <text>` to aider. If no text is provided, prompts you for input.  

Tab completion for subcommands is available when typing `:Aider ` and pressing `<Tab>`.

## Configuration Options

| Option     | Type   | Default                    | Description                                 |
| ---------- | ------ | -------------------------- | ------------------------------------------- |
| `cmd`      | string | `"aider"`                  | The command or executable for aider.       |
| `profiles` | table  | `{ default = {} }`         | Named profiles with different argument sets.|

You can override these in your `lazy.nvim` setup under the `opts` table.

## License

MIT
