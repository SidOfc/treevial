if exists('g:loaded_treevial')
  finish
endif

let g:loaded_treevial = 1
let s:save_cpo        = &cpo
let s:is_nvim         = has('nvim')
let s:is_vim          = !s:is_nvim
set cpo&vim

function! treevial#root() abort
  let root_target = get(argv(), 0, getcwd())
  let no_lnum     = line2byte('$') ==# -1

  if isdirectory(root_target) && no_lnum && !&insertmode && &modifiable
    call treevial#open(root_target)
  endif
endfunction

function! treevial#open(cwd) abort
  let s:cwd  = a:cwd
  let s:root = get(s:, 'root', s:tree_entry(s:cwd, fnamemodify(s:cwd, ':h'), -1))

  enew
  file treevial

  silent! setlocal
        \ filetype=treevial
        \ bufhidden=hide
        \ nobuflisted
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

  call s:root.open()
  call treevial#draw()

  noremap <silent><buffer> <S-Cr>
        \ :call treevial#navigate({'shift': 1})<Cr>
  noremap <silent><buffer> <Cr>   :call treevial#navigate()<Cr>
endfunction

function! treevial#draw() abort
  let saved_view = winsaveview()
  let entries    = map(
        \ deepcopy(s:convert_tree_to_list(s:root.children())),
        \ '[v:val, v:key + 1]')

  setlocal modifiable noreadonly
  silent! normal! ggdG

  if s:is_vim | echo '' | endif

  call append(0, fnamemodify(s:cwd, ':t') . '/')

  for [entry, idx] in entries
    let indent = repeat(' ', entry.depth * &sw)
    let prefix = entry.is_dir
          \ ? entry.is_open ? '- ' : '+ '
          \ : '  '

    call append(idx, indent . prefix . entry.name)
  endfor

  silent! normal! "_ddgg

  if s:is_vim | echo '' | endif

  call winrestview(saved_view)
  setlocal nomodified nomodifiable readonly
endfunction

function! treevial#entry_under_cursor() abort
  let cursor_line_index = line('.') - 2

  return cursor_line_index >? -1
        \ ? get(s:convert_tree_to_list(s:root.children()), cursor_line_index, 0)
        \ : 0
endfunction

function! treevial#navigate(...) abort
  let settings = get(a:, 1, {})
  let entry    = treevial#entry_under_cursor()

  if type(entry) ==# type({})
    call entry.toggle({'recursive': get(settings, 'shift', 0)})
    call treevial#draw()
  endif
endfunction

function! s:convert_tree_to_list(tree) abort
  let result = []

  for entry in a:tree
    call add(result, entry)
    if entry.is_open
      call extend(result, s:convert_tree_to_list(entry.children()))
    endif
  endfor

  return result
endfunction

function! s:make_tree(root, ...) abort
  let depth = get(a:, 1, 0)
  let root  = substitute(a:root, '/\+$', '', '')

  return sort(sort(map(filter(
        \ glob(root . '/*',  0, 1) +
        \ glob(root . '/.*', 0, 1),
        \ {_,  p  -> p !~# '/\.\.\?$'}),
        \ {_,  p  -> s:tree_entry(p, root, depth)}),
        \ {x1, x2 -> x1.name >? x2.name}),
        \ {x1, x2 -> x2.is_dir - x1.is_dir})
endfunction

function! s:tree_entry(path, root, depth) abort
  let is_dir = isdirectory(a:path)
  let path   = fnamemodify(a:path, ':p')
  let entry  = {
        \ 'name': substitute(path, a:root, '', '')[1:],
        \ 'path': path,
        \ 'depth': a:depth,
        \ 'is_dir': is_dir,
        \ 'is_open': 0
        \ }

  call extend(entry, {
        \ 'update': function('extend', [entry]),
        \ 'open': function('s:entry_open', entry),
        \ 'close': function('s:entry_close', entry),
        \ 'toggle': function('s:entry_toggle', entry),
        \ 'children': function('s:entry_children', entry)
        \ })

  return entry
endfunction

function! s:entry_toggle(...) dict
  let settings  = get(a:, 1, {})
  return self.is_open ? self.close(settings) : self.open(settings)
endfunction

function! s:entry_close(...) dict
  let settings  = get(a:, 1, {})
  let recursive = get(settings, 'recursive', 0)

  call self.update({'is_open': 0})

  if recursive && has_key(self, '_children')
    for child_entry in self.children()
      call child_entry.close(settings)
    endfor
  endif
endfunction

function! s:entry_open(...) dict
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
endfunction

function! s:entry_children() dict
  if self.is_dir && !has_key(self, '_children')
    call extend(self, {'_children': s:make_tree(self.path, self.depth + 1)})
  endif

  return get(self, '_children', [])
endfunction

if has('vim_starting')
  augroup treevial
    autocmd!
    autocmd VimEnter * nested call treevial#root()
  augroup END
endif

let &cpo = s:save_cpo
unlet s:save_cpo
