#NoEnv
#NoTrayIcon
;#SingleInstance Force
#SingleInstance Off
#KeyHistory 0
SetBatchLines -1
Process Priority,,A
ListLines Off

;no files dropped on exe so we open GUI
If %0% = 0
  GoSub StartGUI
Else ;loop through input file(s)
  {
  Loop %0%
    {
    Loop % %A_Index%,1
      {
      If (InStr(FileExist(A_LoopFileLongPath),"D") = 0)
        InputFiles(A_LoopFileLongPath)
      }
    }
  ExitApp
  }
Return

StartGUI:

  Script_Name := A_ScriptDir "\" SubStr(A_ScriptName,1,-3) "ini"
  IniRead Editor,%Script_Name%,Settings,Editor,Notepad.exe
  IniRead DisableWarnings,%Script_Name%,Settings,DisableWarnings,False
  IniRead ScanSteamWorkshop,%Script_Name%,Settings,ScanSteamWorkshop,True

  ;Shamelessly borrowed/edited from Autohotkey help (tree/listview example)

  TreeRoots := A_APPDATA "\Heat_Signature`r`n"
  If (ScanSteamWorkshop = "True")
    TreeRoots .= getSteamLibraryPaths()
  Else
    TreeRoots := RemoveBlank(TreeRoots)

  TreeViewWidth := 175
  ListViewWidth := 400 - TreeViewWidth - 20

  Gui +Resize

  ImageListID := IL_Create(5)
  Loop 5
    IL_Add(ImageListID, "shell32.dll", A_Index)
  Gui Add,Button,gButtonRefresh vButtonRefresh,&Refresh List
  Gui Add,Button,xp+80 gButtonEdit vButtonEdit,&Edit Selected
  Gui Add,Text,xp+80 ym+5 vInfoText,Double click to Decode/Encode, Double right-click to Recycle.
  Gui Add,TreeView,y+15 vMyTreeView r20 w%TreeViewWidth% gMyTreeView ImageList%ImageListID%
  Gui Add,ListView,-Multi gListViewAction vMyListView r20 w%ListViewWidth% x+10,Name|Modified|Path

  Col2Width := 100
  LV_ModifyCol(1, ListViewWidth - Col2Width + 120)
  LV_ModifyCol(2, Col2Width)
  LV_ModifyCol(3, 0)

  Gui Add,StatusBar
  SB_SetParts(60, 85)

  GuiControl -Redraw,MyTreeView
  SplashTextOn 200,25,%A_ScriptName%,Loading...
  Loop Parse,TreeRoots,`n,`r
    AddSubFoldersToTree(A_LoopField)
  SplashTextOff
  GuiControl +Redraw,MyTreeView

  Gui Show,,%A_APPDATA%\Heat_Signature
Return

AddSubFoldersToTree(Folder, ParentItemID = 0)
  {
  Loop Files,%Folder%\*.*,D
    AddSubFoldersToTree(A_LoopFileFullPath, TV_Add(A_LoopFileName, ParentItemID, "Icon4"))
  }

MyTreeView:
  LV_Delete()
  Loop Parse,TreeRoots,`n,`r
    MyTreeViewFunction(A_LoopField,False)
Return

Global SavedId,SavedItemText,SavedTreeRoot

MyTreeViewFunction(TreeRoot,SavedView)
  {
  If (SavedView = False)
    {
    If A_GuiEvent <> S
      Return
    TV_GetText(SelectedItemText,A_EventInfo)
    SavedItemText := SelectedItemText
    ParentID := A_EventInfo
    SavedId := A_EventInfo
    }
  Else
    {
    SelectedItemText := SavedItemText
    ParentID := SavedId
    }

  Loop
    {
    ParentID := TV_GetParent(ParentID)
    If not ParentID
      Break
    TV_GetText(ParentText, ParentID)
    SelectedItemText := ParentText "\" SelectedItemText
    }

  SelectedFullPath := TreeRoot "\" SelectedItemText

  GuiControl -Redraw,MyListView
  FileCount := 0
  TotalSize := 0

  Loop Files,%SelectedFullPath%\*.*,F
    {
    CheckNameD := SubStr(A_LoopFileLongPath	,-7)
    CheckNameE := SubStr(A_LoopFileLongPath	,-3)
    If (CheckNameD = ".dat.txt" || CheckNameE = ".dat" || CheckNameD = ".dat.old")
      {
      LV_Add("",A_LoopFileName,A_LoopFileTimeModified,A_LoopFileLongPath)
      FileCount += 1
      TotalSize += A_LoopFileSize
      }
    }
  GuiControl +Redraw,MyListView

  SB_SetText(FileCount . " files", 1)
  SB_SetText(Round(TotalSize / 1024, 1) . " KB", 2)
  SB_SetText(SelectedFullPath, 3)
  }

ButtonRefresh:
  LV_Delete()
  Loop Parse,TreeRoots,`n,`r
    MyTreeViewFunction(A_LoopField,True)
Return

ButtonEdit:
  LV_GetText(SelectedFile,LV_GetNext(),3)
  Run %Editor% "%SelectedFile%"
Return

GuiSize:
  If A_EventInfo := 1
    Return
  GuiControl Move,MyTreeView, % "H" (A_GuiHeight - 76) "X" (10)
  GuiControl Move,MyListView, % "H" (A_GuiHeight - 76) "W" (A_GuiWidth - TreeViewWidth - 40) "X" (TreeViewWidth + 20)

Return

ListViewAction:
  ;skip if not clicking on a file
  If (A_EventInfo < 1 || A_GuiEvent != "DoubleClick" && A_GuiEvent != "R")
    Return

  LV_GetText(ClickedFile,A_EventInfo,3)
  SplitPath ClickedFile,OutFileName,OutDir,,OutNameNoExt

  ;dbl click to decode/edit or encode
  If (A_GuiEvent = "DoubleClick")
    {
    NewName := InputFiles(ClickedFile)
    If (NewName != False)
      Run %Editor% "%OutDir%\%OutNameNoExt%%NewName%"
    }
  ;dbl right click to recycle
  Else If (A_GuiEvent = "R")
    {
    If (DisableWarnings = "True")
      FileRecycle %ClickedFile%
    Else
      {
      MsgBox 4097,Send to Recycle Bin?,Recycle %OutFileName%?
      IfMsgBox OK
        FileRecycle %ClickedFile%
      }
    }
  GoSub ButtonRefresh
Return

GuiClose:
ExitApp

;make a list of steam workshop folders that have HS id in them
getSteamLibraryPaths()
  {
  RegRead SteamLoc,HKCU\Software\Valve\Steam,SteamPath
  SteamLoc := StrReplace(SteamLoc,"/","\")
  If InStr(FileExist(SteamLoc "\SteamApps\workshop\content\268130"),"D")
    SteamLibraryPaths := SteamLoc "\SteamApps\workshop\content\268130`n"
  If FileExist(SteamLoc "\SteamApps\libraryfolders.vdf")
    {
    FileRead LibraryFileTemp,%SteamLoc%\SteamApps\libraryfolders.vdf
    LibraryFileTemp := SubStr(LibraryFileTemp,20)
    LibraryFileTemp := SubStr(LibraryFileTemp,1,-3)

    Loop Parse,LibraryFileTemp,`n,`r%A_Space%%A_Tab%
      {
      If (A_Index < 3 || A_LoopField = "")
        Continue
      regex = i)^"([1-9]|[1-9][0-9]|[1-9][0-9][0-9])"[ \t]+"
      LoopTemp := RegExReplace(A_LoopField,regex)
      SteamLibraryTemp := SubStr(LoopTemp,1,-1) "\steamapps\workshop\content\268130"
      If InStr(FileExist(SteamLibraryTemp),"D")
        SteamLibraryPaths .= SteamLibraryTemp "`n"
      }
    SteamLibraryPaths := SubStr(SteamLibraryPaths,1,-1)
    SteamLibraryPaths := StrReplace(SteamLibraryPaths,"\\","\")
    }

  Return SteamLibraryPaths
  }

InputFiles(InputFile)
  {
  FileRead sSaveGame,%InputFile%
  CheckNameD := SubStr(InputFile,-7)
  CheckNameE := SubStr(InputFile,-3)

  If (CheckNameD = ".dat.txt") ;decoded file we want to encode
    {
    If (InStr(sSaveGame,"SteamID") > 0 || InStr(sSaveGame,"oEverythingGun") > 0 || InStr(sSaveGame,"Trait") > 0 || InStr(sSaveGame,"Character") > 0)
      {
      EncodeText(InputFile,sSaveGame)
      Return False
      }
    }
  Else if (CheckNameE = ".dat") ;encoded file we want to decode
    {
    If (InStr(sSaveGame,"SteamID") = 0 && InStr(sSaveGame,"oEverythingGun") = 0 && InStr(sSaveGame,"Trait") = 0 && InStr(sSaveGame,"Character") = 0)
      {
      NewName := DecodeText(InputFile,sSaveGame)
      Return NewName
      }
    }
  Else ;abort with message
    {
    SplitPath InputFile,OutFileName
    MsgBox 4096,Filename Error,Filename Error: "%OutFileName%" doesn't end in .dat or .dat.txt!
    Return False
    }
  }

DecodeText(InputFile,sSaveGame)
  {
  sOutFile := ""
  ;number of files at the start to skip
  If (InStr(sSaveGame,"Encoded") = 0 && InStr(sSaveGame,"TimeNumber") = 0)
    sWhichFile := 0 ;SharedData.dat
  Else If (InStr(sSaveGame,"Encoded") = 0 && InStr(sSaveGame,"TimeNumber") > 0)
    sWhichFile := 3 ;Progress.dat
  Else
    sWhichFile := 4 ;chars/items

  ;loop through each line and decode it
  Loop Parse,sSaveGame,`n,`r
    {
    ;ignore the lines that don't need to be decoded
    If (A_Index <= sWhichFile)
      {
      ;append text to output file
      sOutFile .= A_LoopField "`r`n"
      Continue
      }
    If (A_LoopField = "")
      {
      ;append newline to output file
      sOutFile .= "`r`n"
      Continue
      }
    ;append decoded text to output file
    sOutFile .= Base64_DecodeText(A_LoopField) "`r`n"
    }

  ;remove blank lines from end of file
  sOutFile := RemoveBlank(sOutFile)
  ;delete any old .dat.txt file so we create a new rather than append
  FileDelete %InputFile%.txt
  FileAppend %sOutFile%,%InputFile%.txt
  Return ".dat.txt"
  }

EncodeText(InputFile,sSaveGame)
  {
  sOutFile := ""
  If (InStr(sSaveGame,"SteamID") > 0 && InStr(sSaveGame,"PersonaName") > 0)
    sWhichFile := 0 ;SharedData.dat
  Else If (InStr(sSaveGame,"Encoded") = 0 && InStr(sSaveGame,"TimeNumber") > 0)
    sWhichFile := 3 ;Progress.dat
  Else
    sWhichFile := 4 ;chars/items

  Loop Parse,sSaveGame,`n,`r
    {
    If (A_Index <= sWhichFile)
      {
      sOutFile .= A_LoopField "`r`n"
      Continue
      }
    If (A_LoopField = "")
      {
      sOutFile .= "`r`n"
      Continue
      }

    sOutFile .= Base64_EncodeText(A_LoopField) "`r`n"
    }
  sOutFile := RemoveBlank(sOutFile)

  ;get filename for rename/replace
  sNewString := InputFile
  FoundPos := InStr(sNewString,".dat.txt")
  StringLeft sNewString,sNewString,%FoundPos%
  sNewString := sNewString "dat"

  ;randomly rename old file to not overwrite
  ;If FileExist(sNewString ".old")
    ;FileMove %sNewString%,%sNewString%_%A_NowUTC%.old,1
  ;or just rename old save file overwriting any older file
  FileMove %sNewString%,%sNewString%.old,1
  FileDelete %sNewString%
  FileAppend %sOutFile%,%sNewString%
  }

RemoveBlank(sOutFile)
  {
  Loop
    {
    TestLine := SubStr(sOutFile,-1)
    If (TestLine = "`r`n")
      sOutFile := SubStr(sOutFile,1,-2)
    Else
      Break
    }
  Return sOutFile
  }

;https://github.com/ahkscript/libcrypt.ahk
Base64_DecodeText(Text)
  {
	DllCall("Crypt32.dll\CryptStringToBinary", "Ptr", &Text, "UInt", StrLen(In)
	, "UInt", 0x1, "Ptr", 0, "UInt*", OutLen, "Ptr", 0, "Ptr", 0)
	VarSetCapacity(Out, OutLen)

	DllCall("Crypt32.dll\CryptStringToBinary", "Ptr", &Text, "UInt", StrLen(In)
	, "UInt", 0x1, "Str", Out, "UInt*", OutLen, "Ptr", 0, "Ptr", 0)

	Return StrGet(&Out, OutLen, "UTF-8")
  }

Base64_EncodeText(Text)
  {
	VarSetCapacity(Bin, StrPut(Text, "UTF-8"))
	DllCall("Crypt32.dll\CryptBinaryToString", "Ptr", &Bin
	, "UInt", StrPut(Text, &Bin, "UTF-8")-1, "UInt", 0x40000001, "Ptr", 0, "UInt*", Base64)

	VarSetCapacity(Out, Base64 * (1+A_IsUnicode))
	DllCall("Crypt32.dll\CryptBinaryToString", "Ptr", &Bin
	, "UInt", StrPut(Text, &Bin, "UTF-8")-1, "UInt", 0x40000001, "Str", Out, "UInt*", Base64)

	Return Out
  }
