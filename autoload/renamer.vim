scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

" Script variables {{{1
let s:hashes = '### '
let s:linksTo = 'LinksTo: '
let s:linkPrefix = ' '.s:hashes.s:linksTo
let s:header = [
  \ "Renamer: change names then give command :Ren\n" ,
  \ "ENTER=chdir, T=toggle original files, F5=refresh, Ctrl-Del=delete\n" ,
  \ "Do not change the number of files listed (unless deleting)\n"
  \ ]
let s:headerLineCount = len(s:header) + 2 " + 2 because of extra lines added later


function! renamer#start(needNewWindow, startLine, directory) "{{{1
  " Check version
  call s:alert()

  " The main function that starts the app

  " Prevent a report of our actions from showing up
  let oldRep=&report
  let save_sc = &sc
  set report=10000 nosc

  " Get a blank window, either by
  if a:needNewWindow && !exists('b:renamerDirectory')
    " a) creating a window if non exists, or
    if bufname('') != '' || &mod
        new
    else
        normal! 1GVGd
    endif
    let b:renamerSavedDirectoryLocations = {}
  else
    " b) deleting the existing window content if renamer is already running
    normal! 1GVGd
  endif

  if g:RenamerOriginalFileWindowEnabled
    " Set scrollbinding in case the original files window is enabled so they
    " will scroll together.  Seems important to do it early in this function
    " to ensure it's processed for the correct buffer.
    setlocal scrollbind
  endif

  " Process optional parameters to this function and
  " set the directory to process
  if !empty(a:directory)
    let b:renamerDirectory = s:Path(a:directory)
  elseif !exists('b:renamerDirectory')
    let b:renamerDirectory = s:Path(getcwd())
  endif

  " Get an escaped version of b:renamerDirectory for later common use
  let b:renamerDirectoryEscaped = escape(b:renamerDirectory, '[]`~$*\')

  " Set the title, since the renamer window won't have one
  let &titlestring='Vim Renamer ('.b:renamerDirectory.') - '.v:servername
  set title

  " Get a list of all the files
  " Since glob follows 'wildignore' settings and this may well be undesirable,
  " we may ignore such directives
  if g:RenamerWildIgnoreSetting != 'VIM_WILDIGNORE_SETTING'
    let savedWildignoreSetting = &wildignore
    let &wildignore = g:RenamerWildIgnoreSetting
  endif

  " Unix and Windows need different things due to differences in possible filenames
  if has('unix')
    let pathfiles = s:Path(glob(b:renamerDirectoryEscaped . "/*"))
  else
    let pathfiles = s:Path(glob(b:renamerDirectory . "/*"))
  endif
  if pathfiles != "" && pathfiles !~ "\n$"
    let pathfiles .= "\n"
  endif

  " Restore Wildignore settings
  if g:RenamerWildIgnoreSetting != 'VIM_WILDIGNORE_SETTING'
    let &wildignore = savedWildignoreSetting
  endif


  " Remove the directory from the filenames
  let filenames = substitute(pathfiles, b:renamerDirectoryEscaped . '/', '', 'g')

  " Calculate what to display on the screen and what to keep for when the
  " process is done
  " First declare some variables.  The list is long, due to differences
  " between
  " a) directories and files
  " b) writeable vs non-writeable items
  " c) symbolic links vs real files (hard links)
  " d) full paths needed for processing vs filename only for display
  " e) display text (eg including link resolutions) vs pure filenames
  " f) syntax highlighting issues, eg only applying a highlight to one
  "    specific line
  " ...however... some of these things could be rationalised using
  " multi-dimensional arrays.
  let pathfileList = sort(split(pathfiles, "\n"), 1) " List including full pathnames
  let filenameList = sort(split(filenames, "\n"), 1) " List of just filenames
  let numFiles = len(pathfileList)
  let writeableFilenames = []                        " The name only (no path) of all writeable files
  let writeableFilenamesEntryNums = []               " Used to calculate the final line number the name appears on
  let writeableFilenamesIsLink = []                  " Boolean, whether it's a link or not (affects syntax highlighting)
  let writeableFilenamesPath = []                    " Full path and name of each writeable file
  let writeableDirectories = []                      " Repeated for directories...
  let writeableDirectoriesEntryNums = []
  let writeableDirectoriesIsLink = []
  let writeableDirectoriesPath = []
  let b:renamerNonWriteableEntries = []

  let displayText  = s:hashes.join(s:header, s:hashes)   " Initialise the display text, start with the preset header
  let displayText .= s:hashes."Current directory: " . b:renamerDirectory . "\n"
  let displayText .= "# ../\n"

  let directoryDisplayText = ''                      " Display text for the directory parts
  let fileDisplayText = ''                           " Display text for the file parts
  let b:renamerMaxWidth = 0                          " Max width of an entry, to help with original file names window sizing

  let i = 0                                          " Main loop variable over all files
  let fileEntryNumber = 0                            " Index for file entries (writeable or not)
  let dirEntryNumber = 0                             " Index for directory entries (writeable or not)

  " Main loop for each file
  while i < numFiles

    " Link handling - decide if we need to add link info
    let addLinkInfo = 0
    let resolved = resolve(pathfileList[i])
    if resolved != pathfileList[i] && g:RenamerShowLinkTargets
      let addLinkInfo = 1
      let resolved = substitute(resolved, '\\', '\/', 'g')
      if isdirectory(resolved)
        let resolved .= '/'
      endif
    endif

    " Now process as writeable/nonwriteable, files/directories, etc.
    "
    if filewritable(pathfileList[i])
      " Writeable entries
      let text = filenameList[i]
      if isdirectory(pathfileList[i])
        " Writeable directories
        let writeableDirectories += [ filenameList[i] ]
        let writeableDirectoriesEntryNums += [ dirEntryNumber ]
        let writeableDirectoriesPath += [ pathfileList[i] ]
        let text .= "/"
        if addLinkInfo
          let writeableDirectoriesIsLink += [ 1 ]
          let text .= s:linkPrefix.resolved
        else
          let writeableDirectoriesIsLink += [ 0 ]
        endif
        let directoryDisplayText .= text."\n"
        let dirEntryNumber += 1
      else
        " Writeable files
        let writeableFilenames += [ filenameList[i] ]
        let writeableFilenamesEntryNums += [ fileEntryNumber ]
        let writeableFilenamesPath += [ pathfileList[i] ]
        if addLinkInfo
          let writeableFilenamesIsLink += [ 1 ]
          let text .= s:linkPrefix.resolved
        else
          let writeableFilenamesIsLink += [ 0 ]
        endif
        let fileDisplayText .= text."\n"
        let fileEntryNumber += 1
      endif
    else
      " Readonly entries
      let b:renamerNonWriteableEntries += [ pathfileList[i] ]
      if isdirectory(pathfileList[i])
        " Readonly directories
        let text = '# '.filenameList[i].'/ '.s:hashes.'Not writeable '.s:hashes
        if addLinkInfo
          let text .= s:linkPrefix.resolved
        endif
        let directoryDisplayText .= text."\n"
        let dirEntryNumber += 1
      else
        " Readonly files
        let text = '# '.filenameList[i].' '.s:hashes.'Not writeable '.s:hashes
        if addLinkInfo
          let text .= s:linkPrefix.resolved
        endif
        let fileDisplayText .= text."\n"
        let fileEntryNumber += 1
      endif
    endif
    let b:renamerMaxWidth = max([b:renamerMaxWidth, len(text)])
    let i += 1
  endwhile

  " Save the original names in the order they appear on the screen
  let b:renamerOriginalPathfileList = copy(writeableDirectoriesPath)
  let b:renamerOriginalPathfileList += copy(writeableFilenamesPath)

  " Display the text to the user
  let b:renamerEntryDisplayText = directoryDisplayText . fileDisplayText
  put =displayText
  if b:renamerEntryDisplayText != ''
    put =b:renamerEntryDisplayText
  endif
  " Remove a blank line created by 'put'
  normal! ggdd

  " Set the buffer type
  setlocal buftype=nofile
  setlocal noswapfile

  " Set the buffer name if not already set
  if bufname('%') != 'VimRenamer'
    exec 'file VimRenamer "' . b:renamerDirectoryEscaped . '"'
  endif

  " Setup syntax
  if has("syntax")
    syntax on
    exec "syn match RenamerSecondaryInstructions '^\s*".s:hashes.".*'"
    exec "syn match RenamerPrimaryInstructions   '^\s*".s:hashes."Renamer.*'"
    exec "syn match RenamerLinkInfo '".s:linkPrefix.".*'"
    syn match RenamerNonwriteableEntries         '^# .*'
    syn match RenamerModifiedFilename            '^\s*[^#].*'

    " Highlighting for files
    let i = 0
    while i < len(writeableFilenames)
      " Escape some characters for use in regex's
      let escapedFile = escape(writeableFilenames[i], '*[]\~"')
      " Calculate the line number for this entry, for line-specific syntax highlighting
      let lineNumber = dirEntryNumber + writeableFilenamesEntryNums[i] + s:headerLineCount + 1 " Get the line number
      " Start the match command
      let cmd = 'syn match RenamerOriginalFilename   "^\%'.lineNumber.'l'.escapedFile
      if writeableFilenamesIsLink[i] && g:RenamerShowLinkTargets
        " match linkPrefix also, but then exclude if from the match
        let cmd .= s:linkPrefix.'"me=e-'.len(s:linkPrefix)
      else
        let cmd .= '$"'
      endif
      exec cmd
      let i += 1
    endwhile

    " Highlighting for directories - duplicates file handling above - rationalise?
    let i = 0
    while i < len(writeableDirectories)
      " Escape some characters for use in regex's
      let escapedDir = escape(writeableDirectories[i], '*[]\~/') . '\/*'
      " Calculate the line number for this entry, for line-specific syntax highlighting
      let lineNumber = writeableDirectoriesEntryNums[i] + s:headerLineCount + 1
      " Start the match command
      let cmd = 'syn match RenamerOriginalDirectoryName   "^\%'.lineNumber.'l'.escapedDir
      if writeableDirectoriesIsLink[i] && g:RenamerShowLinkTargets
        let cmd .= s:linkPrefix.'"me=e-'.len(s:linkPrefix)
      else
        let cmd .= '$"'
      endif
      exec cmd
      let i += 1
    endwhile

    " Link the highlights to user-setable colours
    exec "highlight link RenamerPrimaryInstructions " . g:RenamerHighlightForPrimaryInstructions
    exec "highlight link RenamerSecondaryInstructions " . g:RenamerHighlightForSecondaryInstructions
    exec "highlight link RenamerLinkInfo " . g:RenamerHighlightForLinkInfo
    exec "highlight link RenamerModifiedFilename " . g:RenamerHighlightForModifiedFilename
    exec "highlight link RenamerOriginalFilename " . g:RenamerHighlightForOriginalFilename
    exec "highlight link RenamerNonwriteableEntries " . g:RenamerHighlightForNonWriteableEntries
    " Make directories a bold version of files if set to 'bold'
    if g:RenamerHighlightForOriginalDirectoryName == 'bold'
      let originalFilenameHighlightString = s:GetHighlightString(g:RenamerHighlightForOriginalFilename)
      let originalDirectoryNameHighlightString = s:AddBoldToHighlightGroupDefinition(originalFilenameHighlightString)
      exec "highlight RenamerOriginalDirectoryName " . originalDirectoryNameHighlightString
    else
      exec "highlight link RenamerOriginalDirectoryName " . g:RenamerHighlightForOriginalDirectoryName
    endif
  endif

  " Define command to do the rename
  exec 'command! -buffer -bang -nargs=0 Ren :call <SNR>'.s:sid.'_PerformRename()'

  if g:RenamerSupportColonWToRename
    " Enable :w<cr> to work as well
    cnoremap <buffer> <CR> <C-\>e<SID>CheckUserCommand()<CR><CR>
    function! s:CheckUserCommand()
      let cmd = getcmdline()
      if cmd == 'w'
        let cmd = 'Ren'
      endif
      return cmd
    endfunc
  endif

  " Define the mapping to change directories
  exec 'nnoremap <buffer> <silent> <CR> :call <SNR>'.s:sid.'_ChangeDirectory()<CR>'
  exec 'nnoremap <buffer> <silent> <C-Del> :call <SNR>'.s:sid.'_DeleteEntry()<CR>'
  exec 'nnoremap <buffer> <silent> T :call <SNR>'.s:sid.'_ToggleOriginalFilesWindow()<CR>'
  exec 'nnoremap <buffer> <silent> <F5> :call <SNR>'.s:sid.'_Refresh()<CR>'

  " Position the cursor
  if a:startLine > 0
    call cursor(a:startLine, 1)
  else
    " Position the cursor on the parent directory line
    call cursor(s:headerLineCount,1)
  endif

  " If the user wants the window with with original files, create it
  if g:RenamerOriginalFileWindowEnabled
    call s:CreateOriginalFileWindow(a:needNewWindow, b:renamerMaxWidth, b:renamerEntryDisplayText)
  endif

  " Restore things
  let &report=oldRep
  let &sc = save_sc

endfunction

function! s:alert()
  if v:version < 704
    echoe "renamer.vim requires vim version 7.4 or greater (mainly because it uses the new lists functionality)"
    finish
  endif
endfunction

function! s:CreateOriginalFileWindow(needNewWindow, maxWidth, entryDisplayText) "{{{1

  let currentLine = line('.')
  call cursor(1,1)

  if a:needNewWindow || g:RenamerOriginalFileWindowEnabled == 2
    " Create a new window to the left
    lefta vnew
    setlocal modifiable

    " Set the header text
    let headerText = [ s:hashes.'ORIGINAL' ,
                     \ s:hashes.' FILES' ,
                     \ s:hashes.'  DO' ,
                     \ s:hashes.' NOT' ,
                     \ s:hashes.'MODIFY!' ]
    let i = 0
    while i < s:headerLineCount
      if i < len(headerText)
        call setline(i+1, headerText[i])
      else
        call setline(i+1, '')
      endif
      let i += 1
    endwhile
  else
    " Go to the existing window, make it modifiable, and
    " delete the existing file entries
    wincmd h
    setlocal modifiable
    exec (s:headerLineCount+1).',$d'
  endif

  " Put the list of files/dirs
  exec s:headerLineCount.'put =a:entryDisplayText'

  " Set the buffer type
  setlocal buftype=nofile
  setlocal noswapfile
  setlocal nomodifiable
  setlocal scrollbind

  " Position the cursor on the same line as the main window
  call cursor(currentLine,1)

  " Set the width of the left hand window, as small as we can
  " 14 is the minimum reasonable, so set winwidth to that
  " to prevent vim enlarging it
  set winwidth=14
  let width = max([&winwidth, a:maxWidth+1])
  " But don't use more than half the width of vim
  exec 'vertical resize '.min([&columns/2, width])

  if a:needNewWindow
    " Setting the window width to the right size is tricky if renamer is
    " started via a command line option, since the gui doesn't seem to be fully sized
    " yet so we can't do "lefta <SIZE>vnew".
    " So register it to be done on the VIMEnter event.  Seems to work.
    augroup Renamer
      " In case user is changing the gui size via a startup command, delay the
      " resize as long as possible, until &columns will hopeuflly have its
      " final value
      exec 'autocmd VIMEnter <buffer> exec "vertical resize ".min([&columns/2, '.width.'])|wincmd l|cursor('.currentLine.',1)'
      " exec 'autocmd CursorHold <buffer> exec "vertical resize ".min([&columns/2, '.width.'])|wincmd l'
    augroup END
  else
    " Move back to the editable window since we have no autocmd to do it
    wincmd l
    call cursor(currentLine,1)
  endif

  " Reset g:RenamerOriginalFileWindowEnabled to 1 in case it was 2 to create a new window
  let g:RenamerOriginalFileWindowEnabled = 1

endfunction

function! s:PerformRename() "{{{1
" The function to do the renaming

  " Prevent a report of our actions from showing up
  let oldRep=&report
  let save_sc = &sc
  set report=10000 nosc

  " Get the current lines, except the first
  let saved_z = @z
  normal! 1GVG"zy
  let bufferText = @z
  let @z = saved_z

  let splitBufferText = split(bufferText, "\n")
  let modifiedFileList = []
  let lineNo = 0
  let invalidFileCount = 0
  for line in splitBufferText
    let lineNo += 1
    if line !~ '^#'
      let line = substitute(line, s:linkPrefix.'.*','','')
      let line = substitute(line, '\/$','','')
      let invalidFileCount += s:ValidatePathfile(b:renamerDirectory, line, lineNo)
      let modifiedFileList += [ b:renamerDirectory . '/' . line ]
    endif
  endfor

  if invalidFileCount
    echoe invalidFileCount." name(s) had errors. Resolve and retry..."
    return
  endif

  let numOriginalFiles = len(b:renamerOriginalPathfileList)
  let numModifiedFiles = len(modifiedFileList)

  if numModifiedFiles != numOriginalFiles
    echoe 'Dir contains '.numOriginalFiles.' writeable files, but there are '.numModifiedFiles.' listed in buffer.  These numbers should be equal'
    return
  endif

  " The actual renaming process is a hard one to do reliably.  Consider a few cases:
  " 1. a -> c
  "    b -> c
  "    => This should give an error, else a will be deleted.
  " 2. a -> b
  "    b -> c
  "    This should be okay, but basic sequential processing would give
  "    a -> c, and b is deleted - not at all what was asked for!
  " 3. a -> b
  "    b -> a
  "    This should be okay, but basic sequential processing would give
  "    a remains unchanged and b is deleted!!
  " So - first check that all destination files are unique.
  " If yes, then for all files that are changing, rename them to
  " <fileIndex>_GOING_TO_<newName>
  " Then finally rename them to <newName>.

  " Check for duplicates
  let sortedModifiedFileList = sort(copy(modifiedFileList))
  let lastFile = ''
  let duplicatesFound = []
  for thisFile in sortedModifiedFileList
    if thisFile == lastFile
      let duplicatesFound += [ thisFile ]
    end
    let lastFile = thisFile
  endfor
  if len(duplicatesFound)
    echom "Found the following duplicate files:"
    for f in duplicatesFound
      echom f
    endfor
    echoe "Fix the duplicates and try again"
    return
  endif

  " Rename to unique intermediate names
  let uniqueIntermediateNames = []
  let i = 0
  while i < numOriginalFiles
    if b:renamerOriginalPathfileList[i] != modifiedFileList[i]
      if filewritable(b:renamerOriginalPathfileList[i])
        " let newName = substitute(modifiedFileList[i], escape(b:renamerDirectory.'/','/\'),'','')
        let newName = substitute(modifiedFileList[i], b:renamerDirectoryEscaped,'','')
        let newDir = fnamemodify(modifiedFileList[i], ':h')
        if !isdirectory(newDir) && exists('*mkdir')
          " Create the directory, or directories required
          call mkdir(newDir, 'p')
        endif
        if !isdirectory(newDir)
            echoe "Attempting to rename '".b:renamerOriginalPathfileList[i]."' to '".newName."' but directory ".newDir." couldn't be created!"
            " Continue anyway with the other files since we've already started renaming
        else
          " To allow moving files to other directories, slashes must be "escaped" in a special way
          let newName = substitute(newName, '\/', '_FORWSLASH_', 'g')
          let newName = substitute(newName, '\\', '_BACKSLASH_', 'g')
          let uniqueIntermediateName = b:renamerDirectory.'/'.i.'_GOING_TO_'.newName
          if rename(b:renamerOriginalPathfileList[i], uniqueIntermediateName) != 0
            echoe "Unable to rename '".b:renamerOriginalPathfileList[i]."' to '".uniqueIntermediateName."'"
            " Continue anyway with the other files since we've already started renaming
          else
            let uniqueIntermediateNames += [ uniqueIntermediateName ]
          endif
        endif
      else
        echom "File '".b:renamerOriginalPathfileList[i]."' is not writable and won't be changed"
      endif
    endif
    let i += 1
  endwhile

  " Do final renaming
  for intermediateName in uniqueIntermediateNames
    let newName = b:renamerDirectory.'/'.substitute(intermediateName, '.*_GOING_TO_', '', '')
    let newName = substitute(newName, '_FORWSLASH_', '/', 'g')
    let newName = substitute(newName, '_BACKSLASH_', '\', 'g')
    if filereadable(newName)
      echoe "A file called '".newName."' already exists - cancelling rename!"
      " Continue anyway with the other files since we've already started renaming
    else
      if rename(intermediateName, newName) != 0
        echoe "Unable to rename '".intermediateName."' to '".newName."'"
        " Continue anyway with the other files since we've already started renaming
      endif
    endif
  endfor

  let &report=oldRep
  let &sc = save_sc

  call renamer#start(0, -1, b:renamerDirectory)

endfunction

function! s:ChangeDirectory() "{{{1
  let line = getline('.')
  exec "let isLinkedDir = line =~ '" . s:linksTo . ".*\/$'"
  if isLinkedDir
    " Save the line for the directory being left
    exec "let b:renamerSavedDirectoryLocations['".b:renamerDirectory."'] = ".line('.')

    " Get link destination in the case of linked dirs
    let b:renamerDirectory = simplify(substitute(line, '.*'.s:linkPrefix, '', ''))
  else
    let line = substitute(line, ' *'.s:hashes.'.*', '', '')
    if line !~ '\/$'
      " Not a directory, ignore
      normal! j0
      return
    else
      " Save the line for the directory being left
      exec "let b:renamerSavedDirectoryLocations['".b:renamerDirectory."'] = ".line('.')
      if line =~ '^#'
        let b:renamerDirectory = simplify(b:renamerDirectory.'/'.substitute(line, '^#\{1,} *', '', ''))
      else
        let b:renamerDirectory = b:renamerDirectory.'/'.line
      endif
    endif
  endif

  " Tidy up the path (remove trailing slashes etc)
  let b:renamerDirectory = s:Path(b:renamerDirectory)

  let lineForNewBuffer = -1
  if exists("b:renamerSavedDirectoryLocations['".b:renamerDirectory."']")
    let lineForNewBuffer = b:renamerSavedDirectoryLocations[b:renamerDirectory]
    unlet b:renamerSavedDirectoryLocations[b:renamerDirectory]
  endif

  " We must also change the current directory, else it can happen
  " that we are trying to rename the directory we're currently in,
  " which is never going to work
  exec 'cd "'.b:renamerDirectory . '"'

  " Now update the display for the new directory
  call renamer#start(0, lineForNewBuffer, b:renamerDirectory)
endfunction

function! s:DeleteEntry() "{{{1
  let lineNum = line('.')
  let entry = getline(lineNum)
  " Remove leading comment chars
  let entry = substitute(entry, '^# *', '', '')
  " Remove trailing comment chars
  let entry = substitute(entry, ' *'.s:hashes.'.*', '', '')
  " Remove trailing slash on dirs
  let entry = substitute(entry, '\/$', '', '')
  " Add path
  let entryPath = b:renamerDirectory.'/'.substitute(entry, '\/$', '', '')

  " Try to find the entry in the starting lists.  If not found there's been a mistake
  let i = 0
  let listIndex = -1
  while i < len(b:renamerOriginalPathfileList)
    if entryPath == b:renamerOriginalPathfileList[i]
      let listIndex = i
      let listName = 'b:renamerOriginalPathfileList'
      break
    endif
    let i += 1
  endwhile
  if listIndex == -1
    let i = 0
    while i < len(b:renamerNonWriteableEntries)
      if entryPath == b:renamerNonWriteableEntries[i]
        let listIndex = i
        let listName = 'b:renamerNonWriteableEntries'
        break
      endif
      let i += 1
    endwhile
    if listIndex == -1
      echoe "Renamer: DeleteEntry couldn't find entry '".entry."'"
      return
    endif
  endif

  " Deletion code in netrw.vim can't easily be reused, so it's reproduced here.
  " Thanks to Bram, Chip Campbell etc!
  let type = 'file'
  if isdirectory(entryPath)
    let type = 'directory'
  endif
  echohl Statement
  call inputsave()
  let ok = input("Confirm deletion of ".type." '".entryPath."' ","[{y(es)},n(o)] ")
  call inputrestore()
  echohl NONE
  if ok == ''
    let ok = 'no'
  endif
  let ok= substitute(ok,'\[{y(es)},n(o)]\s*','','e')
  if ok == '' || ok =~ '[yY]'
    if type == 'directory'
      " Try deleting with rmdir
      call system('rmdir "'.entryPath.'"')
      if v:shell_error != 0
        " Failed, try vim's own function
        let errcode = delete(entryPath)
        if errcode != 0
          " Failed - error message
          echoe "Unable to delete directory '".entryPath."' - this script is limited to only delete empty directories"
          return
        endif
      endif
    else
      " Try deleting the file
      let errcode = delete(entryPath)
      if errcode != 0
        " Failed - error message
        echoe "Unable to delete file '".entryPath."'"
        return
      endif
    endif

    " Restart renamer to reset everything
    call renamer#start(0, lineNum, b:renamerDirectory)

  endif

endfunction

function! s:ToggleOriginalFilesWindow() "{{{1
  " Toggle the original files window
  if g:RenamerOriginalFileWindowEnabled == 0
    let g:RenamerOriginalFileWindowEnabled = 2 " 2 => create the window as well
    call s:CreateOriginalFileWindow(0, b:renamerMaxWidth, b:renamerEntryDisplayText)
  else
    wincmd h
    bdelete
    let g:RenamerOriginalFileWindowEnabled = 0
  endif
endfunction

function! s:Refresh() "{{{1
  " Update the display in case directory contents have changed outside vim
  call renamer#start(0, -1, b:renamerDirectory)
endfunction

" Support functions        {{{1

function! s:Path(p)       "{{{2
" Make sure a path has proper form
  if has("dos16") || has("dos32") || has("win16") || has("win32") || has("os2")
    let returnPath=substitute(a:p,'\\','/','g')
  else
    let returnPath=a:p
  endif
  " Remove trailing slashes (note - only from end of list, not from the end of
  " lines followed by return characters within the list)
  let returnPath=substitute(returnPath, '/*$', '', '')
  return returnPath
endfunction

function! s:SID()         "{{{2
  " Return the SID number for a file
  return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfun
let s:sid = s:SID()

function! s:GetHighlightString(group) "{{{2
  " Given a named highlight group, return the string representing the settings for it
  if !hlexists(a:group)
    echoe "Error in GetHighlightString: no highlight group exists called " . a:group
    return ''
  endif

  let hlid = hlID(a:group)
  let synid = synIDtrans(hlid)
  let result = ''
  for mode in ['term', 'cterm', 'gui']
    for what in ['fg', 'bg']
      let attr = synIDattr(synid, what, mode)
      if attr != '' && attr != -1
        let result .= ' ' . mode . what . '=' . attr
      endif
    endfor
    for what in ['bold', 'italic', 'reverse', 'inverse', 'underline', 'undercurl']
      let attr = synIDattr(synid, what, mode)
      if attr == 1
        " Don't bother supporting multiple options, like term=bold,underline
        let result .= ' ' . mode . '=' . what
      endif
    endfor
  endfor
  return result
endfunction

function! s:AddBoldToHighlightGroupDefinition(string) "{{{2
  " Function to add the keyword "bold" where appropriate to a highlight definition string
  let string = a:string
  let string .= ' gui=bold'
  if string =~ '\<term=' && string !~ '\<term=bold'
    let string = substitute(string, '\<term=', 'term=bold,', '')
  else
    let string .= ' term=bold'
  endif
  if string =~ '\<cterm=' && string !~ '\<cterm=bold'
    let string = substitute(string, '\<cterm=', 'cterm=bold,', '')
  else
    let string .= ' cterm=bold'
  endif
  return string
endfunction


function! s:ValidatePathfile(dir, line, lineNo) "{{{2
  " Validate characters provided
  " In theory we could/should match against \f, which is controlled by the
  " option 'isfname' - but in reality - it's not an option.  For example,
  " by default on Windows, isfname includes colon - in order for 'gf' to work
  " on paths like c:\windows\file.txt - but colon is not a valid character in
  " an actual file name, so it's misleading.  Also, ampersand is a valid
  " character in a Windows filename - but I can't seem to set it easily.
  " The simpler option is to use validChars...
  " Test the whole string first
  let param = renamer#platform#params()
  if match(a:line, '^'.validChars.'\+$') == -1
    " Be specific about which char(s) is/are invalid
    let invalidName = 0
    for c in split(a:line, '\zs')
      let validChar = (match(c, param.validChars) != -1) || (match(c, param.separator) != -1)
      if !validChar
        echom printf("Invalid character '%s' in name '%s' on line %s", c, a:line, a:lineNo)
        let invalidName = 1
      endif
    endfor
    if invalidName
      return 1
    endif
  endif

  " Validate filename
  let filename = fnamemodify(a:line, ':t')
  if ! s:IsValidPattern(filename, param.fileIllegalPatterns, param.fileIllegalPatternsGuide, a:lineNo)
    return 1
  endif

  " Validate pathfile
  let pathfile = a:dir . '/' . a:line
  if ! s:IsValidPattern(pathfile, param.filePathIllegalPatterns, param.filePathIllegalPatternsGuide, a:lineNo)
    return 1
  endif

  return 0
endfunction

function! s:IsValidPattern(string, patterns, correspondingMsgs, lineNo) "{{{2
  " Given a regex with multiple OR'd sub-patterns, check which ones match a string,
  " and print the corresponding messages for each match
  " patterns should be of the form '\v(A)|(B)|(C)....'
  let i = 0
  let invalid = 0

  let matchlist = matchlist(a:string, a:patterns)
  let submatches = matchlist[1:] " Strip the full match and the one
  while i < len(submatches)
    if submatches[i] != ''
      echom "Error: the name '".a:string."' on line ".a:lineNo." contains ".a:correspondingMsgs[i]
      let invalid = 1
    endif
    let i += 1
  endwhile
  if invalid
    return 0
  endif
  return 1
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

