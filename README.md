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

- **Treevial does not leave buffers `&modified` AND `&readonly`**
- Treevial has one clear view mode: Tree view.
- Treevial supports "single file/folder" merging like github.
- Treevial has 3 "sane" mappings for performing file actions:
  - <kbd>m</kbd>: Move file or selection
  - <kbd>d</kbd>: Delete file or selection
  - <kbd>c</kbd>: Create file or directory
- And also two "sane" mappings for file selections:
  - <kbd>tab</kbd>: Toggle mark and move to next line
  - <kbd>shift</kbd>+<kbd>tab</kbd>: Toggle mark and move to previous line

## Roadmap

- [ ] Completely isolate tests from each other.
- [ ] Support "sidebar" style.
- [ ] Make colors configurable to allow for colorblind-friendly schemes.
- [ ] Make mappings configurable.
- [ ] Document, document, document, document, document!!

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
