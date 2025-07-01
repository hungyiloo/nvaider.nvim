# nvaider

A minimalist Neovim plugin to integrate the [aider](https://github.com/your/aider) CLI via a floating terminal and a single `:Aider` command with subcommands.

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
      args = { "--watch-files" },
    },
  },
})
```

## Usage

The plugin defines a single user command:

  :Aider <subcommand> [text]

Available subcommands:

- `start`  
  Starts the helper in a hidden terminal buffer.  
- `stop`  
  Stops the helper process and closes any open window.  
- `toggle`  
  Opens or closes a centered floating window displaying the helper terminal.  
- `add`  
  Sends `add <current-file-path>` to the helper.  
- `drop`  
  Sends `drop <current-file-path>` to the helper.  
- `send [text]`  
  Sends arbitrary text. If no text is provided, prompts you for input.

Tab completion for subcommands is available when typing `:Aider ` and pressing `<Tab>`.

## Configuration Options

| Option | Type   | Default        | Description                                 |
| ------ | ------ | -------------- | ------------------------------------------- |
| `cmd`  | string | `"aider"`      | The command or executable for the helper.   |
| `args` | list   | `{} `          | List of extra CLI arguments to pass on start.|

You can override these in your `lazy.nvim` setup under the `opts` table.

## License

MIT
