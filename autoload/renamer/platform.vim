scriptencoding utf-8

if has('dos16')||has('dos32')||has('win16')||has('win32')||has('win64')||has('win32unix')||has('win95')
  " With info from http://support.grouplogic.com/?p=1607 and
  " http://en.wikipedia.org/wiki/Filename
  let s:validChars = '[][a-zA-Z0-9`~!@#$%^&()_+={};'',. -]'
  let s:separator = '[\\/]'
  let s:fileIllegalPatterns =  '\v( $)|(\.$)|(.{256})|^(com[1-9]|lpt[1-9]|con|nul|prn)$'
  let s:fileIllegalPatternsGuide = [ 'a space at the end of the filename', 'a period at the end of the filename', 'more than 255 characters', 'a prohibited filename for DOS/Windows']
  let s:filePathIllegalPatterns =  '\v(.{261})'
  let s:filePathIllegalPatternsGuide = [ 'more than 260 characters']

elseif has('macunix') " May well have 'mac' as well, but this one is more permissive
  let s:validChars = '[^:]'
  let s:separator = '[/]'
  let s:fileIllegalPatterns =  '\v(^\.)|(.{256})'
  let s:fileIllegalPatternsGuide = [ 'a period as the first character', 'more than 255 characters']
  let s:filePathIllegalPatterns =  'There are no illegal filepath patterns for OS X on macs:'
  let s:filePathIllegalPatternsGuide = []

elseif has('unix')
  let s:validChars = '.'  " No illegal characters
  let s:separator = '[/]'
  let s:fileIllegalPatterns =  '\v(.{256})'
  let s:fileIllegalPatternsGuide = [ 'more than 255 characters']
  let s:filePathIllegalPatterns =  'There are no illegal filepath patterns on unix'
  let s:filePathIllegalPatternsGuide = []

elseif has('mac')
  let s:validChars = '[^:]'
  let s:separator = '[/]'
  let s:fileIllegalPatterns =  '\v(.{32})'
  let s:fileIllegalPatternsGuide = ['more then 31 characters']
  let s:filePathIllegalPatterns =  'There are no illegal filepath patterns for OS 9 on macs:'
  let s:filePathIllegalPatternsGuide = []

else
  " POSIX defaults
  let s:validChars = '[A-Za-z0-9._-]'
  let s:separator = '[/]'
  let s:fileIllegalPatterns =  '\v(.{256})'
  let s:fileIllegalPatternsGuide = [ 'more than 255 characters']
  let s:filePathIllegalPatterns =  'There are no illegal filepath patterns for the default charset'
  let s:filePathIllegalPatternsGuide = []
endif

lockvar s:

function! renamer#platform#params()
  return s:
endfunction
