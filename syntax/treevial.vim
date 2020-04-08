hi def EndOfBuffer ctermfg=Black guifg=Black guibg=NONE ctermbg=NONE

hi def TreevialDir        ctermfg=DarkBlue guifg=DarkBlue
hi def TreevialRoot       ctermfg=Yellow   guifg=Yellow
hi def TreevialExpandable ctermfg=DarkGray guifg=DarkGray

syn match TreevialDir        /^  \+\([^\/]\+\/\)\+/
syn match TreevialDir        /\S\+\/$/      contained

syn match TreevialRoot       /^\S\+\/$/     contains=TreevialDir
syn match TreevialExpandable /^\s*[+-].*$/  contains=TreevialDir
