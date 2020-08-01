let s:save_cpo = &cpo
set cpo&vim

let s:settings = {}

function! treevial#settings#init(name, default) abort
  let s:settings[a:name] = get(g:, 'treevial_' . a:name, a:default)
endfunction

function! treevial#settings#get(name) abort
  return get(s:settings, a:name)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
