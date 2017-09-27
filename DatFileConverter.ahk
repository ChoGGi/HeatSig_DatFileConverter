#NoEnv
#NoTrayIcon
#SingleInstance Force
;#SingleInstance Off
#KeyHistory 0
SetBatchLines -1
Process Priority,,A
ListLines Off

;no files dropped on exe so we open GUI
If %0% = 0
  GoSub lStartGUI
Else ;loop through input file(s)
  {
  Loop %0%
    {
    Loop % %A_Index%,1
      {
      If (InStr(FileExist(A_LoopFileLongPath),"D") = 0)
        fInputFiles(A_LoopFileLongPath)
      }
    }
  ExitApp
  }
Return

Global sHeatSigFiles,sSteamLoc,sWorkshopFiles,ScanSteamWorkshop,Editor

lStartGUI:
  sScriptName := A_ScriptDir "\" SubStr(A_ScriptName,1,-3) "ini"
  IniRead Editor,%sScriptName%,Settings,Editor,%A_Space%
  IniRead DisableWarnings,%sScriptName%,Settings,DisableWarnings,0
  IniRead ScanSteamWorkshop,%sScriptName%,Settings,ScanSteamWorkshop,1
  IniRead ManualRefresh,%sScriptName%,Settings,ManualRefresh,0

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
  sButtonRefresh_TT := "Refreshes file list"
  sButtonEdit_TT := "Edits first selected file"
  sButtonRecycleOld_TT := "Any .dat.old files in current folder are sent to the Recycle Bin"
  sButtonConvert_TT := "Converts selected files`nUse Ctrl+Click to select multiple files`n`nWARNING: If you select file.dat and file.dat.txt, then this will convert from the top of the list down (probably overwriting the wrong file)!"
  sCheckboxScanSteam_TT := "Adds files from friends (from Steam Workshop)"
  sCheckboxManRefresh_TT := "Only refresh file list when you click Refresh List"
  sMyListView_TT := "Double click to Decode/Encode`nDouble right-click to Recycle."

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

  Gui Show,w570,%sHeatSigFiles%
  ;for tooltips
  OnMessage(0x200,"WM_MOUSEMOVE")
Return

lMyTreeView:
lButtonRefresh:
  sTreeItem := fSelectTreeItem()
  fPopulateListView(sTreeItem)
Return

lButtonRecycleOld:
  StatusBarGetText sCurrentDir,3
  If (DisableWarnings = True)
    FileRecycle %sCurrentDir%\*.dat.old
  Else
    {
    MsgBox 4097,Send to Recycle Bin?,Recycle all .dat.old files in current folder?
    IfMsgBox OK
      FileRecycle %sCurrentDir%\*.dat.old
    }
  If (ManualRefresh = False)
    GoSub lButtonRefresh
Return

lButtonConvert:
  iRowNumber := 0
  Loop
    {
    iRowNumber := LV_GetNext(iRowNumber)
    If not iRowNumber
      Break
    LV_GetText(sSelectedFile,iRowNumber,3)
    fInputFiles(sSelectedFile)
    }
  If (ManualRefresh = False)
    GoSub lButtonRefresh
Return

lCheckboxScanSteam:
  ScanSteamWorkshop := fBoolToggle(ScanSteamWorkshop)
  IniWrite %ScanSteamWorkshop%,%sScriptName%,Settings,ScanSteamWorkshop
  fPopulateTreeView()
Return

lCheckboxManRefresh:
  ManualRefresh := fBoolToggle(ManualRefresh)
  IniWrite %ManualRefresh%,%sScriptName%,Settings,ManualRefresh
Return

lButtonEdit:
  LV_GetText(sSelectedFile,LV_GetNext(),3)
  SplitPath sSelectedFile,,sOutDir,sExt,sOutNameNoExt
  fStartEditor(sOutDir "\",sOutNameNoExt,"." sExt)
Return

GuiSize:
  If A_EventInfo := 1
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
  If (A_GuiEvent = "DoubleClick")
    {
    If (Editor = "")
      fEditorGUI(sOutDir "\",sOutNameNoExt,"." sExt)
    Else
      {
      sNewExt := fInputFiles(sClickedFile)
      If (sNewExt != False)
        fStartEditor(sOutDir "\",sOutNameNoExt,sNewExt)
      }
    }
  ;dbl right click to recycle
  Else If (A_GuiEvent = "R")
    {
    If (DisableWarnings = True)
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
  If (sFileListA != sFileListB && ManualRefresh = False)
    GoSub lButtonRefresh
Return

fStartEditor(sDir,sFile,sExt)
  {
  If (Editor = "")
    fEditorGUI(sDir,sFile,sExt)
  Else
    Run %Editor% "%sDir%%sFile%%sExt%"
  }

GuiEscape:
GuiClose:
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
  If (sFileListA != sFileListB && ManualRefresh = False)
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
  If (sSelectedFile != "")
    {
    If (SubStr(sSelectedFile,-3) = ".dat")
      fSaveEncodeText(sSelectedFile ".txt",sFileEditor)
    Else
      FileAppend %sFileEditor%,%sSelectedFile%
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
  If A_EventInfo := 1
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
  If (sExt = ".dat")
    sInputText := fDecodeText(sInputText)
  Else If (sExt = ".old")
    {
    If (SubStr(sFile,-3) = ".dat")
      sInputText := fDecodeText(sInputText)
    }

  Gui oEditorWin:New,+LastFound +Resize +OwnDialogs,Editing %sFile%%sExt%

  If (sExt = ".dat")
    sButtonSaveFile := sFile sExt ".txt"
  Else If (sExt = ".old")
    sButtonSaveFile := sFile sExt ".txt"
  Else
    sButtonSaveFile := sFile sExt
  Gui Add,Button,xm ym +Disabled glButtonSaveFile vsButtonSaveFile,&Save as %sButtonSaveFile%
  If (SubStr(sFile sExt,-7) = ".dat.txt")
    sButtonSaveDatFile := sFile
  Else If (sExt = ".old")
    sButtonSaveDatFile := sFile sExt ".dat"
  Else If (sExt = ".txt")
    sButtonSaveDatFile := sFile sExt ".dat"
  Else
    sButtonSaveDatFile := sFile sExt
  Gui Add,Button,x+m +Disabled glButtonSaveDatFile vsButtonSaveDatFile,&Save as %sButtonSaveDatFile%
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
  If (bBool = 1)
    bBool := 0
  Else
    bBool := 1
  Return bBool
  }

fPopulateTreeView()
  {
  TV_Delete()
  GuiControl -Redraw,sMyTreeView
  SplashTextOn 200,25,%A_ScriptName%,Loading...
  fAddSubFoldersToTree(sHeatSigFiles,,True)
  If (ScanSteamWorkshop = True)
    {
    Loop Parse,sWorkshopFiles,`n,`r
      fAddSubFoldersToTree(A_LoopField)
    }
  SplashTextOff
  GuiControl +Redraw,sMyTreeView
  }

fAddSubFoldersToTree(sFolder,iParentItemID = 0,bHSFiles = False)
  {
  Loop Files,%sFolder%\*.*,D
    {
    If (bHSFiles = True)
      fAddSubFoldersToTree(A_LoopFileFullPath,TV_Add(A_LoopFileName,iParentItemID,"Icon1"),True)
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
    If not iParentID
      Break
    TV_GetText(sParentText, iParentID)
    sSelectedItemText := sParentText "\" sSelectedItemText
    }
    ;bold is a steam workshop folder
    If (TV_Get(TV_GetSelection(),"Bold") = 0)
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
      If (A_Index < 3 || A_LoopField = "")
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
    if (InStr(sSaveGame,"U3RlYW1JRCA9") > 0 || InStr(sSaveGame,"PENoYXJhY3Rlcj4=") > 0
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
  ;loop through each line and decode it
  Loop Parse,sText,`n,`r
    {
    ;ignore the lines that don't need to be decoded
    If (fCheckText(A_LoopField,A_Index) = True)
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
  If (SubStr(sInputFile,-7) = ".dat.old")
    Return ".old.txt"
  Else
    Return ".dat.txt"
  }

fEncodeText(sText)
  {
  Loop Parse,sText,`n,`r
    {
    If (fCheckText(A_LoopField,A_Index) = True)
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
  If (InStr(sNewString,".dat.txt") > 0)
    sExt := InStr(sNewString,".dat.txt")
  Else
    sExt := InStr(sNewString,".old.txt")
  StringLeft sNewString,sNewString,% sExt
  sNewString := sNewString "dat"

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
  If (iIndex > 4)
    Return False
  Else If (sText = "<Header>" || sText = "" || InStr(sText,"TimeNumber = ") > 0
      || InStr(sText,"Encoded = 1") > 0 || RegExMatch(sText,"^Time\s=\s") > 0)
    Return True
  }

;remove blank lines from end of var
fRemoveBlank(sText)
  {
  Loop
    {
    If (SubStr(sText,-1) = "`r`n")
      sText := SubStr(sText,1,-2)
    Else
      Break
    }
  Return sText
  }

;https://github.com/ahkscript/libcrypt.ahk
fBase64_DecodeText(sText)
  {
	DllCall("Crypt32.dll\CryptStringToBinary", "Ptr", &sText, "UInt", StrLen(In)
	, "UInt", 0x1, "Ptr", 0, "UInt*", OutLen, "Ptr", 0, "Ptr", 0)
	VarSetCapacity(Out, OutLen)

	DllCall("Crypt32.dll\CryptStringToBinary", "Ptr", &sText, "UInt", StrLen(In)
	, "UInt", 0x1, "Str", Out, "UInt*", OutLen, "Ptr", 0, "Ptr", 0)

	Return StrGet(&Out, OutLen, "UTF-8")
  }

fBase64_EncodeText(sText)
  {
	VarSetCapacity(Bin, StrPut(sText, "UTF-8"))
	DllCall("Crypt32.dll\CryptBinaryToString", "Ptr", &Bin
	, "UInt", StrPut(sText, &Bin, "UTF-8")-1, "UInt", 0x40000001, "Ptr", 0, "UInt*", PcchString)

	VarSetCapacity(Out, PcchString * (1+A_IsUnicode))
	DllCall("Crypt32.dll\CryptBinaryToString", "Ptr", &Bin
	, "UInt", StrPut(sText, &Bin, "UTF-8")-1, "UInt", 0x40000001, "Str", Out, "UInt*", PcchString)

	Return Out
  }

;from ahk manual
;GUI Example: Display context-senstive help (via ToolTip)
WM_MOUSEMOVE()
  {
  Static CurrControl,PrevControl,_TT
  CurrControl := A_GuiControl
  If (CurrControl <> PrevControl and not InStr(CurrControl, " "))
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
