if exists('g:loaded_treevial')
  finish
endif

" {{{ script setup
let g:loaded_netrw       = 1
let g:loaded_netrwPlugin = 1
let g:loaded_treevial    = 1
let s:util               = {}
let s:view               = {}
let s:entry              = {}
let s:is_nvim            = has('nvim')
let s:mark_prefix        = has('multi_byte') ? '• ' : '* '
let s:is_vim             = !s:is_nvim
let s:save_cpo           = &cpo
set cpo&vim
" }}}

" {{{ main functionality
function! treevial#open(...) abort
  let options = get(a:, 1, {})
  let entry   = s:util.lnum_to_entry(line('.'))

  if s:util.is_entry(entry)
    if entry.is_dir
      call entry.toggle(options)
      call s:view.render()
    else
      call entry.open(options)
    endif
  endif
endfunction

function! treevial#mark(...) abort
  let options = get(a:, 1, {})
  let lnum    = get(options, 'lnum', line('.'))
  let shift   = get(options, 'shift', 0)
  let entry   = s:util.lnum_to_entry(lnum)

  if s:util.is_entry(entry)
    call entry.mark()
    call entry.mark_children()

    if !entry.is_marked
      call entry.mark_parents()
    endif

    call cursor(lnum + (shift ? -1 : 1), 1)
    call s:view.render()
  endif
endfunction

function! treevial#unmark_all() abort
  let rerender = 0

  for [entry, _] in b:entries
    let rerender = rerender || entry.is_marked
    call entry.mark(0)
    call entry.mark_children()
  endfor

  if rerender
    call s:view.render()
  endif
endfunction

" this 159 line beast will need a refactor
" some things to improve still:
" - do not assume destination is in a directory
" - less janky logic for marked_paths
function! treevial#move() abort
  let marked = b:root.list_actionable_marked()

  if empty(marked)
    let entry  = s:util.lnum_to_entry(line('.'))
    let marked = s:util.is_entry(entry) ? [entry] : []
  endif

  let destination  = input('destination: ', b:root.path, 'dir')
  let marked_paths = map(copy(marked), 'v:val.path')
  let dest_dir_idx = index(marked_paths, destination . '/')

  " erase remaining text by clearing the screen
  " before asking for confirmation
  mode

  if dest_dir_idx >? -1
    let entry = get(marked, dest_dir_idx, 0)
    if s:util.is_entry(entry)
      if entry.is_marked
        let choice = confirm(printf(
              \ "unable to move '%s' into itself, what would you like to do?\n",
              \ destination),
              \ "&Cancel\n&Unmark")

        if choice ==# 2
          call entry.mark(0)
          call entry.mark_children()

          call filter(marked, 'v:val.is_marked')
          call s:view.render()
        else
          " NOTE: early return!
          return
        endif
      else
        call confirm(printf(
              \ "unable to move '%s' into itself\n",
              \ entry.path))

        " NOTE: early return!
        return
      endif
    else
      call confirm(printf(
            \ "%s\n\n%s\n",
            \ 'aborting because this is probably a bug',
            \ 'please open an issue on: https://github.com/sidofc/treevial/issues'))

      " NOTE: early return!
      return
    endif
  endif

  let duplicates = s:util.duplicate_filenames(marked)

  if !empty(duplicates)
    let msg = "the following files / directories have identical names and will not be moved!\n\n"

    for [filename, dupes] in duplicates
      let msg .= printf("%s\n%s\n\n",
            \ filename,
            \ join(map(copy(dupes), '"  " . v:val.path'), "\n"))
    endfor

    let msg    .= "what would you like to do?\n"
    let choice  = confirm(msg, "&Cancel\n&Unmark duplicates")

    if choice ==# 2
      for [_, dupes] in duplicates
        for dupe in dupes[1:]
          call dupe.mark(0)
          call dupe.mark_children()
        endfor
      endfor

      call filter(marked, 'v:val.is_marked')
      call s:view.render()
    else
      " NOTE: early return!
      return
    endif
  endif

  let dest_filenames = map(s:entry.new(destination).children(), 'v:val.filename')
  let found_in_dest  = filter(
        \ copy(marked),
        \ {_, entry -> index(dest_filenames, entry.filename) >? -1})

  if !empty(found_in_dest)
    if len(marked) ==# 1 && !marked[0].is_marked
      let choice = confirm(printf(
            \ "destination %s/%s already exists, overwrite?\n",
            \ destination,
            \ marked[0].filename),
            \ "&Cancel\n&Overwrite")

      if choice ==# 2
        mode
      else
        " NOTE: early return!
        return
      endif
    else
      let choice = confirm(printf(
            \ "%s\nalready exist in: %s, what would you like to do?\n",
            \ s:util.to_message_parts(found_in_dest),
            \ destination),
            \ "&Cancel\n&Unmark existing\n&Overwrite existing")

      if choice ==# 2
        for existing in found_in_dest
          call existing.mark(0)
          call existing.mark_children()
        endfor

        call filter(marked, 'v:val.is_marked')
        call s:view.render()
      elseif choice ==# 3
        mode
      else
        " NOTE: early return
        return
      endif
    endif
  endif

  if empty(marked)
    return
  endif

  let choice = confirm(printf(
        \ "%s\nwill be moved into: %s, continue?\n",
        \ s:util.to_message_parts(marked),
        \ destination),
        \ "&No\n&Yes")

  if choice ==# 2
    let failed = s:util.move_all(marked, destination)

    if len(failed)
      call confirm(printf(
            \ "%s\ncould not be moved and will remain marked!\n",
            \ s:util.to_message_parts(failed)))
    endif

    call b:root.sync()
    call s:view.render()
  endif
endfunction

function! treevial#unlink() abort
  let marked = b:root.list_actionable_marked()

  if empty(marked)
    let entry  = s:util.lnum_to_entry(line('.'))
    let marked = s:util.is_entry(entry) ? [entry] : []
  endif

  let choice = confirm(printf(
        \ "%s\nwill be deleted, continue?\n",
        \ s:util.to_message_parts(marked)),
        \ "&No\n&Yes")

  " close confirm prompt before showing other
  " potential echo's
  redraw

  if choice ==# 2
    let failed = s:util.delete_all(marked)

    if len(failed)
      call confirm(printf(
            \ "%s\ncould not be removed and will remain marked!\n",
            \ s:util.to_message_parts(failed)))
    endif

    call b:root.sync()
    call s:view.render()
  endif
endfunction
" }}}

" {{{ s:view helpers
function! s:view.buffer(...) abort
  noautocmd edit treevial
  setfiletype treevial

  let options   = get(a:,      1,         {})
  let sync      = get(options, 'bang',    !exists('b:entries'))
  let b:cwd     = get(options, 'cwd',     getcwd())
  let b:entries = get(b:,      'entries', [])
  let b:root    = get(b:,      'root',    s:entry.new(b:cwd).expand())

  setlocal noru nonu nornu noma nomod ro noswf nospell
  setlocal bufhidden=hide
  setlocal buftype=nowrite
  setlocal laststatus=0
  setlocal shiftwidth=2
  setlocal signcolumn=no

  augroup TreevialBuffer
    autocmd!
    autocmd BufEnter,FocusGained <buffer>
          \ call b:root.sync() |
          \ call s:view.render()
    autocmd CursorMoved <buffer>
          \ call s:util.keep_cursor_below_root()
  augroup END

  nnoremap <silent><buffer> v       <Nop>
  nnoremap <silent><buffer> V       <Nop>
  nnoremap <silent><buffer> <Cr>    :call treevial#open()<Cr>
  nnoremap <silent><buffer> <C-v>   :call treevial#open({'command': 'vspl'})<Cr>
  nnoremap <silent><buffer> <C-x>   :call treevial#open({'command': 'spl'})<Cr>
  nnoremap <silent><buffer> <Tab>   :call treevial#mark()<Cr>
  nnoremap <silent><buffer> <S-Tab> :call treevial#mark({'shift': 1})<Cr>
  nnoremap <silent><buffer> U       :call treevial#unmark_all()<Cr>
  nnoremap <silent><buffer> D       :call treevial#unlink()<Cr>
  nnoremap <silent><buffer> M       :call treevial#move()<Cr>

  if s:is_nvim
    nnoremap <silent><buffer> <S-Cr> :call treevial#open({'shift': 1})<Cr>
  endif

  if sync
    call b:root.sync()
  endif

  call s:view.render()
endfunction

function! s:view.render() abort
  let b:entries    = b:root.list()
  let saved_view   = winsaveview()
  let target       = bufname('%')
  let current_lnum = 0
  let mark_prefix  = b:root.has_marked_entries() ? s:mark_prefix : '  '

  setlocal ma noro

  call s:util.clear_buffer()
  call clearmatches()
  call append(current_lnum, b:root.name)

  for [entry, depth] in b:entries
    let current_lnum += 1
    let indent_ws     = depth * 2
    let indent        = repeat(' ', indent_ws)
    let prefix        = len(entry.fetched_children())
          \ ? entry.is_open ? '- ' : '+ ' : mark_prefix

    if entry.is_marked
      call matchaddpos('TreevialSelectedMark', [[current_lnum + 1, indent_ws + 1]])
    elseif entry.has_marked_entries()
      call matchaddpos('TreevialPartialMark',  [[current_lnum + 1, indent_ws + 1]])
    endif

    call append(current_lnum, indent . prefix . entry.name)
  endfor

  call s:util.clear_trailing_empty_lines()
  call s:util.winrestview(saved_view)

  setlocal noma ro nomod
  redraw!
endfunction
" }}}

" {{{ s:util helpers
function! s:util.pluralize(word, count) abort
  return a:word =~? 'y$'
        \ ? a:count ==# 1 ? a:word : substitute(a:word, 'y$', 'ies', 'i')
        \ : a:count ==# 1 ? a:word : a:word . 's'
endfunction

function! s:util.lnum_to_entry(lnum) abort
  return a:lnum >? 1 ? get(get(b:entries, a:lnum - 2, []), 0, 0) : 0
endfunction

function! s:util.keep_cursor_below_root() abort
  if line('.') <=? 1
    call cursor(2, col('.'))
  endif
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
  call deletebufline('%', 1, line('$')) | echo ''
endfunction

function! s:util.clear_trailing_empty_lines() abort
  while empty(getline('$'))
    call deletebufline('%', line('$'))
  endwhile | echo ''
endfunction

function! s:util.is_entry(entry) abort
  return type(a:entry) ==# type({})
endfunction
" }}}

" {{{ s:entry model + helpers
function! s:entry.new(path, ...) abort
  let is_dir = isdirectory(a:path)
  let root   = get(a:, 1, fnamemodify(a:path, ':h'))
  let path   = fnamemodify(a:path, ':p')

  return extend(deepcopy(s:entry), {
        \ 'name': substitute(path, root, '', '')[1:],
        \ 'filename': get(split(path, '/'), -1, ''),
        \ 'path': path,
        \ 'is_dir': is_dir,
        \ 'is_open': 0,
        \ 'is_marked': 0,
        \ 'new': 0
        \ })
endfunction

function! s:entry.update(properties) abort dict
  return extend(self, a:properties)
endfunction

function! s:entry.open(...) abort dict
  let options = get(a:, 1, {})

  exe get(options, 'command', 'edit') fnameescape(self.path)
endfunction

function! s:entry.toggle(...) abort dict
  let options = get(a:, 1, {})

  return self.is_open ? self.collapse(options) : self.expand(options)
endfunction

function s:entry.mark(...) abort dict
  return self.update({'is_marked': get(a:, 1, !self.is_marked)})
endfunction

function! s:entry.mark_children() abort dict
  for child_entry in self.fetched_children()
    call child_entry.update({'is_marked': self.is_marked}).mark_children()
  endfor

  return self
endfunction

function! s:entry.mark_parents() abort dict
  let parent = self.parent()

  if s:util.is_entry(parent)
    let unmarked_count = len(filter(
          \ copy(parent.fetched_children()),
          \ '!v:val.is_marked'))

    call parent.update({'is_marked': unmarked_count ==# 0})
    call parent.mark_parents()
  endif

  return self
endfunction

function! s:entry.collapse(...) abort dict
  let options   = get(a:, 1, {})
  let recursive = get(options, 'shift', 0)

  call self.update({'is_open': 0})

  if recursive
    for child_entry in self.fetched_children()
      call child_entry.collapse(options)
    endfor
  endif

  return self
endfunction

function! s:entry.expand(...) abort dict
  call self.update({'is_open': self.is_dir})

  for child_entry in self.children()
    let result_entry = child_entry

    while len(result_entry.children()) ==# 1
      let result_entry = result_entry.children()[0]
    endwhile

    if child_entry.path !=# result_entry.path
      call child_entry.update({
            \ 'name': substitute(result_entry.path, self.path, '', ''),
            \ 'filename': result_entry.filename,
            \ 'path': result_entry.path,
            \ 'is_dir': result_entry.is_dir,
            \ '_children': []
            \ })
    endif
  endfor

  return self
endfunction

function! s:entry.children() abort dict
  if self.is_dir && !has_key(self, '_children')
    let root     = substitute(self.path, '/\+$', '', '')
    let children = sort(sort(map(filter(
        \ glob(root . '/*',  0, 1) + glob(root . '/.*', 0, 1),
        \ {_,  p  -> p !~# '/\.\.\?$'}),
        \ {_,  p  -> s:entry.new(p, root)}),
        \ {x1, x2 -> x1.name >? x2.name}),
        \ {x1, x2 -> x2.is_dir - x1.is_dir})

    call extend(self, {'_children': map(
          \ children,
          \ {_, entry -> entry.update({
          \   '_parent': self,
          \   'is_marked': self.is_marked
          \ })
          \ })})
  endif

  return self.fetched_children()
endfunction

function! s:entry.parent() abort dict
  return get(self, '_parent', 0)
endfunction

function! s:entry.fetched_children() abort dict
  return get(self, '_children', [])
endfunction

function! s:entry.list(...) abort dict
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

function! s:entry.sync() abort dict
  let dir_offset = self.is_dir ? -2 : -1
  return self.update(s:entry.new(self.path[:dir_offset]).synchronize_with(self))
endfunction

function! s:entry.synchronize_with(previous) abort dict
  let new_entries         = self.expand().children()
  let old_entries_by_path = {}

  for old_entry in a:previous.fetched_children()
    let old_entries_by_path[old_entry.path] = old_entry
  endfor

  for new_entry in new_entries
    let old_entry = get(old_entries_by_path, new_entry.path, 0)

    if s:util.is_entry(old_entry)
      call new_entry.update({'is_marked': old_entry.is_marked})
      if new_entry.is_dir && old_entry.is_dir && old_entry.is_open
        call new_entry.synchronize_with(old_entry)
      endif
    endif
  endfor

  return self
endfunction

function! s:entry.list_actionable_marked() abort dict
  let marked = []

  for child_entry in self.fetched_children()
    if child_entry.is_marked
      call add(marked, child_entry)
    else
      call extend(marked, child_entry.list_actionable_marked())
    endif
  endfor

  return marked
endfunction

function! s:entry.has_marked_entries() abort dict
  for child_entry in self.fetched_children()
    if child_entry.is_marked || child_entry.has_marked_entries()
      return 1
    endif
  endfor

  return 0
endfunction

function! s:util.split_files_and_dirs(entries)
  let files = []
  let dirs  = []

  for entry in a:entries
    call add(entry.is_dir ? dirs : files, entry)
  endfor

  return [files, dirs]
endfunction

function! s:util.to_message_parts(entries, ...) abort
  let [files, dirs] = s:util.split_files_and_dirs(a:entries)
  let files_len     = len(files)
  let dirs_len      = len(dirs)
  let message       = ''

  if files_len
    let message .= printf(
          \ "%d %s:\n%s\n",
          \ files_len,
          \ s:util.pluralize('file', files_len),
          \ join(map(copy(files), '"  " . v:val.path'), "\n"))
  endif

  let message .= files_len && dirs_len ? "\nand " : ""

  if dirs_len
    let message .= printf(
          \ "%d %s:\n%s\n",
          \ dirs_len,
          \ s:util.pluralize('directory', dirs_len),
          \ join(map(copy(dirs), '"  " . v:val.path'), "\n"))
  endif

  return message
endfunction

function! s:util.dirs_to_create(dirpath) abort
  let existing_dir_path = '/'

  for dirname in split(a:dirpath, '/')
    let tmp_dir_path = existing_dir_path . dirname . '/'

    if isdirectory(tmp_dir_path)
      let existing_dir_path = tmp_dir_path
    else
      break
    endif
  endfor

  let path_to_create = substitute(a:dirpath, existing_dir_path[:-2], '', '')

  return [
        \ get(split(path_to_create, '/'), 0, ''),
        \ existing_dir_path[:-2]]
endfunction

function! s:util.duplicate_filenames(entries) abort
  let duplicates = []
  let filenames  = uniq(sort(map(copy(a:entries), 'v:val.filename')))

  if len(filenames) < len(a:entries)
    for filename in filenames
      let same_named = filter(
            \ copy(a:entries),
            \ {_, entry -> entry.filename == filename})

      if len(same_named) >? 1
        call add(duplicates, [filename, same_named])
      endif
    endfor
  endif

  return duplicates
endfunction

function! s:util.move_all(entries, destination) abort
  let failed_entries    = []
  let destination       = substitute(a:destination, '\/\+$', '', '')
  let [create, base] = s:util.dirs_to_create(destination)

  if !empty(create)
    let create_root = base . (base ==# '/' ? '' : '/') . create
    call mkdir(create_root, 'p')

    " unable to create destination directory, e.g. failed
    " to move all files.
    if !isdirectory(create_root)
      return a:entries
    endif
  endif

  for entry in a:entries
    try
      if rename(entry.path, destination . '/' . entry.filename) !=# 0
        throw 1
      endif
    catch
      call add(failed_entries, entry)
    endtry
  endfor

  return failed_entries
endfunction

function! s:util.delete_all(entries) abort
  let failed_entries = []

  for entry in a:entries
    try
      if delete(entry.path, entry.is_dir ? 'rf' : '') ==# -1
        throw 1
      endif
    catch
      call add(failed_entries, entry)
    endtry
  endfor

  return failed_entries
endfunction
" }}}

" {{{ activation on startup + create Tree[vial][!] command
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
" }}}

" {{{ script teardown
let &cpo = s:save_cpo
unlet s:save_cpo
" }}}
