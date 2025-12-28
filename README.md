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
- dependent binding tracking

Grapple implements the mREPL protocol. mREPL is an in-development message-based
REPL protocol, similar to nREPL but with a simpler design.

## Installing

Grapple consists of a server and a client that communicate using the mREPL
protocol. The server is a Janet CLI utility, `grapple`. The client is your
editor (using a plugin). At the time of writing, the only supported editor is
Neovim with [Conjure][].

[Conjure]: https://conjure.oli.me.uk

### Server

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

## Using

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

The client can start the server if one is not running. This is explained in more
detail below.

### Client

#### Neovim

Once configured, Grapple provides the following key bindings when editing Janet files:

**Server Management:**
- `<localleader>cs`: Starts the Grapple server
- `<localleader>cS`: Stops the Grapple server
- `<localleader>cc`: Connects to the server
- `<localleader>cd`: Disconnects from the server

**Code Evaluation:**
- `<localleader>ee`: Evaluates the form under the cursor
- `<localleader>er`: Evaluates the root form under the cursor
- `<localleader>eb`: Evaluates the entire buffer
- `<localleader>ef`: Evaluates a file
- `<localleader>e!`: Evaluates and replaces the form with its result
- `<localleader>em`: Evaluates the marked form
- `<localleader>ew`: Evaluates the word under the cursor

By default, `<localleader>` is mapped to `\` in Neovim.

The server can be started automatically when the client connects (this is enabled
by default). To disable this, add the following to your Neovim configuration:

```lua
vim.g["conjure#client#janet#mrepl#connection#auto_repl#enabled"] = false
```

For more evaluation commands and features, see the [Conjure documentation][].

[Conjure documentation]: https://github.com/Olical/conjure/blob/master/doc/conjure.txt

## Bugs

Found a bug? I'd love to know about it. The best way is to report your bug in
the [Issues][] section on GitHub.

[Issues]: https://github.com/pyrmont/grapple/issues

## Licence

Grapple is licensed under the MIT Licence. See [LICENSE][] for more details.

[LICENSE]: https://github.com/pyrmont/grapple/blob/master/LICENSE
