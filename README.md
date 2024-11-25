# Usearch.nvim

## Description
A search and replace plugin for neovim written in lua. It uses `ripgrep` to search and `perl` to replace text.

## Features
- Search and replace text in current working directory through neovim, which makes undoing changes easy.
- Search with `ripgrep`, which uses modern regex syntax. You don't have to deal with the quirks of BRE/ERE/Posix regex.
- Replace with `perl`, which uses pcre regex syntax. Sed cannot use `\d` for example.
- Floating window for search, replace, ignore and an output window for results. You can easily get a grasp of what changes will be made before you make them.


## Usage
```lua
-- Create a new search. This will open a floating window with search, replace, ignore and output windows.
-- Press <Tab> and <Shift-Tab> to navigate between windows, and <esc> to close the floating window.
require('usearch').new_search()

-- Did you close your search window? No problem. Just open it again. All of the state is saved.
require('usearch').toggle_search()

-- Ready to perform your replaces? Great.
require('usearch').perform_replace()

-- Whoops! You made a mistake. No problem. Just undo your changes.
require('usearch').rollback()
```


## Status
This plugin is in development. It is not ready for use.
