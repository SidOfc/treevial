let s:save_cpo = &cpo
set cpo&vim

let s:entry   = {}
let s:fn_type = type(function('getline'))

function! treevial#entry#new(path, ...) abort
  let is_dir   = isdirectory(a:path)
  let root     = get(a:, 1, fnamemodify(a:path, ':p:h:h'))
  let path     = fnamemodify(a:path, ':p')
  let resolved = resolve(a:path)
  let modified = getftime(resolved)
  let is_ln    = a:path !=? resolved

  return extend(copy(s:entry), {
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
  let options        = get(a:, 1, {})
  let spl_hor        = get(options, 'horizontal')
  let spl_vert       = get(options, 'vertical')
  let escaped_path   = fnameescape(self.path)
  let command        = spl_vert ? 'vsplit' : spl_hor ? 'split' : 'edit'
  let target_buffers = (spl_hor || spl_vert) ? treevial#util#opened_by_treevial(command) : []
  let target_buffer  = get(filter(copy(target_buffers),
        \ {_, buf -> buf.variables.treevial_data.index ==# v:count1}), 0, {})
  let target_winid   = bufwinid(get(target_buffer, 'bufnr', -1))

  if target_winid ># -1
    call win_gotoid(target_winid)
    exe 'edit' escaped_path
  else
    if v:count1
      let align_after = get(filter(
            \ copy(target_buffers),
            \ {_, buf -> buf.variables.treevial_data.index <# v:count1}),
            \ -1, {})
      let align_winid = bufwinid(get(align_after, 'bufnr', -1))

      if align_winid ># -1
        call win_gotoid(align_winid)
      endif
    endif

    exe command escaped_path

    call setwinvar(winnr(), 'treevial_data', {'command': command, 'index': v:count1})
  endif
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

  if treevial#util#is_entry(parent)
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
  let recursive = get(options, 'shift')

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
      let result_entry    = child_entry
      let symlinks        = [result_entry.is_symlink]
      let original_parent = result_entry.parent()

      while len(result_entry.children()) ==# 1
        let result_entry = result_entry.children()[0]
        call add(symlinks, result_entry.is_symlink)
      endwhile

      if child_entry.path !=# result_entry.path
        call child_entry
              \.merge(result_entry)
              \.merge({
              \ 'name': substitute(result_entry.path, self.path, '', ''),
              \ '_parent': original_parent,
              \ '_children': result_entry.fetched_children()})
      endif
      call child_entry.merge({'symlinks': symlinks})
    endfor
  endif

  call self.merge({'is_open': self.is_dir, '_expanded': 1})
  return self
endfunction

function! s:entry.children() abort dict
  if self.is_dir && !has_key(self, '_children')
    let root     = treevial#util#strip_trailing_slash(self.path)
    let children = sort(sort(map(filter(
        \ glob(root . '/*',  0, 1, 1) + glob(root . '/.*', 0, 1, 1),
        \ {_,  p  -> p !~# '/\.\.\?$'}),
        \ {_,  p  -> treevial#entry#new(p, root)}),
        \ {x1, x2 -> treevial#util#compare_filename(x1, x2)}),
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
  return get(self, '_parent')
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
  return self
        \.merge(treevial#entry#new(treevial#util#strip_trailing_slash(self.path))
        \.synchronize_with(self))
endfunction

function! s:entry.synchronize_with(previous) abort dict
  let new_entries         = self.expand().children()
  let old_entries_by_path = {}

  for old_entry in a:previous.fetched_children()
    let old_entries_by_path[old_entry.path] = old_entry
  endfor

  for new_entry in new_entries
    let old_entry = get(old_entries_by_path, new_entry.path)
    if treevial#util#is_entry(old_entry)
      if new_entry.modified ==# old_entry.modified
        for old_entry_child in old_entry.fetched_children()
          call old_entry_child.merge({'_parent': new_entry})
        endfor
        call new_entry.merge(old_entry)
      elseif new_entry.is_dir && old_entry.is_dir && old_entry.is_open
        call new_entry.synchronize_with(old_entry)
      endif
      call new_entry.merge({'_parent': self})
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

let &cpo = s:save_cpo
unlet s:save_cpo
