#NoEnv
#NoTrayIcon
#SingleInstance Ignore
#KeyHistory 0
SetBatchLines -1
Process Priority,,A
ListLines Off

iInputAmount = %0%
If (iInputAmount = 0)
  {
  MsgBox You need to drag and drop a .dat file onto the exe
  ExitApp
  }
SetWorkingDir %A_ScriptDir%

Loop %0%
  {
  Loop % %A_Index%,1
    {
    If (InStr(FileExist(A_LoopFileLongPath),"D") = 0)
      InputFiles(A_LoopFileLongPath)
    }
  }
Return

InputFiles(FILE)
{
  FileRead sSaveGame,%FILE%
  sOutFile := ""

  ;abort
  If (InStr(sSaveGame,"SteamID") = 0 && InStr(sSaveGame,"oEverythingGun") = 0 && InStr(sSaveGame,"Trait") = 0 && InStr(sSaveGame,"Character") = 0)
    {
    SplitPath FILE,OutFileName
    MsgBox This file is (probably) already encoded!`n`n%OutFileName%
    ExitApp
    }

  ;number of files at the start to skip
  If (InStr(sSaveGame,"SteamID") > 0 && InStr(sSaveGame,"PersonaName") > 0)
    sWhichFile := 0 ;SharedData.dat
  Else If (InStr(sSaveGame,"Encoded") = 0 && InStr(sSaveGame,"TimeNumber") > 0)
    sWhichFile := 3 ;Progress.dat
  Else
    sWhichFile := 4 ;chars/items

  Loop Parse,sSaveGame,`n,`r
    {
    ;ignore the lines that don't need to be encoded
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

  ;remove blank lines from end of file
  Loop
    {
    TestLine := SubStr(sOutFile,-1)
    If (TestLine = "`r`n")
      sOutFile := SubStr(sOutFile,1,-2)
    Else
      Break
    }

  ;get filename for rename/replace
  sNewString = %FILE%
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

;https://github.com/ahkscript/libcrypt.ahk
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

