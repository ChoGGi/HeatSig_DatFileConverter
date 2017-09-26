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

;loop through input file(s)
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
  If (InStr(sSaveGame,"SteamID") > 0 || InStr(sSaveGame,"oEverythingGun") > 0 || InStr(sSaveGame,"Trait") > 0 || InStr(sSaveGame,"Character") > 0)
    {
    SplitPath FILE,OutFileName
    MsgBox This file is (probably) already decoded!`n`n%OutFileName%
    ExitApp
    }

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
  ;delete any old .dat.txt file so we create a new rather than append
  FileDelete %FILE%.txt
  FileAppend %sOutFile%,%FILE%.txt
}

;https://github.com/ahkscript/libcrypt.ahk
Base64_DecodeText(Text)
{
	DllCall("Crypt32.dll\CryptStringToBinary", "Ptr", &Text, "UInt", StrLen(In)
	, "UInt", 0x1, "Ptr", 0, "UInt*", OutLen, "Ptr", 0, "Ptr", 0)
	VarSetCapacity(Out, OutLen)
	DllCall("Crypt32.dll\CryptStringToBinary", "Ptr", &Text, "UInt", StrLen(In)
	, "UInt", 0x1, "Str", Out, "UInt*", OutLen, "Ptr", 0, "Ptr", 0)
	return StrGet(&Out, OutLen, "UTF-8")
}
