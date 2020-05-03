if exists('g:loaded_treevial') || !has('lambda')
  finish
endif

" {{{ script setup
let g:loaded_netrw       = 1
let g:loaded_netrwPlugin = 1
let g:loaded_treevial    = 1
let s:util               = {}
let s:test               = {}
let s:io                 = {}
let s:view               = {}
let s:entry              = {}
let s:mark_prefix        = has('multi_byte') ? '• ' : '* '
let s:is_nvim            = has('nvim')
let s:is_vim             = !s:is_nvim
let s:fn_type            = type(function('getline'))
let s:save_cpo           = &cpo
set cpo&vim
" }}}

" {{{ startup configuration settings
let s:settings = {
      \ 'default_mappings': get(g:, 'treevial_default_mappings', v:version >=? 703)
      \ }
" }}}

" {{{ main functionality
function! treevial#open(...) abort
  let options = get(a:, 1, {})
  let entry   = s:util.lnum_to_entry(line('.'))

  if s:util.is_entry(entry)
    if entry.is_dir && get(options, 'dirs', 1)
      call entry.toggle(options)
      call s:view.render()
    elseif get(options, 'files', 1)
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
  for [entry, _] in b:entries
    call entry.mark(0)
    call entry.mark_children()
  endfor

  call s:view.render()
endfunction

function! treevial#create() abort
  let destination = input('create: ', b:root.path, 'dir')
  let dest_is_dir = destination =~? '\/$'
  let dest_exists = filereadable(destination) || isdirectory(destination)

  if dest_exists
    return s:util.confirm(destination . ' already exists')
  elseif empty(destination)
    return
  endif

  if dest_is_dir
    if !s:io.mkdirp(destination) | return | endif
  else
    if !s:io.mkfile(destination) | return | endif
  endif

  call b:root.sync()
  call s:view.render()
endfunction

function! treevial#move() abort
  let selection = b:root.list_actionable()

  if len(selection) <? 2
    let entry = get(selection, 0, s:util.lnum_to_entry(line('.')))

    if s:util.is_entry(entry)
      call s:io.handle_move_single_entry(entry)
    endif
  else
    return s:io.handle_move_multiple_entries(selection)
  endif
endfunction

function! treevial#destroy() abort
  let selection = b:root.list_actionable()

  if empty(selection)
    let entry = s:util.lnum_to_entry(line('.'))

    if s:util.is_entry(entry)
      let selection = [entry]
    endif
  endif

  if !empty(selection)
    let choice = s:util.confirm({
          \ 'entries': selection,
          \ 'message': 'will be deleted, continue?',
          \ 'choices': "&No\n&Yes"
          \ })

    if choice ==# 2
      call s:io.delete_all(selection)
      call b:root.sync()
      call s:view.render()
    endif
  endif
endfunction
" }}}

" {{{ s:view helpers
function! s:view.buffer(...) abort
  if bufexists('treevial')
    buffer treevial
    return
  endif

  noautocmd edit treevial
  setfiletype treevial

  let options   = get(a:, 1, {})
  let b:entries = []
  let b:root    = s:entry.new(get(options, 'cwd', getcwd()))

  setlocal noru nonu nornu noma nomod ro noswf nospell
  setlocal bufhidden=hide buftype=nowrite buftype=nofile

  call b:root.sync()
  call s:view.mappings()
  call s:view.render()
endfunction

function! s:view.mappings() abort
  if s:settings.default_mappings
    nnoremap <silent><nowait><buffer> <Cr>    :call treevial#open()<Cr>
    nnoremap <silent><nowait><buffer> <C-v>   :call treevial#open({'command': 'vspl', 'dirs': 0})<Cr>
    nnoremap <silent><nowait><buffer> <C-x>   :call treevial#open({'command': 'spl',  'dirs': 0})<Cr>
    nnoremap <silent><nowait><buffer> <Tab>   :call treevial#mark()<Cr>
    nnoremap <silent><nowait><buffer> <S-Tab> :call treevial#mark({'shift': 1})<Cr>
    nnoremap <silent><nowait><buffer> u       :call treevial#unmark_all()<Cr>
    nnoremap <silent><nowait><buffer> d       :call treevial#destroy()<Cr>
    nnoremap <silent><nowait><buffer> m       :call treevial#move()<Cr>
    nnoremap <silent><nowait><buffer> c       :call treevial#create()<Cr>

    if s:is_nvim
      nnoremap <silent><nowait><buffer> <S-Cr> :call treevial#open({'shift': 1})<Cr>
    endif
  endif

  if exists('#User#TreevialMappings')
    doautocmd User TreevialMappings
  endif
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
    let check_links   = 0
    let current_lnum += 1
    let indent_mult   = depth * 2
    let indent        = repeat(' ', indent_mult)
    let fname_len     = len(entry.filename)
    let prefix        = len(entry.fetched_children())
          \ ? entry.is_open ? '- ' : '+ ' : mark_prefix
    let line          = indent . prefix . entry.name

    call append(current_lnum, line)

    for link in entry.symlinks
      if link >? 0
        let check_links = 1
        break
      endif
    endfor

    if check_links
      let parts            = split(substitute(entry.name, '\/\+$', '', ''), '/')
      let column           = len(line)
      let initial_offset   = entry.is_dir
      let positions        = []
      let broken_positions = []

      for idx in reverse(range(0, len(parts) - 1))
        let symlink_status = get(entry.symlinks, idx)
        if symlink_status
          let part        = get(parts, idx, '')
          let part_len    = len(part)
          let column     -= part_len + initial_offset
          let add_target  = symlink_status ==# 2 ? broken_positions : positions

          call add(add_target, [current_lnum + 1, column + 1, part_len])

          let column         -= 1
          let initial_offset  = 0
        endif

        let pos_len        = len(positions)
        let broken_pos_len = len(broken_positions)

        if idx ==# 0 && pos_len >? 0 || pos_len ==# 8
          call s:util.each_view({-> matchaddpos(
                \ 'TreevialSymlink', positions)})
          let positions = []
        endif

        if idx ==# 0 && broken_pos_len >? 0 || broken_pos_len ==# 8
          call s:util.each_view({-> matchaddpos(
                \ 'TreevialBrokenSymlink', broken_positions)})
          let broken_positions = []
        endif
      endfor
    endif

    if entry.is_exe
      call s:util.each_view({-> matchaddpos(
            \ 'TreevialExecutable',
            \ [[current_lnum + 1, len(line) - fname_len + 1, fname_len]])})
    endif

    if entry.is_marked
      call s:util.each_view({-> matchaddpos(
            \ 'TreevialSelectedMark', [[current_lnum + 1, indent_mult + 1]])})
    elseif entry.has_marked_entries()
      call s:util.each_view({-> matchaddpos(
            \ 'TreevialPartialMark', [[current_lnum + 1, indent_mult + 1]])})
    endif
  endfor

  call s:util.clear_trailing_empty_lines()
  call s:util.winrestview(saved_view)

  setlocal noma ro nomod
  mode
endfunction
" }}}

" {{{ s:entry model + helpers
function! s:entry.new(path, ...) abort
  let is_dir   = isdirectory(a:path)
  let root     = get(a:, 1, fnamemodify(a:path, ':h'))
  let path     = fnamemodify(a:path, ':p')
  let resolved = resolve(a:path)
  let modified = getftime(resolved)
  let is_ln    = a:path !=? resolved

  return extend(deepcopy(s:entry), {
        \ 'name': substitute(path, root, '', '')[1:],
        \ 'filename': fnamemodify(a:path, ':t'),
        \ 'modified': modified,
        \ 'path': path,
        \ 'is_symlink': is_ln ? (modified ==# -1 ? 2 : 1) : 0,
        \ 'is_dir': is_dir,
        \ 'is_exe': executable(path),
        \ 'is_open': 0,
        \ 'is_marked': 0,
        \ 'new': 0,
        \ 'symlinks': []
        \ })
endfunction

function! s:entry.merge(other) abort dict
  return extend(self, filter(copy(a:other), {_, v -> type(v) !=# s:fn_type}))
endfunction

function! s:entry.open(...) abort dict
  let options = get(a:, 1, {})

  exe get(options, 'command', 'edit') fnameescape(self.path)
  call clearmatches()
endfunction

function! s:entry.toggle(...) abort dict
  let options = get(a:, 1, {})

  return self.is_open ? self.collapse(options) : self.expand(options)
endfunction

function s:entry.mark(...) abort dict
  return self.merge({'is_marked': get(a:, 1, !self.is_marked)})
endfunction

function! s:entry.mark_children() abort dict
  for child_entry in self.fetched_children()
    call child_entry.merge({'is_marked': self.is_marked}).mark_children()
  endfor

  return self
endfunction

function! s:entry.mark_parents() abort dict
  let parent = self.parent()

  if s:util.is_entry(parent)
    let unmarked_count = len(filter(
          \ copy(parent.fetched_children()),
          \ '!v:val.is_marked'))

    call parent.merge({'is_marked': unmarked_count ==# 0})
    call parent.mark_parents()
  endif

  return self
endfunction

function! s:entry.collapse(...) abort dict
  let options   = get(a:, 1, {})
  let recursive = get(options, 'shift', 0)

  call self.merge({'is_open': 0})

  if recursive
    for child_entry in self.fetched_children()
      call child_entry.collapse(options)
    endfor
  endif

  return self
endfunction

function! s:entry.expand(...) abort dict
  if !has_key(self, '_expanded')
    for child_entry in self.children()
      let result_entry = child_entry
      let symlinks     = [result_entry.is_symlink]

      while len(result_entry.children()) ==# 1
        let result_entry = result_entry.children()[0]
        call add(symlinks, result_entry.is_symlink)
      endwhile

      if child_entry.path !=# result_entry.path
        call child_entry.merge(result_entry)
              \.merge({'name': substitute(result_entry.path, self.path, '', '')})
      endif
      call child_entry.merge({'symlinks': symlinks})
    endfor
  endif

  call self.merge({'is_open': self.is_dir, '_expanded': 1})
  return self
endfunction

function! s:entry.children() abort dict
  if self.is_dir && !has_key(self, '_children')
    let root     = substitute(self.path, '/\+$', '', '')
    let children = sort(sort(map(filter(
        \ glob(root . '/*',  0, 1, 1) + glob(root . '/.*', 0, 1, 1),
        \ {_,  p  -> p !~# '/\.\.\?$'}),
        \ {_,  p  -> s:entry.new(p, root)}),
        \ s:util.compare_filename),
        \ {x1, x2 -> x2.is_dir - x1.is_dir})

    call extend(self, {'_children': map(
          \ children,
          \ {_, entry -> entry.merge({
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
  return self.merge(s:entry.new(self.path[:dir_offset]).synchronize_with(self))
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
      call new_entry.merge({'is_marked': old_entry.is_marked})
      if new_entry.modified ==# old_entry.modified
        call new_entry.merge(old_entry)
      elseif new_entry.is_dir && old_entry.is_dir && old_entry.is_open
        call new_entry.synchronize_with(old_entry)
      endif
    endif
  endfor

  return self
endfunction

function! s:entry.list_actionable() abort dict
  let marked = []

  for child_entry in self.fetched_children()
    if child_entry.is_marked
      call add(marked, child_entry)
    else
      call extend(marked, child_entry.list_actionable())
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
" }}}

" {{{ s:util helpers
function! s:util.lnum_to_entry(lnum) abort
  return a:lnum >? 1 ? get(get(b:entries, a:lnum - 2, []), 0, 0) : 0
endfunction

function! s:util.keep_cursor_below_root() abort
  if line('.') <=? 1
    call cursor(2, col('.'))
  endif
endfunction

function! s:util.each_view(func) abort
  let curr_winnr = winnr()
  let windows = filter(map(
        \ win_findbuf(bufnr('%')),
        \ 'win_id2win(v:val)'),
        \ 'v:val !=# ' . curr_winnr)

  for winnr in windows
    exe winnr . 'wincmd w'
    call call(a:func, [winnr])
  endfor

  exe curr_winnr . 'wincmd w'
  call call(a:func, [curr_winnr])
endfunction

function! s:util.winrestview(position) abort
  call s:util.each_view({-> winrestview(a:position)})
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

function! s:util.confirm(overrides) abort
  if s:test.vader_confirmed()
    return s:test.vader_confirm_answer()
  endif

  let overrides = type(a:overrides) ==# type('') ? {'message': a:overrides} : a:overrides
  let options   = extend(
        \ deepcopy({'choices': '&Ok', 'entries': [], 'default': 1, 'message': 'Confirm'}),
        \ overrides)

  let choice = empty(options.entries)
        \ ? confirm(printf("%s\n", options.message), options.choices, options.default)
        \ : confirm(printf(
        \   "%s%s\n",
        \   s:util.categorized_entries_message(options.entries),
        \   options.message),
        \   options.choices,
        \   options.default)

  redraw!

  return choice
endfunction

function! s:util.categorized_entries_message(entries) abort
  let message    = ''
  let own_cats   = type(get(a:entries, 0, {})) == type([])
  let categories = own_cats
        \ ? a:entries
        \ : s:util.split_files_and_dirs(a:entries)

  for [category, category_entries] in categories
    let entries_length = len(category_entries)

    if entries_length
      let joined_paths  = join(map(copy(category_entries), '"  " . v:val.path'), "\n")
      let message      .= own_cats
            \ ? printf("%s:\n%s\n\n", category, joined_paths)
            \ : printf(
            \   "%d %s:\n%s\n\n",
            \   entries_length,
            \   s:util.pluralize(category, entries_length),
            \   joined_paths)
    endif
  endfor

  return message
endfunction

function! s:util.split_files_and_dirs(entries)
  let files       = []
  let directories = []

  for entry in a:entries
    call add(entry.is_dir ? directories : files, entry)
  endfor

  return [['files', files], ['directories', directories]]
endfunction

function! s:util.pluralize(word, count) abort
  let singular = substitute(a:word, 'ies$', 'y', '')
  let singular = substitute(singular, 's$', '', '')

  if a:count ==# 1
    return singular
  else
    let plural  = substitute(singular, 'y$', 'ies', '')
    let plural .= (plural =~? 's' ? '' : 's')

    return plural
  endif
endfunction

function! s:util.to_dict(listlist) abort
  let dict = {}

  for [key, value] in a:listlist
    let dict[key] = value
  endfor

  return dict
endfunction

" The s:util.compare_filename and s:util.filename_words
" functions have been shamelessly stolen from:
" https://github.com/Shougo/vimfiler.vim/blob/master/autoload/vimfiler/helper.vim
"
" Thanks Shougo!
function! s:util.compare_filename(entry1, entry2) abort
  let words_1 = s:util.filename_words(a:entry1.filename)
  let words_2 = s:util.filename_words(a:entry2.filename)
  let words_1_len = len(words_1)
  let words_2_len = len(words_2)

  for i in range(0, min([words_1_len, words_2_len])-1)
    if words_1[i] >? words_2[i]
      return 1
    elseif words_1[i] <? words_2[i]
      return -1
    endif
  endfor

  return words_1_len - words_2_len
endfunction

function! s:util.filename_words(filename) abort
  let words = []
  for part in split(a:filename, '\d\+\zs\ze')
    let words += split(part, '\D\zs\ze\d\+')
  endfor

  return map(words, "v:val =~ '^\\d\\+$' ? str2nr(v:val) : v:val")
endfunction
" }}}

" {{{ IO helpers
function! s:io.handle_move_multiple_entries(entries) abort
  let entries              = copy(a:entries)
  let entry_filenames      = uniq(sort(map(copy(entries), 'v:val.filename')))
  let entry_filename_table = s:util.to_dict(map(copy(entry_filenames), '[v:val, []]'))
  let illegal_moves        = []
  let dest_path            = expand(
        \ substitute(input('directory: ', b:root.path, 'dir'), '\/$', '', ''))

  mode

  if filereadable(dest_path)
    call s:util.confirm(dest_path . ' is a file, please choose a directory')
    return s:io.handle_move_multiple_entries(entries)
  elseif empty(dest_path)
    return
  endif

  for entry in entries
    let errors = s:io.validate_move(entry.path, dest_path . '/' . entry.filename)

    call add(entry_filename_table[entry.filename], entry)

    if errors.overwrite_parent || errors.move_into_self
      call add(illegal_moves, entry)
    endif
  endfor

  call filter(entry_filename_table, 'len(v:val) >? 1')

  if !empty(illegal_moves)
    let one = len(illegal_moves) ==# 1
    let choice = s:util.confirm({
          \ 'entries': illegal_moves,
          \ 'message': 'can not be moved because '
          \          . (one ? 'its' : 'their')
          \          . ' parent directory would be overwritten,'
          \          . ' or ' . (one ? 'it' : 'they')
          \          . ' would overwrite ' . (one ? 'itself' : 'themselves')
          \          . ', what would you like to do?',
          \ 'choices': "&Cancel\n&Unmark"
          \ })

    if choice ==# 2
      for illegal in illegal_moves
        call illegal.mark(0)
        call illegal.mark_children()
      endfor

      call filter(entries, 'v:val.is_marked')
      call s:view.render()
    endif
    return
  endif

  if !empty(entry_filename_table)
    let choice = s:util.confirm({
          \ 'entries': items(entry_filename_table),
          \ 'message': 'unable to copy multiple files with the same name,'
          \          . ' what would you like to do?',
          \ 'choices': "&Cancel\n&Unmark duplicates"
          \ })

    if choice ==# 2
      for [_, entries] in items(entry_filename_table)
        for entry in entries[1:]
          call entry.mark()
          call entry.mark_children()
        endfor
      endfor

      call filter(entries, 'v:val.is_marked')
      call s:view.render()
    else
      return
    endif
  endif

  if !isdirectory(dest_path) && !s:io.mkdirp(dest_path)
    return
  endif

  let dest_entry      = s:entry.new(dest_path)
  let dest_filenames  = map(dest_entry.children(), 'tolower(v:val.filename)')
  let would_overwrite = filter(
        \ copy(entries),
        \ {_, entry -> index(dest_filenames, tolower(entry.filename)) >? -1})

  mode

  if !empty(would_overwrite)
    let choice = s:util.confirm({
          \ 'entries': would_overwrite,
          \ 'message': 'will overwrite a file or directory in "' . dest_path . '"',
          \ 'choices': "&Cancel\n&Overwrite\n&Unmark"
          \ })

    if choice ==# 3
      for entry in would_overwrite
        entry.mark(0)
        entry.mark_children()
      endfor

      call filter(entries, 'v:val.is_marked')
    elseif choice !=? 2
      return
    endif
  endif

  for marked in entries
    call s:io.move(marked.path, dest_path . '/' . marked.filename)
  endfor

  call b:root.sync()
  call s:view.render()
endfunction

function! s:io.handle_move_single_entry(entry) abort
  let dest_path   = expand(substitute(input('destination: ', a:entry.path, 'dir'), '\/$', '', ''))
  let dest_parent = fnamemodify(dest_path, ':h')
  let entry_path  = substitute(a:entry.path, '\/$', '', '')
  let errors      = s:io.validate_move(entry_path, dest_path)

  mode

  if errors.noop
    return
  elseif errors.overwrite_parent
    return s:util.confirm('unable to overwrite parent directory')
  elseif errors.move_into_self
    return s:util.confirm('files and directories can not be moved into themselves')
  elseif errors.dest_exists
    let choice = s:util.confirm({
          \ 'message': join(['destination "' . dest_path . '" already exists,',
          \                  "what would you like to do?"], "\n\n"),
          \ 'choices': "&Cancel\n&Overwrite"
          \ })

    if choice !=? 2
      return
    endif
  elseif !isdirectory(dest_parent)
    if !s:io.mkdirp(dest_parent)
      return
    endif
  endif

  call s:io.move(entry_path, dest_path)
  call b:root.sync()
  call s:view.render()
endfunction

function! s:io.move(from, to) abort
  if rename(a:from, a:to) !=? 0
    return s:util.confirm({
          \ 'entries': [['rename', [{'path': a:from}]],
          \             ['to',     [{'path': a:to}]]],
          \ 'message': 'failed, press <ENTER> to continue'})
  endif
endfunction

function! s:io.mkdirp(path) abort
  try
    call mkdir(a:path, 'p')
  finally
    if isdirectory(a:path)
      return 1
    else
      call s:util.confirm('failed to create "' . a:path . '"')
      return 0
    endif
  endtry
endfunction

function s:io.mkfile(destination) abort
  let dest_dir = fnamemodify(a:destination, ':h')
  if isdirectory(dest_dir) || s:io.mkdirp(dest_dir)
    try
      if writefile([], a:destination, 'b') !=? 0
        throw 1
      endif
      return 1
    catch
      call s:util.confirm('failed to create file: ' . a:destination)
      return 0
    endtry
  else
    return 0
  endif
endfunction

function s:io.validate_move(from, to) abort
  let from = substitute(a:from, '\/$', '', '')
  let to   = substitute(a:to, '\/$', '', '')

  return {
        \ 'overwrite_parent': from =~? '^' . to && isdirectory(to),
        \ 'move_into_self': to =~? '^' . from . '/',
        \ 'noop': to ==? from || empty(to) || empty(from),
        \ 'dest_exists': isdirectory(to) || filereadable(to)
        \ }
endfunction

function! s:io.delete_all(entries) abort
  let failed = []

  for entry in a:entries
    try
      if delete(entry.path, entry.is_dir ? 'rf' : '') ==# -1
        throw 1
      endif
    catch
      call add(failed, entry)
    endtry
  endfor

  if len(failed) >? 0
    call s:util.confirm({
          \ 'entries': failed
          \ 'message': 'could not be removed and will remain marked!',
          \ 'choices': "&Ok"
          \ })
    return 0
  else
    return 1
  endif
endfunction
" }}}

" {{{ activation on startup + create Tree[vial][!] command
function! s:vimenter() abort
  let root_target = get(argv(), 0, getcwd())
  let no_lnum     = line2byte('$') ==# -1

  if exists('#FileExplorer')        | exe 'au! FileExplorer *'        | endif
  if exists('#NERDTreeHijackNetrw') | exe 'au! NERDTreeHijackNetrw *' | endif

  if isdirectory(root_target) && no_lnum && !&insertmode && &modifiable
    call s:view.buffer({'cwd': root_target})
  endif
endfunction

if !exists(':Treevial')
  command -bang Treevial call s:view.buffer({'bang': <bang>0})
endif

augroup Treevial
  autocmd!
  autocmd VimEnter * call s:vimenter()
  autocmd BufLeave,FocusLost treevial let b:active = 0
  autocmd BufEnter,FocusGained treevial
        \ if get(b:, 'active', 1) ==# 0 |
        \   call b:root.sync() |
        \   call s:view.render() |
        \   let b:active = 1 |
        \ endif
  autocmd CursorMoved treevial
        \ call s:util.keep_cursor_below_root()
augroup END
" }}}

" {{{ test 'helpers'
function! s:test.vader_confirmed() abort
  return get(g:, '__treevial_vader_confirm_reply__', '') != ''
endfunction

function! s:test.vader_confirm_answer() abort
  let answer = g:__treevial_vader_confirm_reply__
  unlet g:__treevial_vader_confirm_reply__
  return answer
endfunction
" }}}

" {{{ script teardown
let &cpo = s:save_cpo
unlet s:save_cpo
" }}}
