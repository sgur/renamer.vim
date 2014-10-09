# Installing As Windows XP Right Click Menu Option:

To add running this script on a directory as a right click menu option,
in Windows XP, if you are confident working with the registry, do as
follows **(NOTE - THESE INSTRUCTIONS CAME FROM THE WEB AND WORKED FOR
ME, BUT I CAN'T GUARANTEE THEY ARE 100% SAFE)**:

- Run the Registry Editor (REGEDIT.EXE).
- Open `My Computer\HKEY_CLASSES_ROOT\Directory` and click on the
  sub-item 'shell'.
- Select New from the Edit menu, and then select Key.
- Here, type VimRenamer and press Enter.
- Double-click on the (default) value in the right pane, and type the name
  to see in the meny, eg Rename Files with Vim Renamer, and press Enter.
- Highlight the new key in the left pane, select New from the Edit menu,
  and then select Key again.
- Type the word Command for the name of this new key, and press Enter.
- Double-click on the (default) value in the right pane, and type the full
  path and filename to vim, along with the command as per the following
  example line:
  ```
  "C:\Program Files\vim\vim70\gvim.exe" -c "cd %1|Renamer"
  ```
  Change the path as required, press Enter when done.
- Close the Registry Editor when finished.
