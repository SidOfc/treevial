hi def EndOfBuffer          ctermfg=Black    guifg=Black    guibg=NONE ctermbg=NONE
hi def TreevialDir          ctermfg=DarkBlue guifg=DarkBlue cterm=bold gui=bold
hi def TreevialSelectedMark ctermfg=Red      guifg=Red
hi def TreevialPartialMark  ctermfg=Yellow   guifg=Yellow   cterm=bold gui=bold
hi def TreevialDirState     ctermfg=DarkGray guifg=DarkGray cterm=bold gui=bold

syn match TreevialDir      /\([^ \/]\+\/\)\+/
syn match TreevialDirState /^\s*[+\-*]/
