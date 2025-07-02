# nvaider

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
      args = { "--model", "o4-mini", "--watch-files" },
    },
  },
})
```

## Usage

The plugin defines a single user command:

  :Aider <subcommand> [text]

Available subcommands:

- `start`  
  Starts aider in a hidden terminal buffer (use with aider's [`--watch-files`](https://aider.chat/docs/usage/watch.html)).  
- `stop`  
  Stops aider process and closes any open window.  
- `toggle`  
  Toggles a side window displaying aider terminal.  
- `show`  
  Opens a side window displaying aider terminal.  
- `hide`  
  Closes the side window displaying aider terminal.  
- `focus`  
  Opens the side window displaying aider terminal and enters input mode.  
- `add`  
  Sends `/add <current-file-path>` to aider.  
- `drop`  
  Sends `/drop <current-file-path>` to aider.  
- `dropall`  
  Sends `/drop` to aider, removing all tracked files.  
- `reset`  
  Sends `/reset` to aider, clearing all state.  
- `commit`  
  Sends `/commit` to aider and notifies on completion.  
- `send [text]`  
  Sends arbitrary text. If no text is provided, prompts you for input.

Tab completion for subcommands is available when typing `:Aider ` and pressing `<Tab>`.

## Configuration Options

| Option | Type   | Default        | Description                                 |
| ------ | ------ | -------------- | ------------------------------------------- |
| `cmd`  | string | `"aider"`      | The command or executable for aider.   |
| `args` | list   | `{} `          | List of extra CLI arguments to pass on start.|

You can override these in your `lazy.nvim` setup under the `opts` table.

## License

MIT
