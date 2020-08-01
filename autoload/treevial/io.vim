function! treevial#io#handle_move_multiple_entries(entries) abort
  let entries              = copy(a:entries)
  let entry_filenames      = uniq(sort(map(copy(entries), 'v:val.filename')))
  let entry_filename_table = treevial#util#to_dict(map(copy(entry_filenames), '[v:val, []]'))
  let illegal_moves        = []
  let dest_path            = expand(
        \ treevial#util#strip_trailing_slash(input('directory: ', b:root.path, 'dir')))

  mode

  if filereadable(dest_path)
    call treevial#util#confirm(dest_path . ' is a file, please choose a directory')
    return treevial#io#handle_move_multiple_entries(entries)
  elseif empty(dest_path)
    return
  endif

  for entry in entries
    let errors = treevial#io#validate_move(entry.path, dest_path . '/' . entry.filename)

    call add(entry_filename_table[entry.filename], entry)

    if errors.overwrite_parent || errors.move_into_self
      call add(illegal_moves, entry)
    endif
  endfor

  call filter(entry_filename_table, 'len(v:val) >? 1')

  if !empty(illegal_moves)
    let one = len(illegal_moves) ==# 1
    let choice = treevial#util#confirm({
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
      call treevial#view#render()
    endif
    return
  endif

  if !empty(entry_filename_table)
    let choice = treevial#util#confirm({
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
      call treevial#view#render()
    else
      return
    endif
  endif

  if !isdirectory(dest_path) && !treevial#io#mkdirp(dest_path)
    return
  endif

  let dest_entry      = treevial#entry#new(dest_path)
  let dest_filenames  = map(dest_entry.children(), 'tolower(v:val.filename)')
  let would_overwrite = filter(
        \ copy(entries),
        \ {_, entry -> index(dest_filenames, tolower(entry.filename)) >? -1})

  mode

  if !empty(would_overwrite)
    let choice = treevial#util#confirm({
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
    call treevial#io#move(marked.path, dest_path . '/' . marked.filename)
  endfor

  call b:root.sync()
  call treevial#view#render()
endfunction

function! treevial#io#handle_move_single_entry(entry) abort
  let dest_path   = expand(substitute(input('destination: ', a:entry.path, 'dir'), '\/$', '', ''))
  let dest_parent = fnamemodify(dest_path, ':h')
  let entry_path  = substitute(a:entry.path, '\/$', '', '')
  let errors      = treevial#io#validate_move(entry_path, dest_path)

  mode

  if errors.noop
    return
  elseif errors.overwrite_parent
    return treevial#util#confirm('unable to overwrite parent directory')
  elseif errors.move_into_self
    return treevial#util#confirm('files and directories can not be moved into themselves')
  elseif errors.dest_exists
    let choice = treevial#util#confirm({
          \ 'message': join(['destination "' . dest_path . '" already exists,',
          \                  "what would you like to do?"], "\n\n"),
          \ 'choices': "&Cancel\n&Overwrite"
          \ })

    if choice !=? 2
      return
    endif
  elseif !isdirectory(dest_parent)
    if !treevial#io#mkdirp(dest_parent)
      return
    endif
  endif

  call treevial#io#move(entry_path, dest_path)
  call b:root.sync()
  call treevial#view#render()
endfunction

function! treevial#io#move(from, to) abort
  if rename(a:from, a:to) !=? 0
    return treevial#util#confirm({
          \ 'entries': [['rename', [{'path': a:from}]],
          \             ['to',     [{'path': a:to}]]],
          \ 'message': 'failed, press <ENTER> to continue'})
  endif
endfunction

function! treevial#io#mkdirp(path) abort
  try
    call mkdir(a:path, 'p')
  finally
    if isdirectory(a:path)
      return 1
    else
      call treevial#util#confirm('failed to create "' . a:path . '"')
      return 0
    endif
  endtry
endfunction

function treevial#io#mkfile(destination) abort
  let dest_dir = fnamemodify(a:destination, ':h')
  if isdirectory(dest_dir) || treevial#io#mkdirp(dest_dir)
    try
      if writefile([], a:destination, 'b') !=? 0
        throw 1
      endif
      return 1
    catch
      call treevial#util#confirm('failed to create file: ' . a:destination)
      return 0
    endtry
  else
    return 0
  endif
endfunction

function treevial#io#validate_move(from, to) abort
  let from = substitute(a:from, '\/$', '', '')
  let to   = substitute(a:to, '\/$', '', '')

  return {
        \ 'overwrite_parent': from =~? '^' . to && isdirectory(to),
        \ 'move_into_self': to =~? '^' . from . '/',
        \ 'noop': to ==? from || empty(to) || empty(from),
        \ 'dest_exists': isdirectory(to) || filereadable(to)
        \ }
endfunction

function! treevial#io#delete_all(entries) abort
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
    call treevial#util#confirm({
          \ 'entries': failed
          \ 'message': 'could not be removed and will remain marked!',
          \ 'choices': "&Ok"
          \ })
    return 0
  else
    return 1
  endif
endfunction

