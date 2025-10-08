# Grapple

[![Test Status][icon]][status]

[icon]: https://github.com/pyrmont/grapple/workflows/test/badge.svg
[status]: https://github.com/pyrmont/grapple/actions?query=workflow%3Atest

Grapple is an mREPL server for Janet.

> [!WARNING]
> Jeep is in an alpha stage of development. There are likely to be bugs and
> gaps in its implementation.

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

Install directly:

```console
$ git clone https://github.com/pyrmont/grapple
$ cd grapple
$ janet -b .
$ grapple -h
```

Or using [Jeep][]:

```console
$ jeep install https://github.com/pyrmont/grapple
$ grapple -h
```

[Jeep]: https://github.com/pyrmont/grapple

## Usage

### Server

Grapple can be imported as a library into an existing project:

```janet
(import grapple)

(setdyn :grapple/log-level :debug)
(grapple/server/start "127.0.0.1" 3737)
```

Alternatively, Grapple's CLI utility can be used like this in your project
root:

```shell
$ grapple --host "127.0.0.1" --port 3737 --logging "debug"
```

### Client

#### Neovim (Conjure)

Grapple comes with a client for [Conjure][], a Neovim plugin. Add this to your
`init.lua`:

**lazy.nvim**

```lua
require("lazy").setup({
  <...>

  {
    dir = "<janet-syspath>/grapple",
    dependencies = { "Olical/nfnl", ft = "fennel" },
    config = function(plugin)
      vim.opt.rtp:append(plugin.dir .. "/res/plugins/grapple.nvim")
    end,
  },
  {
    "Olical/conjure",
    init = function()
      vim.g["conjure#log#strip_ansi_escape_sequences_line_limit"] = 1000
      vim.g["conjure#filetype#janet"] = "grapple.client"
      vim.g["conjure#log#wrap"] = true
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
