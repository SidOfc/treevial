" allow plugins to load
set nocompatible

" vim (not nvim) has this off by default, nvim is on by default,
" something good to point out to potential users if this gets
" released
syntax on

" source current directory
set rtp+=.

" Treevial settings
" let g:treevial_sidebar = 1

" below are things I need to stay sane during development
set wildignore=.git,.DS_Store
set splitright splitbelow
set nowrap

" even while disabling swap files within treevial buffers
" vim still writes them to disk for reasons I have yet to figure out
set noswf

if has('nvim')
  set termguicolors
endif

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
