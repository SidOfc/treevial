if exists('g:loaded_treevial')
  finish
endif

let g:loaded_treevial = 1
let s:util            = {}
let s:is_nvim         = has('nvim')
let s:is_vim          = !s:is_nvim
let s:save_cpo        = &cpo
set cpo&vim

function! treevial#vimenter() abort
  let root_target = get(argv(), 0, getcwd())
  let no_lnum     = line2byte('$') ==# -1

  if isdirectory(root_target) && no_lnum && !&insertmode && &modifiable
    call treevial#buffer()
  endif
endfunction

function! treevial#buffer(...) abort
  noautocmd edit treevial

  let options   = get(a:,      1,         {})
  let refresh   = get(options, 'bang',    !exists('b:entries'))
  let cwd       = get(options, 'cwd',     getcwd())
  let b:root    = get(b:,      'root',    s:entry(cwd, fnamemodify(cwd, ':h')))
  let b:entries = get(b:,      'entries', [])

  if refresh
    let b:root    = s:entry(cwd, fnamemodify(cwd, ':h'))
    let b:entries = []
  endif

  silent! setlocal
        \ filetype=treevial
        \ bufhidden=hide
        \ buftype=nowrite
        \ noruler
        \ laststatus=0
        \ shiftwidth=2
        \ nonumber
        \ nomodifiable
        \ readonly
        \ norelativenumber
        \ nospell
        \ noswapfile
        \ signcolumn=no

  nnoremap <silent><buffer> <S-Cr> :call treevial#open({'shift': 1})<Cr>
  nnoremap <silent><buffer> <Cr>   :call treevial#open()<Cr>
  nnoremap <silent><buffer> <C-v>  :call treevial#open({'command': 'vspl'})<Cr>
  nnoremap <silent><buffer> <C-x>  :call treevial#open({'command': 'spl'})<Cr>

  if refresh
    call b:root.expand()
    call treevial#render()
  endif

  let b:booted = 1
endfunction

function! treevial#entry_under_cursor() abort
  let lnum = line('.') - 2

  return lnum >? -1 ? get(get(b:entries, lnum, []), 0, 0) : 0
endfunction

function! treevial#open(...) abort
  let settings = get(a:, 1, {})
  let entry    = treevial#entry_under_cursor()

  if type(entry) ==# type({})
    if entry.is_dir
      call entry.toggle(settings)
      call treevial#render()
    else
      call entry.open(settings)
    endif
  endif
endfunction

function! treevial#render() abort
  call treevial#update()
  call treevial#draw()
endfunction

function! treevial#update() abort
  let b:entries = b:root.list()
endfunction

function! treevial#winrestview(position) abort
  let curr_winnr = winnr()
  let windows    = filter(map(
        \ win_findbuf(bufnr('%')),
        \ 'win_id2win(v:val)'),
        \ 'v:val !=# ' . curr_winnr)

  for winnr in windows
    exe winnr . 'wincmd w'
    call winrestview(a:position)
  endfor

  exe curr_winnr . 'wincmd w'
  call winrestview(a:position)
endfunction

function! treevial#draw() abort
  let saved_view   = winsaveview()
  let target       = bufname('%')
  let current_lnum = 0

  setlocal modifiable noreadonly

  call s:util.clear_buffer()
  call append(current_lnum, b:root.name)

  for [data, idx] in map(copy(b:entries), '[v:val, v:key]')
    let current_lnum   += 1
    let [entry, depth]  = data
    let indent          = repeat(' ', depth * &sw)
    let prefix          = entry.is_dir && len(entry.children())
          \ ? entry.is_open ? '- ' : '+ '
          \ : '  '

    call append(current_lnum, indent . prefix . entry.name)
  endfor

  call s:util.clear_trailing_empty_lines_from_buffer()
  call treevial#winrestview(saved_view)

  setlocal nomodified nomodifiable readonly
endfunction

function! s:util.clear_buffer() abort
  exe 'normal! ggdG:\<Esc>'
endfunction

function! s:util.clear_trailing_empty_lines_from_buffer() abort
  while empty(getline('$'))
    exe 'normal! dd:\<Esc>'
  endwhile
endfunction

function! s:entry(path, root) abort
  let is_dir = isdirectory(a:path)
  let path   = fnamemodify(a:path, ':p')
  let entry  = {
        \ 'name': substitute(path, a:root, '', '')[1:],
        \ 'path': path,
        \ 'is_dir': is_dir,
        \ 'is_open': 0
        \ }

  call extend(entry, {
        \ 'update': function('extend', [entry]),
        \ 'expand': function('s:entry_expand', entry),
        \ 'collapse': function('s:entry_collapse', entry),
        \ 'toggle': function('s:entry_toggle', entry),
        \ 'children': function('s:entry_children', entry),
        \ 'list': function('s:entry_list', entry),
        \ 'open': function('s:entry_open', entry)
        \ })

  return entry
endfunction

function! s:entry_open(...) dict
  let options = get(a:, 1, {})

  exe get(options, 'command', 'edit') fnameescape(self.path)
endfunction

function! s:entry_toggle(...) dict
  let settings = get(a:, 1, {})

  return self.is_open ? self.collapse(settings) : self.expand(settings)
endfunction

function! s:entry_collapse(...) dict
  let settings  = get(a:, 1, {})
  let recursive = get(settings, 'shift', 0)

  call self.update({'is_open': 0})

  if self.is_dir && recursive && has_key(self, '_children')
    for child_entry in self.children()
      call child_entry.collapse(settings)
    endfor
  endif

  return self
endfunction

function! s:entry_expand(...) dict
  call self.update({'is_open': self.is_dir})

  for child_entry in self.children()
    let result_entry = child_entry

    while len(result_entry.children()) ==# 1
      let result_entry = result_entry.children()[0]
    endwhile

    if child_entry.path !=# result_entry.path
      call child_entry.update({
            \ 'name': substitute(result_entry.path, self.path, '', ''),
            \ 'path': result_entry.path,
            \ 'is_dir': result_entry.is_dir,
            \ '_children': []
            \ })
    endif
  endfor

  return self
endfunction

function! s:entry_children() dict
  if self.is_dir && !has_key(self, '_children')
    let root     = substitute(self.path, '/\+$', '', '')
    let children = sort(sort(map(filter(
        \ glob(root . '/*',  0, 1) +
        \ glob(root . '/.*', 0, 1),
        \ {_,  p  -> p !~# '/\.\.\?$'}),
        \ {_,  p  -> s:entry(p, root)}),
        \ {x1, x2 -> x1.name >? x2.name}),
        \ {x1, x2 -> x2.is_dir - x1.is_dir})

    call extend(self, {'_children': children})
  endif

  return get(self, '_children', [])
endfunction

function! s:entry_list(...) dict
  let depth  = get(a:, 1, 0)
  let result = []

  for entry in self.children()
    call add(result, [entry, depth])
    if entry.is_open
      call extend(result, entry.list(depth + 1))
    endif
  endfor

  return result
endfunction

if !exists(':Treevial')
  command -bang Treevial call treevial#buffer({'bang': <bang>0})
endif

augroup treevial
  autocmd!
  autocmd VimEnter * nested call treevial#vimenter()
augroup END

let &cpo = s:save_cpo
unlet s:save_cpo
