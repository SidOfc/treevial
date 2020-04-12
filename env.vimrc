" allow plugins to load
set nocompatible

" vim (not nvim) has this off by default, nvim is on by default,
" something good to point out to potential users if this gets
" released
syntax on

" source current directory
set rtp+=.

" below are things I need to stay sane during development
set wildignore=.git,.DS_Store
set splitright splitbelow

" less painful debugging experience
if (isdirectory($HOME . '/.vim/plugged/vim-tmux-navigator/'))
  set rtp+=$HOME/.vim/plugged/vim-tmux-navigator/
endif

nnoremap <C-w> :bd<Cr>

" easily identify highlight groups with <space>gp
nnoremap <silent> <space>gp :echo map(
      \ synstack(line('.'), col('.')),
      \ 'synIDattr(v:val, "name")'
      \ )<Cr>
