hi def EndOfBuffer        ctermfg=Black    guifg=Black guibg=NONE ctermbg=NONE
hi def TreevialDir        ctermfg=DarkBlue guifg=DarkBlue
hi def TreevialRoot       ctermfg=Green    guifg=Green
hi def TreevialExpandable ctermfg=DarkGray guifg=DarkGray

syn match TreevialDir        /\([^ \/]\+\/\)\+/
syn match TreevialRoot       /^\S\+\/$/
syn match TreevialImploded   /^\s*[^+-] [^+-]\S\+\/\S\+$/ contains=TreevialDir
syn match TreevialExpandable /^\s*[+-]/                   contains=TreevialDir
