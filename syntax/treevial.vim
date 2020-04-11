hi def EndOfBuffer      ctermfg=Black    guifg=Black    guibg=NONE ctermbg=NONE
hi def TreevialDir      ctermfg=DarkBlue guifg=DarkBlue cterm=bold gui=bold
hi def TreevialMarked   ctermfg=Yellow   guifg=Yellow
hi def TreevialDirState ctermfg=DarkGray guifg=DarkGray

syn match TreevialDir      /\([^ \/]\+\/\)\+/
syn match TreevialDirState /^\s*[+\-*]/
