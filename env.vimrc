" disable netrw, rtp+=. will load the treevial plugin
let g:loaded_netrw       = 1
let g:loaded_netrwPlugin = 1

" allow plugins to load
set nocompatible

" vim (not nvim) has this off by default, nvim is on by default,
" something good to point out to potential users if this gets
" released
syntax on

" less painful debugging experience
if (isdirectory($HOME . '/.vim/plugged/vim-tmux-navigator/'))
  set rtp+=$HOME/.vim/plugged/vim-tmux-navigator/
endif

" easily identify highlight groups with <space>gp
nnoremap <silent> <space>gp :echo map(
      \ synstack(line('.'), col('.')),
      \ 'synIDattr(v:val, "name")'
      \ )<Cr>

" source current directory
set rtp+=.
set splitright splitbelow

nnoremap <C-w> :bd<Cr>
