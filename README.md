### Save file convertor for the game [Heat Signature](http://www.heatsig.com)
It's a fun little top down space based hijacking game, you should buy a copy

https://store.steampowered.com/app/268130/


### No warranty implied or otherwise!
##### Tested on v2017.09.26.1

```
If Heat Signature changes around how the files are saved you could lose your files, so always backup before doing anything.
I tried to make it safe, but you get what you pay for.
be wary using it if there's any update notes mentioning changes to saves
```

### How to:
```
run DatFileConverter.exe
double click to decode/encode, double right-click to send file to recycle bin.
```
### DatFileConverter.ini:
```
Change the default editor
Stop it from asking you everytime you send a file to the recycle bin
Stop it from scanning Steam workshop files (from other people)
```
### Save files:
```
Save files are located in %APPDATA%\Heat_Signature
Characters are in "Galaxy 1\Characters" (or 2 or 3)
Retired items/Captured characters are in "Workshop" folder
```
### Misc:
```
You can also drag and drop dat/txt files on the exe to convert without GUI
*  Drop save.dat on exe
*  Edit save.dat.txt file
*  Drop save.dat.txt file on exe
*  Start game
You can drop both dat and txt files at the same time.



Uses base64 code from https://github.com/ahkscript/libcrypt.ahk
```
