# 🤖 `nvaider.nvim`

A minimalist Neovim plugin to integrate the [aider](https://github.com/your/aider) CLI via a side terminal and a single `:Aider` command with subcommands.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
require("lazy").setup({
  {
    "hungyiloo/nvaider.nvim",
    opts = {
      -- The aider binary or command to run
      cmd = "aider",
      -- Additional arguments passed to the aider CLI
      args = { "--model", "sonnet", "--watch-files" },
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
      { mode = "x", "<leader>a.", function () require("nvaider").dispatch("send") end, desc = "Send to aider", noremap = true, silent = true },
      { mode = "x", "<leader>a?", function () require("nvaider").dispatch("ask") end, desc = "Ask aider", noremap = true, silent = true },
      { mode = "n", "<leader>ac", ":Aider commit<cr>", desc = "Commit changes with aider", noremap = true, silent = true },
      { mode = "n", "<leader>af", ":Aider focus<cr>", desc = "Focus input on aider", noremap = true, silent = true },
      { mode = "n", "<leader>a!", ":Aider start<cr>", desc = "Start aider (background)", noremap = true, silent = true },
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
  Starts aider in a hidden terminal buffer (use with aider's [`--watch-files`](https://aider.chat/docs/usage/watch.html)).  
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

| Option | Type   | Default        | Description                                 |
| ------ | ------ | -------------- | ------------------------------------------- |
| `cmd`  | string | `"aider"`      | The command or executable for aider.   |
| `args` | list   | `{} `          | List of extra CLI arguments to pass on start.|

You can override these in your `lazy.nvim` setup under the `opts` table.

## License

MIT
