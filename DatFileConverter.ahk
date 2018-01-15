#NoEnv
#KeyHistory 0
#NoTrayIcon
;#SingleInstance Force
#SingleInstance Off
SetBatchLines -1
ListLines Off
AutoTrim Off
Process Priority,,A

;no files dropped on exe so we open GUI
If !A_Args.Length()
  GoSub lStartGUI
Else ;loop through input file(s)
  {
  For iIndex,sInputFile in A_Args
    {
    Loop Files,%sInputFile%,F
      fInputFiles(A_LoopFileLongPath)
    }
  ExitApp
  }

Return

Global sHeatSigFiles,sSteamLoc,sWorkshopFiles,ScanSteamWorkshop,Editor,sSelectedTreeText

lStartGUI:
  ;PID of script...
  iScript_PID := DllCall("GetCurrentProcessId")
  ;get script filename
  SplitPath A_ScriptName,,,,sName
  ;get settings filename
  sProg_Ini := A_ScriptDir "\" sName ".ini"

  If !FileExist(sProg_Ini)
    {
    sText := "[Settings]`r`n`r`n;Leave blank to use built-in editor`r`n;R:\SciTe\SciTeStart.exe`r`n;Notepad.exe`r`nEditor=`r`n`r`n;Ask before recycling files`r`nDisableWarnings=0`r`n`r`n;If you have added a bunch of friends to share saves, then it could be a long list`r`nScanSteamWorkshop=1`r`n`r`n;If you don't want it to refresh the view after deleting/converting files`r`nManualRefresh=0`r`n`r`n;Window Position`r`nWinPos=0:0`r`n"
    FileAppend %sText%,%sProg_Ini%
    }
  IniRead Editor,%sProg_Ini%,Settings,Editor,%A_Space%
  IniRead DisableWarnings,%sProg_Ini%,Settings,DisableWarnings,0
  IniRead ScanSteamWorkshop,%sProg_Ini%,Settings,ScanSteamWorkshop,1
  IniRead ManualRefresh,%sProg_Ini%,Settings,ManualRefresh,0
  IniRead sWinPos,%sProg_Ini%,Settings,WinPos,0:0
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

  Gui Add,Button,glButtonRefresh vsButtonRefresh,&Refresh List
  Gui Add,Button,x+m glButtonEdit vsButtonEdit,&Edit Selected
  Gui Add,Button,x+m glButtonConvert vsButtonConvert,&Convert Selected
  Gui Add,Button,x+m glButtonRecycleOld vsButtonRecycleOld,&Recycle .old
  Gui Add,Checkbox,x+m ym5 Checked%ScanSteamWorkshop% glCheckboxScanSteam vsCheckboxScanSteam,&Scan Workshop
  Gui Add,Checkbox,x+m Checked%ManualRefresh% glCheckboxManRefresh vsCheckboxManRefresh,&Manual Refresh
  Gui Add,TreeView,y+15 r20 glMyTreeView vsMyTreeView ImageList%oImageListID% w%iTreeViewWidth%
  ;Gui Add,ListView,x+m r20 glMyListView vsMyListView w%iListViewWidth%,Name|Modified|File
  Gui Add,ListView,x+m r20 glMyListView vsMyListView w20,Name|Modified|File
  ;toolips for elements
  sButtonRefresh_TT := "Refreshes view"
  sButtonEdit_TT := "Edits first selected file"
  sButtonRecycleOld_TT := "Any .dat.old files in current folder are sent to the Recycle Bin"
  sButtonConvert_TT := "Converts selected files`nUse Ctrl+Click to select multiple files`n`nWARNING: If you select name.dat and name.dat.txt:`nThis will convert from the top of the list down (likely overwriting the wrong file)!"
  sCheckboxScanSteam_TT := "Adds files from friends (from Steam Workshop)"
  sCheckboxManRefresh_TT := "Only refresh file list when you click Refresh List"
  sMyListView_TT := "Double click to Edit or Decode/Encode`nDouble right-click to Recycle."

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

  Gui Show,w570 x%iXPos% y%iYPos%,%sHeatSigFiles%
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
  GuiControl Move,sMyTreeView, % "H" (A_GuiHeight - 76) "X" (10)
  GuiControl Move,sMyListView, % "H" (A_GuiHeight - 76) "W" (A_GuiWidth - iTreeViewWidth - 40) "X" (iTreeViewWidth + 20)
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
  WinGetPos iXPosT,iYPosT,,,ahk_pid %iScript_PID%
  If iXPosT
    iXPos := iXPosT
  If iYPosT
    iYPos := iYPosT
  sWinPos := iXPos ":" iYPos
  IniWrite %sWinPos%,%sProg_Ini%,Settings,WinPos
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
  WinActivate
  WinSet Transparent,OFF
Return

lFileEditor:
  GuiControl Enable,sButtonSaveFile
  GuiControl Enable,sButtonSaveDatFile
  GuiControl Enable,sButtonSaveFileAs
Return

lButtonSaveFileAs:
  Gui Submit,NoHide
  FileSelectFile sSelectedFile,S24,%sButtonSaveFileAs%,Save file as .txt or .dat,txt or dat (*.txt; *.dat)
  ;if user didn't cancel, etc
  If sSelectedFile
    {
    ;if .dat re-encode
    If SubStr(sSelectedFile,-3) = .dat
      fSaveEncodeText(sSelectedFile ".txt",sFileEditor)
    ;else overwrite old file
    Else
      {
      FileDelete %sSelectedFile%
      FileAppend %sFileEditor%,%sSelectedFile%
      }
    }
Return

lButtonSaveFile:
  Gui Submit,NoHide
  FileDelete %sButtonSaveFile%
  FileAppend %sFileEditor%,%sButtonSaveFile%
  GuiControl Disable,sButtonSaveFile
Return

lButtonSaveDatFile:
  Gui Submit,NoHide
  fSaveEncodeText(sButtonSaveDatFile,sFileEditor)
  GuiControl Disable,sButtonSaveDatFile
Return

oEditorWinGuiSize:
  If A_EventInfo = 1
    Return
  GuiControl Move,sFileEditor, % "H" (A_GuiHeight - 45) "W" (A_GuiWidth - 20)
Return

fEditorGUI(sDir,sFile,sExt)
  {
  Global sDirEditorGUI,sFileListB,sFileEditor,sButtonSaveFile,sButtonSaveDatFile,sButtonSaveFileAs,sButtonClose
  ;disable mainwin
  WinSet Transparent,100
  Gui +Disabled
  ;get a list of files beforehand
  Loop Files,%sDir%\*.*
    sFileListB .= A_LoopFileName
  sDirEditorGUI := sDir

  FileRead sInputText,%sDir%%sFile%%sExt%
  If sExt = .dat
    sInputText := fDecodeText(sInputText)
  Else If sExt = .old
    {
    If SubStr(sFile,-3) = .dat
      sInputText := fDecodeText(sInputText)
    }

  Gui oEditorWin:New,+LastFound +Resize +OwnDialogs,Editing %sDir%\%sFile%%sExt%
  sButtonSaveFile := (sExt = ".dat" ? sFile sExt ".txt"
    : sExt = ".old" ? sFile sExt ".txt"
    : sFile sExt)

  Gui Add,Button,xm ym glButtonSaveFile vsButtonSaveFile,&Save as %sButtonSaveFile%
  sButtonSaveDatFile := (SubStr(sFile sExt,-7) = ".dat.txt" ? sFile
    : sExt = ".old" ? sFile sExt ".dat"
    : sExt = ".txt" ? sFile sExt ".dat"
    : sFile sExt)

  Gui Add,Button,x+m glButtonSaveDatFile vsButtonSaveDatFile,&Save as %sButtonSaveDatFile%

  Gui Add,Button,x+m glButtonSaveFileAs vsButtonSaveFileAs,&Save as...
  Gui Add,Button,xp+200 glButtonClose vsButtonClose,&Close
  Gui Add,Edit,r30 xm w700 glFileEditor vsFileEditor,%sInputText%

  sButtonSaveFile := sDir sButtonSaveFile
  sButtonSaveDatFile := sDir sButtonSaveDatFile ".txt"
  sButtonSaveFileAs := sDir sFile sExt

  Gui Show
  ;OnMessage(0x200, "WM_MOUSEMOVE")
  }

fBoolToggle(bBool)
  {
  Return (bBool ? 0 : 1)
  }

fPopulateTreeView(sSelectedItem = 0)
  {
  TV_Delete()
  GuiControl -Redraw,sMyTreeView
  SplashTextOn 200,25,%A_ScriptName%,Loading...
  fAddSubFoldersToTree(sHeatSigFiles,,1)
  If ScanSteamWorkshop
    {
    Loop Parse,sWorkshopFiles,`n,`r
      fAddSubFoldersToTree(A_LoopField)
    }
  SplashTextOff
  GuiControl +Redraw,sMyTreeView
  If sSelectedItem
    {
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
  }

fAddSubFoldersToTree(sFolder,iParentItemID := 0,bHSFiles := 0)
  {
  Loop Files,%sFolder%\*.*,D
    {
    If bHSFiles
      fAddSubFoldersToTree(A_LoopFileFullPath,TV_Add(A_LoopFileName,iParentItemID,"Icon1"),1)
    Else ;use steam icon for workshop files (be nice to have a LV_geticon)
      fAddSubFoldersToTree(A_LoopFileFullPath,TV_Add(A_LoopFileName,iParentItemID,"Bold Icon2"))
    }
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
  GuiControl -Redraw,sMyListView
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
  GuiControl +Redraw,sMyListView

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
  ;check for other library dirs
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
  Return (SubStr(sInputFile,-7) = .dat.old ? ".old.txt" : ".dat.txt")
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
  Else If (sText = "<Header>" || sText = "" || InStr(sText,"TimeNumber = ") > 0
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
  sPtr := (A_PtrSize ? "Ptr" : "UInt")
	DllCall("Crypt32.dll\CryptStringToBinary", sPtr, &sText, "UInt", StrLen(In)
	, "UInt", 0x1, sPtr, 0, "UInt*", OutLen, sPtr, 0, sPtr, 0)
	VarSetCapacity(Out, OutLen)

	DllCall("Crypt32.dll\CryptStringToBinary", sPtr, &sText, "UInt", StrLen(In)
	, "UInt", 0x1, "Str", Out, "UInt*", OutLen, sPtr, 0, sPtr, 0)

	Return StrGet(&Out, OutLen, "UTF-8")
  }

fBase64_EncodeText(sText)
  {
  sPtr := (A_PtrSize ? "Ptr" : "UInt")
	VarSetCapacity(Bin, StrPut(sText, "UTF-8"))
	DllCall("Crypt32.dll\CryptBinaryToString", sPtr, &Bin
	, "UInt", StrPut(sText, &Bin, "UTF-8")-1, "UInt", 0x40000001, sPtr, 0, "UInt*", PcchString)

	VarSetCapacity(Out, PcchString * (1+A_IsUnicode))
	DllCall("Crypt32.dll\CryptBinaryToString", sPtr, &Bin
	, "UInt", StrPut(sText, &Bin, "UTF-8")-1, "UInt", 0x40000001, "Str", Out, "UInt*", PcchString)

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
