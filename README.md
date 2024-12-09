# Grapple

Grapple is an mREPL server for Janet.

**Caution**: Grapple is in an alpha stage of development.

## Features

Grapple offers:

- form or whole-file evaluation
- per-file evaluation environments
- data-rich documentation and error values
- transitive `import` calls
- binding redefinition

Grapple implements the mREPL protocol. mREPL is an in-development message-based
REPL protocol, similar to nREPL but with a simpler design.

## Installation

Install via JPM:

```shell
$ jpm install https://github.com/pyrmont/grapple
$ grapple --help
```

## Usage

### Server

Grapple can be imported as a library into an existing project:

```janet
(import grapple/lib/server)

(setdyn :grapple/log-level :debug)
(server/start "127.0.0.1" 3737)
```

Alternatively, Grapple's CLI utility can be used like this in your project
root:

```shell
$ grapple --host "127.0.0.1" --port 3737 --logging "debug"
```

### Client

#### Neovim (Conjure)

Grapple comes with a client for [Conjure][], a Neovim plugin. If Conjure is installed,
add this to your `init.lua`:

**lazy.nvim**

```lua
require("lazy").setup({
  <...>

  {
    "pyrmont/grapple",
    config = function(plugin)
      vim.opt.rtp:append(plugin.dir .. "/res/plugins/grapple.nvim")
    end,
  },

  <...>
})
```

[Conjure]: https://conjure.oli.me.uk

## Bugs

Found a bug? I'd love to know about it. The best way is to report your bug in
the [Issues][] section on GitHub.

[Issues]: https://github.com/pyrmont/grapple/issues

## Licence

Grapple is licensed under the MIT Licence. See [LICENSE][] for more details.

[LICENSE]: https://github.com/pyrmont/grapple/blob/master/LICENSE
