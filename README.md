# Treevial

:warning::construction: Treevial is under development! :construction::warning:

Treevial is yet another file explorer for (n)vim. With this plugin enabled,
Netrw will be disabled and Treevial will launch instead.

## Motivation

There really is no proper motivation aside from that infuriating feeling
**every. single. time.** I try to close (n)vim and I see that dreaded nonsense
warning about Netrw having left its buffer in some illegal state again.

Unfortunately Netrw is just too broken. I tried using it, [read](https://shapeshed.com/vim-netrw/)
up on why you don't need a directory plugin, tried to throw
the best known netrw-enhancement [vim-vinegar](https://github.com/tpope/vim-vinegar)
at it, at some point I cried in a corner for a while, then decided
to try it for myself.

I am actually thankful for this experience though. Because of the frustration, true
motivation was born and put to use for a (hopefully) more positive experience.

## Why Treevial?

- **Treevial does not leave buffers `&modified` AND `&readonly`**.
- it has some tests.
- it has one clear view mode: Tree view.
- it supports "single file/folder" merging like github.

## Core functionality

- It has 3 mappings for navigating up and down the tree
  - <kbd>-</kbd>: may be preceded by a count of how many directories to move up
  - <kbd>=</kbd>: move into directory, may be preceded by count on folded paths to move into Nth directory from left
  - <kbd>.</kbd>: move to the initial root directory when you first opened (n)vim
  - <kbd>~</kbd>: move to the home directory
- It has 4 mappings to handle file opening and directory expanding / collapsing
  - <kbd>enter</kbd>: toggle directory open / closed or if file, open it in a buffer
  - <kbd>shift</kbd>+<kbd>enter</kbd>: same as enter except when closing, closes all nested child directories (**nvim only by default**)
  - <kbd>ctrl</kbd>+<kbd>v</kbd>: open file in vertical split, no-op on directories
  - <kbd>ctrl</kbd>+<kbd>x</kbd>: open file in horizontal split, no-op on directories
- It has 3 mappings for performing actions:
  - <kbd>m</kbd>: Move below cursor or selection
  - <kbd>d</kbd>: Delete below cursor or selection
  - <kbd>c</kbd>: Create below cursor or directory
- And 3 mappings to handle selections:
  - <kbd>u</kbd>: unmark all
  - <kbd>tab</kbd>: Toggle mark below cursor and move to next line
  - <kbd>shift</kbd>+<kbd>tab</kbd>: Toggle mark below cursor and move to previous line

## Roadmap

- [x] Fix resync issue causing failure to unmark parent entries properly.
- [x] Completely isolate tests from each other.
- [x] Make mappings configurable.
- [x] document `g:treevial_*` settings.
- [x] Write more tests.
    - [x] marking / unmarking child directories.
    - [x] marking / unmarking folded paths.
    - [x] moving more than one file / directory at once.
    - [x] deleting more than one file / directory at once.
- [ ] Make the README user-friendly.

## Development

After cloning the repo, use the following command to start (n)vim with minimal required setup:

```sh
nvim -Nu dev.vimrc
```

This loads (n)vim in **N**ocompatible mode, **u**sing provided **dev.vimrc**.

## Testing

Treevial uses [junegunn/vader.vim](https://github.com/junegunn/vader.vim) as its testing framework.
It assumes `vader.vim` is installed in `$HOME/.vim/plugged/vader.vim`.

There is only a limited amount of tests available since there's only a limited
amount of things I know how to test (somewhat) properly :sweat_smile:. To run the tests,
use the following command to start (n)vim with minimal required testing setup:

```sh
nvim -Nu test.vimrc -c 'Vader test/main.vader'
```

Using `Vader` instead of `Vader!` keeps (n)vim open to allow for debugging.
If you've got ideas on how to test more functionality of Treevial, please drop
an me an issue :+1:
