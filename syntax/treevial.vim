" remove end of buffer tilde (~) characters
hi  def EndOfBuffer ctermfg=Black guifg=Black guibg=NONE ctermbg=NONE

" files, directories, executables, symlinks / broken symlinks
hi  def TreevialDir           ctermfg=DarkBlue  guifg=#00aaff cterm=bold gui=bold
hi  def TreevialFile          ctermfg=LightGray guifg=#f8f8f8 cterm=bold gui=bold
hi  def TreevialExecutable    ctermfg=Green     guifg=#22cc22 cterm=bold gui=bold
hi  def TreevialSymlink       ctermfg=Magenta   guifg=#d77ee0 cterm=bold gui=bold
hi  def TreevialBrokenSymlink ctermfg=Brown     guifg=#ea871e cterm=bold gui=bold

" indicators / marked & unmarked states
hi def TreevialIndicator         ctermfg=DarkGray guifg=Gray   cterm=bold gui=bold
hi def TreevialIndicatorSelected ctermfg=Red      guifg=Red    cterm=bold gui=bold
hi def TreevialIndicatorPartial  ctermfg=Yellow   guifg=Yellow cterm=bold gui=bold

" files and directories are matched using regex
" additional symlink / exe / directory highlighting
" is applied using `matchadd()` in `s:view.render()`
syn match TreevialFile /[^\/]\+[^\/]$/
syn match TreevialDir  /\([^\/]\+\/\)\+/
