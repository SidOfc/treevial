function! treevial#open(cwd) abort
  let s:cwd      = a:cwd
  let s:tree     = get(s:, 'data', s:make_tree(s:cwd))
  let s:defaults = {
        \ 'close_children': 0
        \ }

  enew
  file treevial

  silent! setlocal
        \ bufhidden=hide
        \ noruler
        \ shiftwidth=2
        \ nonumber
        \ norelativenumber
        \ nospell
        \ noswapfile
        \ signcolumn=no
        \ filetype=treevial

  call treevial#draw()

  noremap <silent><buffer> <S-Cr>
        \ :call treevial#navigate({'close_children': 1})<Cr>
  noremap <silent><buffer> <Cr>   :call treevial#navigate()<Cr>
endfunction

function! treevial#draw() abort
  let saved_view = winsaveview()
  let entries    = map(
        \ deepcopy(s:convert_tree_to_list(s:tree)),
        \ '[v:val, v:key + 1]')

  setlocal modifiable
  silent! normal! ggdG

  call append(0, fnamemodify(s:cwd, ':t') . '/')

  for [branch, idx] in entries
    let indent = repeat(' ', branch.depth * &sw)
    let prefix = branch.is_dir
          \ ? branch.is_open ? '- ' : '+ '
          \ : '  '

    call append(idx, indent . prefix . branch.name)
  endfor

  silent! normal! "_ddgg
  call winrestview(saved_view)
  setlocal nomodified nomodifiable
endfunction

function! treevial#entry_under_cursor() abort
  let cursor_line_index = line('.') - 2

  return cursor_line_index >? -1
        \ ? get(s:convert_tree_to_list(s:tree), cursor_line_index, {})
        \ : {}
endfunction

function! treevial#navigate(...) abort
  let options = extend(deepcopy(s:defaults), get(a:, 1, {}))
  let entry   = treevial#entry_under_cursor()

  if has_key(entry, 'name')
    echom 'navigate:' entry.path
    call entry.update({'is_open': entry.is_dir && !entry.is_open})

    if entry.is_open && len(entry.children) ==# 0
      call entry.update({'children': s:make_tree(entry.path, entry.depth + 1)})
    endif

    if entry.is_dir && !entry.is_open && options.close_children
      call entry.update_children({'is_open': 0})
    endif

    call treevial#draw()
  endif
endfunction

function! s:convert_tree_to_list(tree) abort
  let result = []

  for entry in a:tree
    call add(result, entry)
    if entry.is_open
      call extend(result, s:convert_tree_to_list(entry.children))
    endif
  endfor

  let b:current_list = result
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
        \ 'is_open': 0,
        \ 'children': []
        \ }

  " echom 'creating entry:' entry.depth entry.name

  " this code enables git single-file-in-folder like
  " expansion as seem on github, needs work...
  " ---
  " while len(entry.children) ==# 1
  "   let entry = entry.children[0]
  "   if entry.is_dir && len(entry.children) ==# 0
  "     call entry.update({'children': s:make_tree(entry.path, 1, 0)})
  "   endif
  " endwhile

  return extend(entry, {
        \ 'update': function('extend', [entry]),
        \ 'update_children': function('s:update_children', entry)})
endfunction

function! s:update_children(props, ...) dict
  let recursive = get(a:, 1, 1)

  for child_entry in self.children
    call child_entry.update(a:props)
    if recursive
      call child_entry.update_children(a:props)
    endif
  endfor
endfunction

function! s:root() abort
  let root_target = get(argv(), 0, getcwd())
  let no_lnum     = line2byte('$') ==# -1

  if isdirectory(root_target) && no_lnum && !&insertmode && &modifiable
    call treevial#open(root_target)
  endif
endfunction

if has('vim_starting')
  augroup treevial
    autocmd!
    autocmd VimEnter * nested call s:root()
  augroup END
endif
