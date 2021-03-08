#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
; SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.


RunWait, %ComSpec% /c PhaDeadlineVisualizer.exe hidden >>temp.txt
while image = ""
{
    FileReadLine, image, temp.txt, 1
    Sleep, 500
}
FileDelete, temp.txt



m := ComObjCreate("Outlook.Application").CreateItem(0)
Loop, read, emails.txt
{
    m.Recipients.Add(Trim(A_LoopReadLine))
}
m.Attachments.Add(A_WorkingDir . "\" . image)
m.Subject := "Daily Deadline Check"
m.Body := "Here is your automated daily deadline check."

;m.Display ; Comment out to not show the window before sending
m.Send



if !FileExist("Archived")
    FileCreateDir, Archived
FileMove, %image%, Archived\%image%