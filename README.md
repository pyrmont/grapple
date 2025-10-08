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
# assuming <janet-syspath>/bin is on your PATH
$ grapple -h
```

Or using [Jeep][]:

```console
$ jeep install https://github.com/pyrmont/grapple
# assuming <janet-syspath>/bin is on your PATH
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

Alternatively, Grapple's CLI utility can be used like this in your bundle
root:

```shell
$ grapple --host "127.0.0.1" --port 3737 --logging "debug"
```

Or if you just want to get going quickly, launch Neovim from your bundle root
and it will start an instance of `grapple` automatically.

### Client

#### Neovim (Conjure)

Grapple comes with a client for [Conjure][], a Neovim plugin. Add this to your
`init.lua`:

**lazy.nvim**

```lua
require("lazy").setup({
  <...>

  {
    dir = "<janet-syspath>/grapple/res/plugins/grapple.nvim",
    dependencies = { "Olical/nfnl" },
  },
  {
    "Olical/conjure",
    init = function()
      vim.g["conjure#filetype#janet"] = "grapple.client"
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
