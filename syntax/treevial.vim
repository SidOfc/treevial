hi def EndOfBuffer          ctermfg=Black     guifg=Black    guibg=NONE ctermbg=NONE
hi def TreevialDir          ctermfg=DarkBlue  guifg=#00aaff  cterm=bold gui=bold
hi def TreevialDefaultMark  ctermfg=Gray      guifg=Green
hi def TreevialSelectedMark ctermfg=Red       guifg=Red
hi def TreevialPartialMark  ctermfg=Yellow    guifg=Yellow   cterm=bold gui=bold
hi def TreevialDirState     ctermfg=DarkGray  guifg=Gray     cterm=bold gui=bold
hi def TreevialFile         ctermfg=LightGray guifg=#bbbbbb  cterm=bold gui=bold
hi def TreevialExecutable   ctermfg=Green     guifg=#22cc22  cterm=bold gui=bold

syn match TreevialFile        /[^\/]\+[^\/]$/
syn match TreevialDir         /\([^\/]\+\/\)\+/
syn match TreevialDirState    /^\s*[+-]/
syn match TreevialDefaultMark /^\s*[\*|•]/
