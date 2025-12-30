# Iedit.nvim
*A lua rewrite of [emacs's iedit](https://github.com/victorhge/iedit).*

Edit one occurrence of text and simultaneously have other selected occurrences edited in the same way.

## Usage
1. You start iedit with `iedit.toggle()`.
2. The text which will be used is word-under-cursor in normal mode, and visually selected in visual mode.
3. You do some editing on the text, other instances of text will be changed.
4. You stop iedit-mode with `iedit.toggle()`.

## Functions
+ `iedit.toggle(match)` - toggle iedit-mode; when enabling: text will be word-under-cursor in normal mode and visually selected in visual mode.

+ `iedit.toggle_current_occurrence()` - toggle current occurrence to be included/decluded if cursor on occurrence

+ `iedit.goto_next_occurrence(wrap)` - goto next (active) occurrence
+ `iedit.goto_prev_occurrence(wrap)` - goto previous (active) occurrence
+ `iedit.goto_first_occurrence()` - goto first (active) occurrence
+ `iedit.goto_last_occurrence()` - goto last (active) occurrence

### Restrict
Restrictions are line-wise.
Node can fall outside of this restriction when they are manually toggled.
When changing restriction range, matching is redone (which means that manually toggled nodes get reset).

+ `iedit.restrict_current_line()` - restrict to current line
+ `iedit.restrict_visual()` - restrict to visually selected range
+ `iedit.restrict_range(start_row, end_row)` - restrict to range
+ `iedit.expand_up()` - expand restriction up
+ `iedit.expand_down()` - expand restriction down
+ `iedit.unexpand_up()` - unexpand restriction up
+ `iedit.unexpand_down()` - unexpand restriction down
+ `iedit.expand_next_occurrence()` - expand restriction to next occurrence after restriction end
+ `iedit.expand_prev_occurrence()` - expand restriction to prev occurrence before restriction start
+ `iedit.unexpand_next_occurrence()` - unexpand restriction to next occurrence after restriction start
+ `iedit.unexpand_prev_occurrence()` - unexpand restriction to prev occurrence before restriction end

## Setup & Config
Using `iedit.setup()` is **not required**, it just changes the config.
The default config is:
```lua
{
  highlight = 'IncSearch',
  end_right_gravity = true,
  right_gravity = false,
}
```

## Limitations relative to emacs's iedit
Arbitrary same-width pattern is not possible, as there is no (easy) way to get how the extmarked content get's changed, only what the change is. This disables case-toggle and use-(i)search.

## Alternatives
- [viedit](https://github.com/viocost/viedit)

## Donations
If you want to donate then you need to find the correct link (hint: catorce):
+ [00]() [10]() [20]() [30]() [40]() [50]()
+ [01]() [11]() [21]() [31]() [41]() [51]()
+ [02]() [12]() [22]() [32]() [42]() [52]()
+ [03]() [13]() [23]() [33]() [43]() [53]()
+ [04]() [14](https://www.buymeacoffee.com/altermo) [24]() [34]() [44]() [54]()
+ [05]() [15]() [25]() [35]() [45]() [55]()
