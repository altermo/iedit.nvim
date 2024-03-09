# Iedit.nvim
*A lua rewrite of [emacs's iedit](https://github.com/victorhge/iedit).*

Edit one occurrence of text and simultaneously have other selected occurrences edited in the same way.

## Usage
1. You start iedit with `iedit.select()`.
2. The text which will be used is word-under-cursor in normal mode, and visually selected in visual mode.
3. Selection-mode will be started. (where you can chose which occurrences of text you want to iedit)
4. You select which instances of text you want to iedit.
5. You mapping corresponding to done in selection-mode, thus starting iedit-mode.
5. You do some editing.
6. You stop iedit-mode with `iedit.stop()`.

## Setup & Config
Using `iedit.setup()` is **not required**, it just changes the config.
The default config is:
```lua
{
 select={
  map={
   q={'done'},
   ['<Esc>']={'select','done'},
   ['<CR>']={'toggle'},
   n={'toggle','next'},
   p={'toggle','prev'},
   N={'next'},
   P={'prev'},
   a={'all'},
   --Mapping to use while in selection-mode
   --Possible values are:
   -- • `done` Done with selection
   -- • `next` Go to next occurrence
   -- • `prev` Go to previous occurrence
   -- • `select` Select current
   -- • `unselect` Unselect current
   -- • `toggle` Toggle current
   -- • `all` Select all
  },
  highlight={
   current='CurSearch',
   selected='Search'
  }
 },
 highlight='IncSearch',
}
```
Set `merge=false` in a (non-array) table in the config to **not merge** with the default config.

## Donations
If you want to donate then you need to find the correct link (hint: catorce):
+ [00]() [10]() [20]() [30]() [40]() [50]()
+ [01]() [11]() [21]() [31]() [41]() [51]()
+ [02]() [12]() [22]() [32]() [42]() [52]()
+ [03]() [13]() [23]() [33]() [43]() [53]()
+ [04]() [14](https://www.buymeacoffee.com/altermo) [24]() [34]() [44]() [54]()
+ [05]() [15]() [25]() [35]() [45]() [55]()
