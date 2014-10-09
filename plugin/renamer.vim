" renamer.vim
" Maintainer:   John Orr (john undersc0re orr yah00 c0m)
" Version:      1.4
" Last Change:  16 November 2011

" Changelog:   {{{1
" 1.0 - initial functionality
" 1.1 - added options to
"       a) support :w as substitute for :Ren, and
"       b) ignore wildignore settings when reading in files
"     - fixed highlighting after file deletion
"     - various other minor changes, eg naming the buffer.
" 1.2 - fix filename handling for linux - thanks Antonio Monizio
"     - improve :w support to avoid delay showing command line - thanks Sergey Bochenkov
"     - other minor improvements
" 1.3 - check that proposed filenames are valid before applying them
"     - add support for creating required directories - thanks to Glen Miner
"       for the request that made it finally happen.
"     - fix location of intermediate files to be the same as the source file.
"       (Particularly important for large files on slow-access media, as
"       they were being copied to and from local media.)
"       Thanks to Adam Courtemanche for finding and fixing the bug!
" 1.4 - fix permitted filenames problem on Mac OS - thanks Adam Courtemanche.
"     - fix bug when launching from within an existing buffer.

" Reload guard and 'compatible' handling {{{1
let s:save_cpo = &cpo
set cpo&vim

if get(g:, "loaded_renamer", 0)
  finish
endif
let g:loaded_renamer = 1

" User configurable variables {{{1
" The following variables can be set in your .vimrc/_vimrc file to override
" those in this file, such that upgrades to the script won't require you to
" re-edit these variables.

" g:RenamerOriginalFileWindowEnabled {{{2
" Controls whether the window showing the original files is enabled or not
" It can be toggled with <Shift-T>
let g:RenamerOriginalFileWindowEnabled = get(g:, 'RenamerOriginalFileWindowEnabled', 0)

" g:RenamerShowLinkTargets {{{2
" Controls whether the resolved targets of any links will be shown as comments
let g:RenamerShowLinkTargets = get(g:, 'RenamerShowLinkTargets', 1)

" g:RenamerWildIgnoreSetting {{{2
let g:RenamerWildIgnoreSetting = get(g:, 'RenamerWildIgnoreSetting', 'VIM_WILDIGNORE_SETTING')

" g:RenamerSupportColonWToRename {{{2
let g:RenamerSupportColonWToRename = get(g:, 'RenamerSupportColonWToRename', 0)

" Highlight links
" g:RenamerHighlightForPrimaryInstructions {{{2
let g:RenamerHighlightForPrimaryInstructions = get(g:, 'RenamerHighlightForPrimaryInstructions', 'Todo')

" g:RenamerHighlightForSecondaryInstructions {{{2
let g:RenamerHighlightForSecondaryInstructions = get(g:, 'RenamerHighlightForSecondaryInstructions', 'comment')

" g:RenamerHighlightForLinkInfo {{{2
let g:RenamerHighlightForLinkInfo = get(g:, 'RenamerHighlightForLinkInfo', 'comment')

" g:RenamerHighlightForModifiedFilename {{{2
let g:RenamerHighlightForModifiedFilename = get(g:, 'RenamerHighlightForModifiedFilename', 'Constant')

" g:RenamerHighlightForOriginalFilename {{{2
let g:RenamerHighlightForOriginalFilename = get(g:, 'RenamerHighlightForOriginalFilename', 'Keyword')

" g:RenamerHighlightForNonWriteableEntries {{{2
let g:RenamerHighlightForNonWriteableEntries = get(g:, 'RenamerHighlightForNonWriteableEntries', 'NonText')

" g:RenamerHighlightForOriginalDirectoryName {{{2
let g:RenamerHighlightForOriginalDirectoryName = get(g:, 'RenamerHighlightForOriginalDirectoryName', 'bold')


" Commands {{{1
" To run the script
if !exists(':Renamer')
  command -bang -nargs=? -complete=dir Renamer :call <SID>StartRenamer(1,-1,'<args>')
endif


" Keyboard mappings {{{1
"
" All mappings are defined only when the script starts, and are
" specific to the buffer.  Change them in the code if you want.
"
" A template to defined a mapping to start this plugin is:
" noremap <Plug>RenamerStart     :call <SID>StartRenamer(1,-1,getcwd())<CR>
" if !hasmapto('<Plug>RenamerStart')
"   nmap <silent> <unique> <Leader>ren <Plug>RenamerStart
" endif


" Autocommands {{{1
"
" None at present
" augroup Renamer
" augroup END

" Cleanup and modelines {{{1
let &cpo = s:save_cpo

" vim:ft=vim:fdm=marker:fen:fmr={{{,}}}:
