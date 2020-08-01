set nocompatible
set rtp+=~/.vim/plugged/vader.vim
set rtp+=.
if (isdirectory($HOME . '/.vim/plugged/vim-tmux-navigator/'))
  set rtp+=$HOME/.vim/plugged/vim-tmux-navigator/
endif
so syntax/treevial.vim
so autoload/treevial/util.vim
syntax enable
