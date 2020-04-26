# Treevial

:warning::construction: Treevial is under development! :warning::construction:

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
to *screw it* and try it for myself.

I am actually thankful for this experience though. Because of the frustration, true
motivation was born and put to use for a (hopefully) more positive experience.

## Why Treevial?

- <1k total LoC (this will likely grow beyond 1K before initial release, we'll see)
- Treevial has one clear view mode: Tree view.
- Treevial supports "single file/folder" merging like github.
- Treevial has 3 "sane" mappings for performing file actions:
  - <kbd>m</kbd>: Move file or selection
  - <kbd>d</kbd>: Delete file or selection
  - <kbd>c</kbd>: Create file or directory
- And also two "sane" mappings for file selections:
  - <kbd>tab</kbd>: Toggle mark and move to next line
  - <kbd>shift</kbd>+<kbd>tab</kbd>: Toggle mark and move to previous line

## Why not Treevial

- Heavily dependent on colors to indicate symlinks / executables / marks (e.g. not colorblind friendly at the moment, feel free to tip me off though!)
- Treevial is in early stages of development, it has no README, wiki or
  doc/treevial.txt file of any significance.
- Does not support left / right sidebar style display / popout mode yet
- Mappings are not configurable at the moment.
- The amount of `glob()` calls can be cut down by using a single recursive
  search tool such as ripgrep.

## Development

After cloning the repo, use the following command to start (n)vim with minimal required setup:

```sh
nvim -Nu dev.vimrc
```

This loads (n)vim in **N**ocompatible mode, **u**sing provided **dev.vimrc**.

## Testing

There is only a limited amount of tests available since there's only a limited
amount of things I know how to test (somewhat) properly :sweat_smile:. To run the tests,
use the following command to start (n)vim with minimal required testing setup:

```sh
nvim -Nu test.vimrc -c 'Vader test/main.vader'
```

Using `Vader` instead of `Vader!` keeps (n)vim open to allow for debugging.
If you've got ideas on how to test more functionality of Treevial, please drop
an me an issue :+1:
