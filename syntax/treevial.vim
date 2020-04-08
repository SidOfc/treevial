hi def EndOfBuffer ctermfg=Black guifg=Black guibg=NONE ctermbg=NONE

hi def TreevialDir        ctermfg=DarkBlue guifg=DarkBlue
hi def TreevialRoot       ctermfg=Green    guifg=Green
hi def TreevialExpandable ctermfg=DarkGray guifg=DarkGray

syn match TreevialDir  /\([^\/ ]\+\/\)\+$/ contained
syn match TreevialDir        /\S\+\/$/     contained

syn match TreevialRoot       /^\S\+\/$/
syn match TreevialExpandable /^ *[+-].*$/  contains=TreevialDir
