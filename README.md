# renamer.vim
This is a forked version of [renamer.vim](http://www.vim.org/scripts/script.php?script_id=1721)

# Basic Usage

Show a list of file names in a directory, rename then in the vim buffer using
vim editing commands, then have vim rename them on disk

Start the plugin with the command `:Renamer`

# Details

Renaming a single file is easily done via an operating system file explorer,
the vim file explorer (netrw.vim), or the command line.  When you want to
rename a bunch of files, especially when you want to do a common text
manipulation to those file names, this plugin may help.  It shows you all the
files in the current directory, and lets you edit their names in the vim
buffer.  When you're ready, issue the command `:Ren` to perform the mass
rename.

The intention is to rename files in the same directory, but relative
paths can be specified to move files around - provided the destination
directories exist

# Install Details

The usual - drop this file into your `$HOME/.vim/plugin` directory (unix)
or `$HOME/vimfiles/plugin` directory (Windows), etc.

Use the commands defined below to invoke the functionality (or redefine them
elsewhere to what you want), and set the User Configurable Variables as
desired.

# Possible Improvements

- When starting renamer from an already running instance of vim, the cursor
  begins in the original files window if that is enabled.  The reason for
  this related to the fact that I couldn't get the window sizing to work
  when renamer was invoked directly from the command line unless the cursor
  stayed in the left window initially.  The way it is suits me, but if you
  can help fix the problem, let me know.
- Add different ways of sorting files, eg case insensitive, by date, size etc
- Rationalise the code so directories and files use the same arrays indexed
  by type of file.
- Refactor to make functions smaller
- Add installation instructions for Windows 7?  Or better still, updgrade
  my Windows 7 box to XP :)
- Make a suggestion!
