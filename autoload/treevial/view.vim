let s:save_cpo = &cpo
set cpo&vim

function! treevial#view#init_cwd() abort
  return get(s:, 'init_cwd', getcwd())
endfunction

function! treevial#view#buffer(...) abort
  let options    = get(a:, 1, {})
  let root       = treevial#entry#new(get(options, 'cwd', getcwd()))
  let s:init_cwd = treevial#view#init_cwd()
  let bufname    = substitute(
        \ root.path,
        \ fnamemodify(s:init_cwd, ':h') . '/',
        \ '',
        \ '')

  exe 'edit' bufname
  setfiletype treevial

  let b:root = root

  setlocal noru nonu nornu noma nomod ro noswf nospell nowrap
  setlocal bufhidden=hide buftype=nowrite buftype=nofile

  augroup Treevial
    autocmd!
    autocmd BufEnter,FocusGained <buffer> call treevial#view#activate()
    autocmd BufLeave,FocusLost   <buffer> call treevial#view#deactivate()
  augroup END

  call b:root.expand()
  call treevial#view#mappings()
  call treevial#view#render()
endfunction

function! treevial#view#deactivate() abort
  let b:active = 0
endfunction

function! treevial#view#activate() abort
  if get(b:, 'active', 1) ==# 0
    call b:root.sync()
    call treevial#view#render()
    let b:active = 1
  endif
endfunction

function! treevial#view#goto_first_with_winvar(winvar) abort
  let win_with_var = get(filter(getwininfo(),
        \ {_, win -> get(win.variables, a:winvar) ==# 1}), 0, {})
  let target_winid = bufwinid(get(win_with_var, 'bufnr', -1))

  if target_winid ># -1
    call win_gotoid(target_winid)
    return 1
  else
    return 0
  endif
endfunction

function! treevial#view#move_to(dest) abort
  let b:root = treevial#entry#new(a:dest)
  call b:root.expand()
  call treevial#view#render()
endfunction

function! treevial#view#mappings() abort
  if treevial#settings#get('default_mappings')
    nnoremap <silent><nowait><buffer> <Cr>    :<C-u>call treevial#open()<Cr>
    nnoremap <silent><nowait><buffer> <C-v>   :<C-u>call treevial#open({'vertical': 1})<Cr>
    nnoremap <silent><nowait><buffer> <C-x>   :<C-u>call treevial#open({'horizontal': 1})<Cr>
    nnoremap <silent><nowait><buffer> -       :<C-u>call treevial#up()<Cr>
    nnoremap <silent><nowait><buffer> =       :<C-u>call treevial#down()<Cr>
    nnoremap <silent><nowait><buffer> .       :<C-u>call treevial#initial_root()<Cr>
    nnoremap <silent><nowait><buffer> ~       :<C-u>call treevial#home()<Cr>
    nnoremap <silent><nowait><buffer> <Tab>   :call treevial#mark()<Cr>
    nnoremap <silent><nowait><buffer> <S-Tab> :call treevial#mark({'shift': 1})<Cr>
    nnoremap <silent><nowait><buffer> u       :call treevial#unmark_all()<Cr>
    nnoremap <silent><nowait><buffer> d       :call treevial#destroy()<Cr>
    nnoremap <silent><nowait><buffer> m       :call treevial#move()<Cr>
    nnoremap <silent><nowait><buffer> c       :call treevial#create()<Cr>

    if has('nvim')
      nnoremap <silent><nowait><buffer> <S-Cr> :<C-u>call treevial#open({'shift': 1})<Cr>
    endif
  endif

  if exists('#User#TreevialMappings')
    doautocmd User TreevialMappings
  endif
endfunction

function! treevial#view#render() abort
  let saved_view   = winsaveview()
  let target       = bufname('%')
  let current_lnum = 0
  let mark_prefix  = b:root.has_marked_entries()
        \ ? treevial#settings#get('mark_symbol') . ' '
        \ : '  '

  setlocal ma noro

  call treevial#util#clear_buffer()
  call clearmatches()
  call append(current_lnum, b:root.name)

  for [entry, depth] in b:root.list()
    let check_links   = 0
    let current_lnum += 1
    let indent_mult   = depth * 2
    let indent        = repeat(' ', indent_mult)
    let fname_len     = len(entry.filename)
    let prefix        = len(entry.fetched_children())
          \ ? entry.is_open
            \ ? treevial#settings#get('collapse_symbol') . ' '
            \ : treevial#settings#get('expand_symbol') . ' '
          \ : mark_prefix
    let line          = indent . prefix . entry.name

    call append(current_lnum, line)
    call treevial#util#each_view({-> matchaddpos(
          \ 'TreevialIndicator', [[current_lnum + 1, indent_mult + 1]])})

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
          call treevial#util#each_view({-> matchaddpos(
                \ 'TreevialSymlink', positions)})
          let positions = []
        endif

        if idx ==# 0 && broken_pos_len >? 0 || broken_pos_len ==# 8
          call treevial#util#each_view({-> matchaddpos(
                \ 'TreevialBrokenSymlink', broken_positions)})
          let broken_positions = []
        endif
      endfor
    endif

    if entry.is_exe
      call treevial#util#each_view({-> matchaddpos(
            \ 'TreevialExecutable',
            \ [[current_lnum + 1, len(line) - fname_len + 1, fname_len]])})
    endif

    if entry.is_marked
      call treevial#util#each_view({-> matchaddpos(
            \ 'TreevialIndicatorSelected', [[current_lnum + 1, indent_mult + 1]])})
    elseif entry.has_marked_entries()
      call treevial#util#each_view({-> matchaddpos(
            \ 'TreevialIndicatorPartial', [[current_lnum + 1, indent_mult + 1]])})
    endif
  endfor

  call treevial#util#clear_trailing_empty_lines()
  call treevial#util#winrestview(saved_view)

  setlocal noma ro nomod
  mode
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
