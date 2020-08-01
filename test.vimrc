set nocompatible
set rtp+=~/.vim/plugged/vader.vim
set rtp+=.
if (isdirectory($HOME . '/.vim/plugged/vim-tmux-navigator/'))
  set rtp+=$HOME/.vim/plugged/vim-tmux-navigator/
endif
so syntax/treevial.vim
so autoload/treevial/settings.vim
so autoload/treevial/util.vim
so autoload/treevial/entry.vim
so autoload/treevial/io.vim
so autoload/treevial/view.vim
syntax enable
