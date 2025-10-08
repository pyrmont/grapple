# Grapple

[![Test Status][icon]][status]

[icon]: https://github.com/pyrmont/grapple/workflows/test/badge.svg
[status]: https://github.com/pyrmont/grapple/actions?query=workflow%3Atest

Grapple is an mREPL server for Janet.

> [!WARNING]
> Grapple is in an alpha stage of development. There are likely to be bugs and
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

```bash
$ git clone https://github.com/pyrmont/grapple
$ cd grapple
$ janet -b .
# assuming <janet-syspath>/bin is on your PATH
$ grapple -h
```

Or using [Jeep][]:

```bash
$ jeep install https://github.com/pyrmont/grapple
# assuming <janet-syspath>/bin is on your PATH
$ grapple -h
```

[Jeep]: https://github.com/pyrmont/jeep

## Usage

Grapple consists of a server and a client that communicate using the mREPL
protocol. The server is a Janet CLI utility, `grapple`. The client is your
editor (using a plugin). At the time of writing, the only supported editor is
Neovim with [Conjure][].

[Conjure]: https://conjure.oli.me.uk

### Server

Grapple's CLI utility can be used like so in the root of the project you're
developing:

```bash
$ grapple --host "127.0.0.1" --port 3737 --logging debug
```
Alternatively, Grapple can be imported as a library into an existing project:

```janet
(import grapple)

(setdyn :grapple/log-level :debug)
(grapple/server/start "127.0.0.1" 3737)
```

Or if you just want to get going quickly, launch Neovim from your project root
and the client will either connect to an existing instance of `grapple` or, if
one is not availabe, Grapple will start an instance automatically when you open
a `*.janet` file.

### Client

#### Neovim

To use Grapple with Neovim, you can install it using the following package
managers. For `<janet-syspath>`, fill in the path to the location where Grapple
was installed (e.g. `/usr/local/lib/janet/`).

##### lazy.nvim

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

##### vim-plug

```vimscript
call plug#begin('~/.vim/plugged')

" Dependencies
Plug 'Olical/nfnl'
Plug 'Olical/conjure'

" Grapple (local path)
Plug '<janet-syspath>/grapple/res/plugins/grapple.nvim'

call plug#end()

" Configure Conjure for Janet + Grapple
let g:conjure#filetype#janet = 'grapple.client'
```

## Bugs

Found a bug? I'd love to know about it. The best way is to report your bug in
the [Issues][] section on GitHub.

[Issues]: https://github.com/pyrmont/grapple/issues

## Licence

Grapple is licensed under the MIT Licence. See [LICENSE][] for more details.

[LICENSE]: https://github.com/pyrmont/grapple/blob/master/LICENSE
