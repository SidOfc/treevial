if exists('g:loaded_treevial') || !has('lambda')
  finish
endif

" {{{ script setup
let g:loaded_netrw       = 1
let g:loaded_netrwPlugin = 1
let g:loaded_treevial    = 1
let s:save_cpo           = &cpo
set cpo&vim

call treevial#settings#init('default_mappings', v:version >=? 703)
call treevial#settings#init('mark_symbol',      has('multi_byte') ? '•' : '*')
call treevial#settings#init('expand_symbol',    has('multi_byte') ? '▸' : '+')
call treevial#settings#init('collapse_symbol',  has('multi_byte') ? '▾' : '-')
" }}}

" {{{ main functionality
function! treevial#open(...) abort
  let options = get(a:, 1, {})
  let entry   = treevial#util#lnum_to_entry(line('.'))

  if treevial#util#is_entry(entry)
    if entry.is_dir
      if get(options, 'vertical') || get(options, 'horizontal')
        return
      endif

      call entry.toggle(options)
      call treevial#view#render()
    else
      call entry.open(options)
      call clearmatches()
    endif
  endif
endfunction

function! treevial#mark(...) abort
  let options = get(a:, 1, {})
  let lnum    = get(options, 'lnum', line('.'))
  let shift   = get(options, 'shift', 0)
  let entry   = treevial#util#lnum_to_entry(lnum)

  if treevial#util#is_entry(entry)
    call entry.mark()
    call entry.mark_children()

    if !entry.is_marked
      call entry.mark_parents()
    endif

    call cursor(lnum + (shift ? -1 : 1), 1)
    call treevial#view#render()
  endif
endfunction

function! treevial#unmark_all() abort
  for [entry, _] in b:root.list()
    call entry.mark(0)
    call entry.mark_children()
  endfor

  call treevial#view#render()
endfunction

function! treevial#create() abort
  let destination = input('create: ', b:root.path, 'dir')
  let dest_is_dir = destination =~? '\/$'
  let dest_exists = filereadable(destination) || isdirectory(destination)

  if dest_exists
    return treevial#util#confirm(destination . ' already exists')
  elseif empty(destination)
    return
  endif

  if dest_is_dir
    if !treevial#io#mkdirp(destination) | return | endif
  else
    if !treevial#io#mkfile(destination) | return | endif
  endif

  call b:root.sync()
  call treevial#view#render()
endfunction

function! treevial#selection()
  return b:root.list_actionable()
endfunction

function! treevial#move() abort
  let selection = treevial#selection()

  if len(selection) <? 2
    let entry = get(selection, 0, treevial#util#lnum_to_entry(line('.')))

    if treevial#util#is_entry(entry)
      call treevial#io#handle_move_single_entry(entry)
    endif
  else
    return treevial#io#handle_move_multiple_entries(selection)
  endif
endfunction

function! treevial#destroy() abort
  let selection = treevial#selection()

  if empty(selection)
    let entry = treevial#util#lnum_to_entry(line('.'))

    if treevial#util#is_entry(entry)
      let selection = [entry]
    endif
  endif

  if !empty(selection)
    let choice = treevial#util#confirm({
          \ 'entries': selection,
          \ 'message': 'will be deleted, continue?',
          \ 'choices': "&No\n&Yes"
          \ })

    if choice ==# 2
      call treevial#io#delete_all(selection)
      call b:root.sync()
      call treevial#view#render()
    endif
  endif
endfunction

function! treevial#up() abort
  let dest = fnamemodify(
        \ treevial#util#strip_trailing_slash(b:root.path),
        \ repeat(':h', v:count1))

  call treevial#view#move_to(dest)
endfunction

function! treevial#down() abort
  let entry = treevial#util#lnum_to_entry(line('.'))
  if treevial#util#is_entry(entry)
    let base       = substitute(entry.path, entry.name, '', '')
    let parts      = split(treevial#util#strip_trailing_slash(entry.name), '/')
    let max_offset = len(parts) - 1 - !entry.is_dir
    let dest       = base . join(parts[:max_offset][:(v:count1 - 1)], '/')

    if max_offset >? -1
      call treevial#view#move_to(dest)
    endif
  endif
endfunction

function! treevial#initial_root()
  call treevial#view#move_to(treevial#view#init_cwd())
endfunction

function! treevial#home()
  call treevial#view#move_to($HOME)
endfunction
" }}}

" {{{ activation on startup + create Tr[eevial] command
function! s:vimenter() abort
  let root_target = get(argv(), 0, getcwd())
  let no_lnum     = line2byte('$') ==# -1

  if exists('#FileExplorer')        | exe 'au! FileExplorer *'        | endif
  if exists('#NERDTreeHijackNetrw') | exe 'au! NERDTreeHijackNetrw *' | endif

  if isdirectory(root_target) && no_lnum && !&insertmode && &modifiable
    exe 'Treevial' root_target
  endif
endfunction

function! s:command_handler(...)
  let cwd = get(a:, 1, getcwd())

  call treevial#view#buffer({'cwd': cwd})
endfunction

if !exists(':Treevial')
  command -complete=dir -nargs=? Treevial call s:command_handler(<f-args>)
endif

augroup Treevial
  autocmd!
  autocmd VimEnter * call s:vimenter()
augroup END
" }}}

" {{{ script teardown
let &cpo = s:save_cpo
unlet s:save_cpo
" }}}
