if exists('g:loaded_treevial')
  finish
endif

let g:loaded_netrw       = 1
let g:loaded_netrwPlugin = 1
let g:loaded_treevial    = 1
let s:util               = {}
let s:view               = {}
let s:entry              = {}
let s:is_nvim            = has('nvim')
let s:is_vim             = !s:is_nvim
let s:save_cpo           = &cpo
set cpo&vim

function! treevial#open(...) abort
  let settings = get(a:, 1, {})
  let entry    = s:util.entry_under_cursor()

  if type(entry) ==# type({})
    if entry.is_dir
      call entry.toggle(settings)
      call s:view.render()
    else
      call entry.open(settings)
    endif
  endif
endfunction

function! s:view.buffer(...) abort
  noautocmd edit treevial

  let options   = get(a:,      1,         {})
  let reload    = get(options, 'bang',    !exists('b:entries'))
  let b:cwd     = get(options, 'cwd',     getcwd())
  let b:entries = get(b:,      'entries', [])
  let b:root    = get(b:,      'root',    s:entry.new(b:cwd).expand())

  setfiletype treevial
  setlocal noru nonu nornu noma nomod ro noswf nospell
  setlocal bufhidden=hide
  setlocal buftype=nowrite
  setlocal laststatus=0
  setlocal shiftwidth=2
  setlocal signcolumn=no

  augroup TreevialBuffer
    autocmd!
    autocmd BufEnter,FocusGained <buffer>
          \ call s:view.reload() |
          \ call s:view.render()
  augroup END

  if s:is_nvim
    nnoremap <buffer> <S-Cr> :call treevial#open({'shift': 1})<Cr>
  endif

  nnoremap <buffer> <Cr>  :call treevial#open()<Cr>
  nnoremap <buffer> <C-v> :call treevial#open({'command': 'vspl'})<Cr>
  nnoremap <buffer> <C-x> :call treevial#open({'command': 'spl'})<Cr>

  if reload
    call s:view.reload()
  else
    call s:view.render()
  endif
endfunction

function! s:view.render() abort
  call s:view.update()
  call s:view.draw()
endfunction

function! s:view.reload() abort
  let b:root = s:entry.new(b:cwd).reopen_dirs(b:root)
endfunction

function! s:view.update() abort
  let b:entries = b:root.list()
endfunction

function! s:view.draw() abort
  let saved_view   = winsaveview()
  let target       = bufname('%')
  let current_lnum = 0

  setlocal ma noro

  call s:util.clear_buffer()
  call append(current_lnum, b:root.name)

  for [entry, depth] in b:entries
    let current_lnum += 1
    let indent        = repeat(' ', depth * &sw)
    let prefix        = entry.is_dir && len(entry.fetched_children())
          \ ? entry.is_open ? '- ' : '+ '
          \ : '  '

    call append(current_lnum, indent . prefix . entry.name)
  endfor

  call s:util.clear_trailing_empty_lines()
  call s:util.winrestview(saved_view)

  setlocal noma ro nomod
endfunction

function! s:util.entry_under_cursor() abort
  let lnum = line('.') - 2

  return lnum >? -1 ? get(get(b:entries, lnum, []), 0, 0) : 0
endfunction

function! s:util.winrestview(position) abort
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

function! s:util.clear_buffer() abort
  exe 'normal! ggdG:\<Esc>'
endfunction

function! s:util.clear_trailing_empty_lines() abort
  while empty(getline('$'))
    exe 'normal! dd:\<Esc>'
  endwhile
endfunction

function! s:entry.new(path, ...) abort
  let is_dir = isdirectory(a:path)
  let root   = get(a:, 1, fnamemodify(a:path, ':h'))
  let path   = fnamemodify(a:path, ':p')

  return extend(deepcopy(s:entry), {
        \ 'name': substitute(path, root, '', '')[1:],
        \ 'path': path,
        \ 'is_dir': is_dir,
        \ 'is_open': 0,
        \ 'new': 0
        \ })
endfunction

function! s:entry.update(properties) dict
  return extend(self, a:properties)
endfunction

function! s:entry.open(...) dict
  let options = get(a:, 1, {})

  exe get(options, 'command', 'edit') fnameescape(self.path)
endfunction

function! s:entry.toggle(...) dict
  let settings = get(a:, 1, {})

  return self.is_open ? self.collapse(settings) : self.expand(settings)
endfunction

function! s:entry.collapse(...) dict
  let settings  = get(a:, 1, {})
  let recursive = get(settings, 'shift', 0)

  call self.update({'is_open': 0})

  if self.is_dir && recursive
    for child_entry in self.fetched_children()
      call child_entry.collapse(settings)
    endfor
  endif

  return self
endfunction

function! s:entry.expand(...) dict
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

function! s:entry.children() dict
  if self.is_dir && !has_key(self, '_children')
    let root     = substitute(self.path, '/\+$', '', '')
    let children = sort(sort(map(filter(
        \ glob(root . '/*',  0, 1) + glob(root . '/.*', 0, 1),
        \ {_,  p  -> p !~# '/\.\.\?$'}),
        \ {_,  p  -> s:entry.new(p, root)}),
        \ {x1, x2 -> x1.name >? x2.name}),
        \ {x1, x2 -> x2.is_dir - x1.is_dir})

    call extend(self, {'_children': children})
  endif

  return self.fetched_children()
endfunction

function! s:entry.fetched_children() dict
  return get(self, '_children', [])
endfunction

function! s:entry.list(...) dict
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

function! s:entry.reopen_dirs(previous) dict
  let new_entries         = self.expand().children()
  let old_entries_by_path = {}

  for old_entry in a:previous.fetched_children()
    let old_entries_by_path[old_entry.path] = old_entry
  endfor

  for new_entry in new_entries
    let old_entry = get(old_entries_by_path, new_entry.path, 0)

    if type(old_entry) ==# type({})
      if new_entry.is_dir && old_entry.is_dir && old_entry.is_open
        call new_entry.reopen_dirs(old_entry)
      endif
    endif
  endfor

  return self
endfunction

function! s:vimenter() abort
  let root_target = get(argv(), 0, getcwd())
  let no_lnum     = line2byte('$') ==# -1

  if isdirectory(root_target) && no_lnum && !&insertmode && &modifiable
    call s:view.buffer({'cwd': root_target})
  endif
endfunction

if !exists(':Treevial')
  command -bang Treevial call s:view.buffer({'bang': <bang>0})
endif

augroup Treevial
  autocmd!
  autocmd VimEnter * nested call s:vimenter()
augroup END

let &cpo = s:save_cpo
unlet s:save_cpo
