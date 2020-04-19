hi def EndOfBuffer          ctermfg=Black     guifg=Black    guibg=NONE ctermbg=NONE
hi def TreevialDir          ctermfg=DarkBlue  guifg=#00aaff  cterm=bold gui=bold
hi def TreevialDefaultMark  ctermfg=Gray      guifg=Gray     cterm=bold gui=bold
hi def TreevialSelectedMark ctermfg=Red       guifg=Red      cterm=bold gui=bold
hi def TreevialPartialMark  ctermfg=Yellow    guifg=Yellow   cterm=bold gui=bold
hi def TreevialDirState     ctermfg=DarkGray  guifg=Gray     cterm=bold gui=bold
hi def TreevialFile         ctermfg=LightGray guifg=#f8f8f8  cterm=bold gui=bold
hi def TreevialExecutable   ctermfg=Green     guifg=#22cc22  cterm=bold gui=bold
hi def TreevialSymlink      ctermfg=Magenta   guifg=#d77ee0  cterm=bold gui=bold

syn match TreevialFile        /[^\/]\+[^\/]$/
syn match TreevialDir         /\([^\/]\+\/\)\+/
syn match TreevialDirState    /^\s*[+-]/
syn match TreevialDefaultMark /^\s*[\*|•]/
