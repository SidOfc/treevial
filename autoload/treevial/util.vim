let s:save_cpo = &cpo
set cpo&vim

function! treevial#util#opened_by_treevial(...) abort
  let command = get(a:, 1, 'edit')
  return filter(getwininfo(),
        \ {_, win -> has_key(win.variables, 'treevial_data') &&
        \            win.variables.treevial_data.command ==# command})
endfunction

function! treevial#util#strip_trailing_slash(path)
  return substitute(a:path, '\/\+$', '', '')
endfunction

function! treevial#util#lnum_to_entry(lnum) abort
  return a:lnum >? 1 ? get(get(b:root.list(), a:lnum - 2, []), 0) : 0
endfunction

function! treevial#util#each_view(func) abort
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

function! treevial#util#winrestview(position) abort
  call treevial#util#each_view({-> winrestview(a:position)})
endfunction

function! treevial#util#clear_buffer() abort
  call deletebufline('%', 1, line('$')) | echo ''
endfunction

function! treevial#util#clear_trailing_empty_lines() abort
  while empty(getline('$'))
    call deletebufline('%', line('$'))
  endwhile | echo ''
endfunction

function! treevial#util#is_entry(entry) abort
  return type(a:entry) ==# type({})
endfunction

function! treevial#util#confirm(overrides) abort
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
        \   treevial#util#categorized_entries_message(options.entries),
        \   options.message),
        \   options.choices,
        \   options.default)

  redraw!

  return choice
endfunction

function! treevial#util#categorized_entries_message(entries) abort
  let message    = ''
  let own_cats   = type(get(a:entries, 0, {})) == type([])
  let categories = own_cats
        \ ? a:entries
        \ : treevial#util#split_files_and_dirs(a:entries)

  for [category, category_entries] in categories
    let entries_length = len(category_entries)

    if entries_length
      let joined_paths  = join(map(copy(category_entries), '"  " . v:val.path'), "\n")
      let message      .= own_cats
            \ ? printf("%s:\n%s\n\n", category, joined_paths)
            \ : printf(
            \   "%d %s:\n%s\n\n",
            \   entries_length,
            \   treevial#util#pluralize(category, entries_length),
            \   joined_paths)
    endif
  endfor

  return message
endfunction

function! treevial#util#split_files_and_dirs(entries)
  let files       = []
  let directories = []

  for entry in a:entries
    call add(entry.is_dir ? directories : files, entry)
  endfor

  return [['files', files], ['directories', directories]]
endfunction

function! treevial#util#pluralize(word, count) abort
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

function! treevial#util#to_dict(listlist) abort
  let dict = {}

  for [key, value] in a:listlist
    let dict[key] = value
  endfor

  return dict
endfunction

function! treevial#util#filename_words(filename) abort
  let words = []
  for part in split(a:filename, '\d\+\zs\ze')
    let words += split(part, '\D\zs\ze\d\+')
  endfor

  return map(words, "v:val =~ '^\\d\\+$' ? str2nr(v:val) : v:val")
endfunction

function! treevial#util#compare_filename(entry1, entry2) abort
  let words_1 = treevial#util#filename_words(a:entry1.filename)
  let words_2 = treevial#util#filename_words(a:entry2.filename)
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

let s:test = {}

function! s:test.vader_confirmed() abort
  return get(g:, '__treevial_vader_confirm_reply__', '') != ''
endfunction

function! s:test.vader_confirm_answer() abort
  let answer = g:__treevial_vader_confirm_reply__
  unlet g:__treevial_vader_confirm_reply__
  return answer
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
