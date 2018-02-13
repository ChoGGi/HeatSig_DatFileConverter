#NoEnv
#KeyHistory 0
#NoTrayIcon
#SingleInstance Off
SetBatchLines -1
ListLines Off
AutoTrim Off
Process Priority,,A

Global sPtr := (A_PtrSize ? "Ptr" : "UInt"),crypt32 := LoadLibrary("crypt32")

;PID of script...
iScript_PID := DllCall("GetCurrentProcessId")
;get script filename
SplitPath A_ScriptName,,,,sName
;get settings filename
sProg_Ini := A_ScriptDir "\" sName ".ini"

;loop through input file(s)
If A_Args[1]
  {
  For iIndex,sInputFile in A_Args
    {
    Loop Files,%sInputFile%,F
      fInputFiles(A_LoopFileLongPath)
    }
  ExitApp
  }
;no files dropped on exe so we open GUI
Else
  {
  ;we just need the one copy running so check for pid
  IniRead iRunning,%sProg_Ini%,Settings,Running,0
  If iRunning
    {
    WinActivate ahk_pid %iRunning%
    ExitApp
    }
  OnExit GuiClose
  GoSub lStartGUI
  }

;end of init section
Return

Global sHeatSigFiles,sSteamLoc,sWorkshopFiles,ScanSteamWorkshop,Editor,sSelectedTreeText

lStartGUI:
  If !FileExist(sProg_Ini)
    {
    sText := "[Settings]`r`n`r`n;Leave blank to use built-in editor`r`n;R:\SciTe\SciTeStart.exe`r`n;Notepad.exe`r`nEditor=`r`n`r`n;Ask before recycling files`r`nDisableWarnings=0`r`n`r`n;If you have added a bunch of friends to share saves, then it could be a long list`r`nScanSteamWorkshop=1`r`n`r`n;If you don't want it to refresh the view after deleting/converting files`r`nManualRefresh=0`r`n`r`n;Program running?`r`nRunning=0`r`n;Window position`r`nWinPos=0:0`r`n`r`n"
    FileAppend %sText%,%sProg_Ini%
    }
  IniWrite %iScript_PID%,%sProg_Ini%,Settings,Running
  IniRead Editor,%sProg_Ini%,Settings,Editor,%A_Space%
  IniRead DisableWarnings,%sProg_Ini%,Settings,DisableWarnings,0
  IniRead ScanSteamWorkshop,%sProg_Ini%,Settings,ScanSteamWorkshop,1
  IniRead ManualRefresh,%sProg_Ini%,Settings,ManualRefresh,0
  IniRead sWinPos,%sProg_Ini%,Settings,WinPos,0:0
  If sWinPos = :
    sWinPos := "0:0"
  sArray := StrSplit(sWinPos,":")
  iXPos := sArray[1]
  iYPos := sArray[2]
  ;keep GUI on screen
  If iYPos > %A_ScreenHeight%
    iYPos := A_ScreenHeight // 3
  If iXPos > %A_ScreenWidth%
    iXPos := A_ScreenWidth // 3

  ;Shamelessly borrowed/edited from Autohotkey help (tree/listview example)
  sHeatSigFiles := A_APPDATA "\Heat_Signature"
  sWorkshopFiles := fGetSteamLibraryPaths()

  iTreeViewWidth := 175
  ;iListViewWidth := 400 - iTreeViewWidth - 20

  Gui +LastFound +Resize +OwnDialogs

  oImageListID := IL_Create(2)
  IL_Add(oImageListID,"shell32.dll",4)
  IL_Add(oImageListID,sSteamLoc "\Steam.exe",0)

  Gui Add,Button,glButtonRefresh voButtonRefresh,&Refresh List
  Gui Add,Button,x+m glButtonEdit vosButtonEdit,&Edit Selected
  Gui Add,Button,x+m glButtonConvert voButtonConvert,&Convert Selected
  Gui Add,Button,x+m glButtonRecycleOld voButtonRecycleOld,&Recycle .old
  Gui Add,Checkbox,x+m ym5 Checked%ScanSteamWorkshop% glCheckboxScanSteam voCheckboxScanSteam,&Scan Workshop
  Gui Add,Checkbox,x+m Checked%ManualRefresh% glCheckboxManRefresh voCheckboxManRefresh,&Manual Refresh
  Gui Add,TreeView,y+15 r20 glMyTreeView voTreeView1 ImageList%oImageListID% w%iTreeViewWidth%
  Gui Add,ListView,x+m r20 glMyListView voListView1 w20,Name|Modified|File
  ;toolips for elements
  oButtonRefresh_TT := "Refreshes view"
  osButtonEdit_TT := "Edits first selected file"
  oButtonRecycleOld_TT := "Any .dat.old files in current folder are sent to the Recycle Bin"
  oButtonConvert_TT := "Converts selected files`nUse Ctrl+Click to select multiple files`n`nWARNING: If you select name.dat and name.dat.txt:`nThis will convert from the top of the list down (likely overwriting the wrong file)!"
  oCheckboxScanSteam_TT := "Adds files from friends (from Steam Workshop)"
  oCheckboxManRefresh_TT := "Only refresh file list when you click Refresh List"
  oListView1_TT := "Double click to Edit or Decode/Encode`nDouble right-click to Recycle."

  iCol2Width := 105
  ;LV_ModifyCol(1, iListViewWidth - iCol2Width + 120)
  LV_ModifyCol(1, iCol2Width + 120)
  LV_ModifyCol(2, iCol2Width)
  LV_ModifyCol(3, 0)

  Gui Add,StatusBar,vsStatusbar
  SB_SetParts(60,85)

  fPopulateTreeView()
  sTreeItem := fSelectTreeItem()
  fPopulateListView(sTreeItem)

  Gui Show,w570 x%iXPos% y%iYPos%,%sName%: %sHeatSigFiles%
  ;for tooltips
  OnMessage(0x200,"WM_MOUSEMOVE")
Return

lMyTreeView:
  sTreeItem := fSelectTreeItem()
  fPopulateListView(sTreeItem)
Return

lButtonRefresh:
  sTreeItem := fSelectTreeItem()
  fPopulateTreeView(sTreeItem)
  Sleep 100
  fPopulateListView(sTreeItem)
Return

lButtonRecycleOld:
  StatusBarGetText sCurrentDir,3
  If DisableWarnings
    FileRecycle %sCurrentDir%\*.dat.old
  Else
    {
    MsgBox 4097,Send to Recycle Bin?,Recycle all .dat.old files in current folder?
    IfMsgBox OK
      FileRecycle %sCurrentDir%\*.dat.old
    }
  If !ManualRefresh
    GoSub lButtonRefresh
Return

lButtonConvert:
  iRowNumber := 0
  Loop
    {
    iRowNumber := LV_GetNext(iRowNumber)
    If !iRowNumber
      Break
    LV_GetText(sSelectedFile,iRowNumber,3)
    fInputFiles(sSelectedFile)
    }
  If !ManualRefresh
    GoSub lButtonRefresh
Return

lCheckboxScanSteam:
  ScanSteamWorkshop := fBoolToggle(ScanSteamWorkshop)
  IniWrite %ScanSteamWorkshop%,%sProg_Ini%,Settings,ScanSteamWorkshop
  fPopulateTreeView()
Return

lCheckboxManRefresh:
  ManualRefresh := fBoolToggle(ManualRefresh)
  IniWrite %ManualRefresh%,%sProg_Ini%,Settings,ManualRefresh
Return

lButtonEdit:
  LV_GetText(sSelectedFile,LV_GetNext(),3)
  SplitPath sSelectedFile,,sOutDir,sExt,sOutNameNoExt
  fStartEditor(sOutDir "\",sOutNameNoExt,"." sExt)
Return

GuiSize:
  If A_EventInfo = 1
    Return
  GuiControl Move,oTreeView1, % "H" (A_GuiHeight - 76) "X" (10)
  GuiControl Move,oListView1, % "H" (A_GuiHeight - 76) "W" (A_GuiWidth - iTreeViewWidth - 40) "X" (iTreeViewWidth + 20)
Return

lMyListView:
  ;skip if not clicking on a file
  If (A_EventInfo < 1 || A_GuiEvent != "DoubleClick" && A_GuiEvent != "R")
    Return

  LV_GetText(sClickedFile,A_EventInfo,3)
  SplitPath sClickedFile,sOutFileName,sOutDir,sExt,sOutNameNoExt

  ;get a list of files beforehand
  Loop Files,%sOutDir%\*.*
    sFileListB .= A_LoopFileName

  ;dbl click to decode/edit or encode
  If A_GuiEvent = DoubleClick
    {
    If !Editor
      fEditorGUI(sOutDir "\",sOutNameNoExt,"." sExt)
    Else
      {
      sNewExt := fInputFiles(sClickedFile)
      If sNewExt
        fStartEditor(sOutDir "\",sOutNameNoExt,sNewExt)
      }
    }
  ;dbl right click to recycle
  Else If A_GuiEvent = R
    {
    If DisableWarnings
      FileRecycle %sClickedFile%
    Else
      {
      MsgBox 4097,Send to Recycle Bin?,Recycle %sOutFileName%?
      IfMsgBox OK
        FileRecycle %sClickedFile%
      }
    }
  ;get a list of files after
  Loop Files,%sOutDir%\*.*
    sFileListA .= A_LoopFileName
  ;only refresh list if file added
  If (sFileListA != sFileListB && !ManualRefresh)
    GoSub lButtonRefresh
Return

fStartEditor(sDir,sFile,sExt)
  {
  If !Editor
    fEditorGUI(sDir,sFile,sExt)
  Else
    Run %Editor% "%sDir%%sFile%%sExt%"
  }

GuiEscape:
GuiClose:
  WinGetPos iXPosT,iYPosT
  If iXPosT
    iXPos := iXPosT
  If iYPosT
    iYPos := iYPosT
  sWinPos := iXPos ":" iYPos
  If sWinPos != :
    IniWrite %sWinPos%,%sProg_Ini%,Settings,WinPos
  IniWrite 0,%sProg_Ini%,Settings,Running
ExitApp

lButtonClose:
oEditorWinGuiClose:
oEditorWinGuiEscape:
  Gui Destroy
  ;re-enable main win
  Gui 1:Default
  Gui +LastFound +OwnDialogs
  Gui -Disabled
  ;get a list of files after
  Loop Files,%sDirEditorGUI%\*.*
    sFileListA .= A_LoopFileName
  If (sFileListA != sFileListB && !ManualRefresh)
    GoSub lButtonRefresh
  WinSet Transparent,OFF
  WinActivate
Return

lFileEditor:
  GuiControl Enable,oButtonSaveFile
  GuiControl Enable,oButtonSaveDatFile
  GuiControl Enable,oButtonSaveFileAs
Return

lButtonSaveFileAs:
  Gui Submit,NoHide
  FileSelectFile sSelectedFile,S24,%oButtonSaveFileAs%,Save file as .txt or .dat,txt or dat (*.txt; *.dat)
  ;if user didn't cancel, etc
  If sSelectedFile
    {
    ;if .dat re-encode
    If SubStr(sSelectedFile,-3) = .dat
      fSaveEncodeText(sSelectedFile ".txt",oFileEditor)
    ;else overwrite old file
    Else
      {
      FileDelete %sSelectedFile%
      FileAppend %oFileEditor%,%sSelectedFile%
      }
    }
Return

lButtonSaveFile:
  Gui Submit,NoHide
  FileDelete %oButtonSaveFile%
  FileAppend %oFileEditor%,%oButtonSaveFile%
  GuiControl Disable,oButtonSaveFile
Return

lButtonSaveDatFile:
  Gui Submit,NoHide
  fSaveEncodeText(oButtonSaveDatFile,oFileEditor)
  GuiControl Disable,oButtonSaveDatFile
Return

oEditorWinGuiSize:
  If A_EventInfo = 1
    Return
  GuiControl Move,oFileEditor, % "H" (A_GuiHeight - 45) "W" (A_GuiWidth - 20)
Return

fEditorGUI(sDir,sFile,sExt)
  {
  Static oButtonClose
  Global sDirEditorGUI,sFileListB,oFileEditor,oButtonSaveFile,oButtonSaveDatFile,oButtonSaveFileAs
  ;disable mainwin
  WinSet Transparent,100
  Gui +Disabled
  ;get a list of files beforehand (to compare for new files)
  Loop Files,%sDir%\*.*
    sFileListB .= A_LoopFileName
  sDirEditorGUI := sDir

  FileRead sInputText,%sDir%%sFile%%sExt%
  If (sExt = ".dat" || sExt = ".old" && SubStr(sFile,-3) = ".dat")
    sInputText := fDecodeText(sInputText)

  Gui oEditorWin:Default
  Gui +LastFound +Resize +OwnDialogs
  oButtonSaveFile := (sExt = ".dat" ? sFile sExt ".txt"
    : sExt = ".old" ? sFile sExt ".txt"
    : sFile sExt)

  Gui Add,Button,xm ym glButtonSaveFile voButtonSaveFile,&Save as %oButtonSaveFile%
  oButtonSaveDatFile := (SubStr(sFile sExt,-7) = ".dat.txt" ? sFile
    : sExt = ".old" ? sFile sExt ".dat"
    : sExt = ".txt" ? sFile sExt ".dat"
    : sFile sExt)

  Gui Add,Button,x+m glButtonSaveDatFile voButtonSaveDatFile,&Save as %oButtonSaveDatFile%

  Gui Add,Button,x+m glButtonSaveFileAs voButtonSaveFileAs,&Save as...
  Gui Add,Button,xp+200 glButtonClose voButtonClose,&Close
  Gui Add,Edit,r30 xm w700 glFileEditor voFileEditor,%sInputText%

  oButtonSaveFile := sDir oButtonSaveFile
  oButtonSaveDatFile := sDir oButtonSaveDatFile ".txt"
  oButtonSaveFileAs := sDir sFile sExt

  Gui Show,,Editing %sDir%\%sFile%%sExt%
  ;focus on edit box
  GuiControl Focus,oFileEditor
  ;OnMessage(0x200, "WM_MOUSEMOVE")
  }

fBoolToggle(bBool)
  {
  If bBool
    Return 0
  Return 1
  }

fPopulateTreeView(sSelectedItem = 0)
  {
  TV_Delete()
  GuiControl -Redraw,oTreeView1
  SplashTextOn 200,25,%A_ScriptName%,Loading...
  fAddSubFoldersToTree(sHeatSigFiles,,1)
  If ScanSteamWorkshop
    {
    Loop Parse,sWorkshopFiles,`n,`r
      fAddSubFoldersToTree(A_LoopField)
    }
  SplashTextOff
  GuiControl +Redraw,oTreeView1
  If !sSelectedItem
    Return
  iItemID := 0
  Loop
    {
    iItemID := TV_GetNext(iItemID,"Full")
    If !iItemID
      Break
    TV_GetText(sItemText,iItemID)
    TV_GetText(sParentText,TV_GetParent(iItemID))
    iParentID := TV_GetParent(iItemID)
    TV_GetText(sGrandParentText,TV_GetParent(iParentID))
    ;found what we're looking for
    If (sParentText "\" sItemText = sSelectedTreeText
        || sGrandParentText "\" sParentText "\" sItemText = sSelectedTreeText)
      {
      TV_Modify(iItemID)
      Break
      }
    }
  }

;user folders or steam friend folders
fAddSubFoldersToTree(sFolder,iParentItemID := 0,bHSFiles := 0)
  {
  Loop Files,%sFolder%\*.*,D
    oTmp := (bHSFiles
      ? fAddSubFoldersToTree(A_LoopFileFullPath,TV_Add(A_LoopFileName,iParentItemID,"Icon1"),1)
      : fAddSubFoldersToTree(A_LoopFileFullPath,TV_Add(A_LoopFileName,iParentItemID,"Bold Icon2")))
  }

fSelectTreeItem()
  {
  TV_GetText(sSelectedItemText,TV_GetSelection())
  iParentID := TV_GetSelection()
  Loop
    {
    iParentID := TV_GetParent(iParentID)
    If !iParentID
      Break
    TV_GetText(sParentText, iParentID)
    sSelectedItemText := sParentText "\" sSelectedItemText
    }
    ;bold is a steam workshop folder
    If !TV_Get(TV_GetSelection(),"Bold")
      sSelectedFullPath := sHeatSigFiles "\" sSelectedItemText
    Else
      {
      ;loop through workshop folders till it matches
      ;if user has manually moved game to another steam library
      ;this may return older files
      Loop Parse,sWorkshopFiles,`n,`r
        {
        sDirPath := A_LoopField "\" sSelectedItemText
        If InStr(FileExist(sDirPath),"D")
          sSelectedFullPath := sDirPath
        }
      }
  If sSelectedItemText
    sSelectedTreeText := sSelectedItemText
  Return sSelectedFullPath
  }

fPopulateListView(sSelectedFullPath)
  {
  LV_Delete()
  GuiControl -Redraw,oListView1
  iFileCount := 0
  iTotalSize := 0

  Loop Files,%sSelectedFullPath%\*.*,F
    {
    sChkNameD := SubStr(A_LoopFileLongPath	,-7)
    sChkNameE := SubStr(A_LoopFileLongPath	,-3)
    If (sChkNameD = ".dat.txt" || sChkNameE = ".dat"
        || sChkNameD = ".dat.old" || sChkNameD = ".old.txt")
      {
      LV_Add("",A_LoopFileName,A_LoopFileTimeModified,A_LoopFileLongPath,A_LoopFileDir)
      iFileCount += 1
      iTotalSize += A_LoopFileSize
      }
    }
  GuiControl +Redraw,oListView1

  SB_SetText(iFileCount . " files", 1)
  SB_SetText(Round(iTotalSize / 1024, 1) . " KB", 2)
  SB_SetText(sSelectedFullPath, 3)
  }

;make a list of steam workshop folders that have HS id in them
fGetSteamLibraryPaths()
  {
  RegRead sSteamLoc,HKCU\Software\Valve\Steam,SteamPath
  sSteamLoc := StrReplace(sSteamLoc,"/","\")
  ;manually check/add hs workshop dir in steam dir
  If InStr(FileExist(sSteamLoc "\SteamApps\workshop\content\268130"),"D")
    sSteamLibraryPaths := sSteamLoc "\SteamApps\workshop\content\268130`n"

  ;check for other library folders
  If FileExist(sSteamLoc "\SteamApps\libraryfolders.vdf")
    {
    FileRead sLibraryFileTemp,%sSteamLoc%\SteamApps\libraryfolders.vdf
    sLibraryFileTemp := SubStr(sLibraryFileTemp,20)
    sLibraryFileTemp := SubStr(sLibraryFileTemp,1,-3)
    ;remove extra text, so it's just the paths
    Loop Parse,sLibraryFileTemp,`n,`r%A_Space%%A_Tab%
      {
      If (A_Index < 3 || !A_LoopField)
        Continue
      Regex = i)^"([1-9]|[1-9][0-9]|[1-9][0-9][0-9])"[ \t]+"
      sLoopTemp := RegExReplace(A_LoopField,Regex)
      sSteamLibraryTemp := SubStr(sLoopTemp,1,-1) "\steamapps\workshop\content\268130"
      ;now check/add if hs workshop dir exists
      If InStr(FileExist(sSteamLibraryTemp),"D")
        sSteamLibraryPaths .= sSteamLibraryTemp "`n"
      }
    sSteamLibraryPaths := SubStr(sSteamLibraryPaths,1,-1)
    sSteamLibraryPaths := StrReplace(sSteamLibraryPaths,"\\","\")
    }

  Return sSteamLibraryPaths
  }

fInputFiles(sInputFile)
  {
  sChkNameD := SubStr(sInputFile,-7)
  sChkNameE := SubStr(sInputFile,-3)
  FileRead sSaveGame,%sInputFile%

  ;decoded file we want to encode
  If (sChkNameD = ".dat.txt" || sChkNameD = ".old.txt")
    {
    If (InStr(sSaveGame,"SteamID") > 0 || InStr(sSaveGame,"FirstLaunch") > 0
        || InStr(sSaveGame,"<item>") > 0 || InStr(sSaveGame,"<Character>") > 0)
      {
      fSaveEncodeText(sInputFile,sSaveGame)
      Return False ;don't edit name
      }
    }
  ;encoded file we want to decode
  Else if (sChkNameE = ".dat" || sChkNameD = ".dat.old")
    {
    If (InStr(sSaveGame,"U3RlYW1JRCA9") > 0 || InStr(sSaveGame,"PENoYXJhY3Rlcj4=") > 0
        || InStr(sSaveGame,"PEl0ZW0+") > 0 || InStr(sSaveGame,"Rmlyc3RMYXVuY2gg") > 0)
      {
      sNewExt := fSaveDecodeText(sInputFile,sSaveGame)
      Return sNewExt ;edit name so we can open in editor
      }
    }
  Else ;abort with message
    {
    SplitPath sInputFile,sOutFileName
    MsgBox 4096,Filename Error,Filename Error: "%sOutFileName%" doesn't end in .dat, .dat.txt, .dat.old, or .old.txt!
    Return False
    }
  }

fDecodeText(sText)
  {
  sOutFile := ""
  ;loop through each line and decode it
  Loop Parse,sText,`n,`r
    {
    ;ignore the lines that don't need to be decoded
    If fCheckText(A_LoopField,A_Index)
      {
      sOutFile .= A_LoopField "`r`n"
      Continue
      }
    ;append decoded text to output file
    sOutFile .= fBase64_DecodeText(A_LoopField) "`r`n"
    }
  sOutFile := fRemoveBlank(sOutFile)
  Return sOutFile
  }

fSaveDecodeText(sInputFile,sSaveGame)
  {
  sOutFile := fDecodeText(sSaveGame)
  ;ahk doesn't overwrite so we delete old.dat.txt first
  FileDelete %sInputFile%.txt
  FileAppend %sOutFile%,%sInputFile%.txt
  ;for editing newly created file
  If SubStr(sInputFile,-7) = .dat.old
    Return ".old.txt"
  Return ".dat.txt"
  }

fEncodeText(sText)
  {
  sOutFile := ""
  Loop Parse,sText,`n,`r
    {
    If fCheckText(A_LoopField,A_Index)
      {
      sOutFile .= A_LoopField "`r`n"
      Continue
      }
    sOutFile .= fBase64_EncodeText(A_LoopField) "`r`n"
    }
  sOutFile := fRemoveBlank(sOutFile)
  Return sOutFile
  }

fSaveEncodeText(sInputFile,sSaveGame)
  {
  sOutFile := fEncodeText(sSaveGame)
  ;get filename for rename/replace
  sNewString := sInputFile
  sExt := (InStr(sNewString,".dat.txt") ? InStr(sNewString,".dat.txt")
        : InStr(sNewString,".old.txt"))
  sNewString := SubStr(sNewString,1,sExt) "dat"

  ;randomly rename old file to not overwrite
  ;If FileExist(sNewString ".old")
    ;FileMove %sNewString%,%sNewString%_%A_NowUTC%.old,1
  ;or just rename old save file overwriting any older file
  FileMove %sNewString%,%sNewString%.old,1
  FileDelete %sNewString%
  FileAppend %sOutFile%,%sNewString%
  }

;ignore the lines that don't need to be decoded
fCheckText(sText,iIndex)
  {
  If iIndex > 4
    Return 0
  If (sText = "<Header>" || sText = "" || InStr(sText,"TimeNumber = ") > 0
      || InStr(sText,"Encoded = 1") > 0 || RegExMatch(sText,"^Time\s=\s") > 0)
    Return 1
  }

;remove blank lines from end of var
fRemoveBlank(sText)
  {
  Loop
    {
    If SubStr(sText,-1) = "`r`n"
      sText := SubStr(sText,1,-2)
    Else
      Break
    }
  Return sText
  }

;https://github.com/ahkscript/libcrypt.ahk
fBase64_DecodeText(sText)
  {
	DllCall(crypt32.CryptStringToBinary, sPtr, &sText, "UInt", 0
	, "UInt", 0x1, sPtr, 0, "UInt*", OutLen, sPtr, 0, sPtr, 0)
	VarSetCapacity(Out, OutLen)

	DllCall(crypt32.CryptStringToBinary, sPtr, &sText, "UInt", 0
	, "UInt", 0x1, "Str", Out, "UInt*", OutLen, sPtr, 0, sPtr, 0)

	Return StrGet(&Out, OutLen, "UTF-8")
  }

fBase64_EncodeText(sText)
  {
	VarSetCapacity(Bin, StrPut(sText, "UTF-8"))
	DllCall(crypt32.CryptBinaryToString, sPtr, &Bin
	, "UInt", StrPut(sText, &Bin, "UTF-8")-1
  , "UInt", 0x40000001, sPtr, 0, "UInt*", PcchString)

	VarSetCapacity(Out, PcchString * (1+A_IsUnicode))
	DllCall(crypt32.CryptBinaryToString, sPtr, &Bin
	, "UInt", StrPut(sText, &Bin, "UTF-8")-1
  , "UInt", 0x40000001, "Str", Out, "UInt*", PcchString)

	Return Out
  }

;from ahk manual
;GUI Example: Display context-senstive help (via ToolTip)
WM_MOUSEMOVE()
  {
  Static CurrControl,PrevControl,_TT
  CurrControl := A_GuiControl
  If (CurrControl != PrevControl && !InStr(CurrControl, " "))
    {
    ToolTip
    SetTimer DisplayToolTip,1000
    PrevControl := CurrControl
    }
  Return

  DisplayToolTip:
    SetTimer DisplayToolTip,Off
    ToolTip % %CurrControl%_TT
    SetTimer RemoveToolTip,50000 ;don't like tooltips that disappear quickly...
  Return

  RemoveToolTip:
    SetTimer RemoveToolTip,Off
    ToolTip
  Return
  }

/*
by Bentschi
https://autohotkey.com/board/topic/90266-funktionen-loadlibrary-freelibrary-schnellere-dllcalls/
https://github.com/ahkscript/ASPDM/blob/master/Local-Client/Test_Packages/loadlibrary/Lib/loadlibrary.ahk
*/
LoadLibrary(sDllName)
  {
  Static ref := {}
  If (!(ptr := p := DllCall("LoadLibrary","str",sDllName,sPtr)))
    Return 0
  ref[ptr,"count"] := (ref[ptr]) ? ref[ptr,"count"]+1 : 1
  p += NumGet(p+0,0x3c,"int")+24
  o := {_ptr:ptr,__delete:func("FreeLibrary"),_ref:ref[ptr]}
  If (NumGet(p+0,(A_PtrSize=4) ? 92 : 108,"UInt")<1 || (ts := NumGet(p+0,(A_PtrSize=4) ? 96 : 112,"UInt")+ptr)=ptr || (te := NumGet(p+0,(A_PtrSize=4) ? 100 : 116,"UInt")+ts)=ts)
    Return o
  n := ptr+NumGet(ts+0,32,"UInt")
  Loop % NumGet(ts+0,24,"UInt")
    {
    If (p := NumGet(n+0,(A_Index-1)*4,"UInt"))
      {
      o[f := StrGet(ptr+p,"cp0")] := DllCall("GetProcAddress",sPtr,ptr,"astr",f,sPtr)
      If (Substr(f,0)==((A_IsUnicode) ? "W" : "A"))
        o[Substr(f,1,-1)] := o[f]
      }
    }
  Return o
  }
