#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance Force


outlook := ComObjCreate("Outlook.Application")
RunWait, %ComSpec% /c PhaDeadlineVisualizer.exe hidden >>temp.txt
while image = ""
{
    FileReadLine, image, temp.txt, 1
    Sleep, 500
}
FileDelete, temp.txt



mail := outlook.CreateItem(0)
Loop, read, emails.txt
{
    if !(SubStr(A_LoopReadLine, 1, 1) = "#")
    {
        mail.Recipients.Add(Trim(A_LoopReadLine))
    }
}
mail.Attachments.Add(A_WorkingDir "\" image)
mail.Subject := "Daily Deadline Check"
mail.Body := "Here is your automated daily deadline check."

;mail.Display ; Comment out to not show the window before sending
mail.Send



Sleep, 1000
if not FileExist("Archived")
    FileCreateDir, Archived
FileMove, %image%, Archived\%image%