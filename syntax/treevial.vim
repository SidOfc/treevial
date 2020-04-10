hi def EndOfBuffer      ctermfg=Black    guifg=Black guibg=NONE ctermbg=NONE
hi def TreevialDir      ctermfg=DarkBlue guifg=DarkBlue
hi def TreevialDirState ctermfg=DarkGray guifg=DarkGray

syn match TreevialDir      /\([^ \/]\+\/\)\+/
syn match TreevialDirState /^\s*[+-]/
