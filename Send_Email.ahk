#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

image := "PHA_Milestones_27-02-2021_16-36-37.png"
imagePath = %A_ScriptDir%\%image%
emails = %A_ScriptDir%\emails.txt

m := ComObjCreate("Outlook.Application").CreateItem(0)

Loop, read, %emails%
{
    m.Recipients.Add(Trim(A_LoopReadLine))
}

m.Attachments.Add(imagePath)

m.Subject := "Daily Deadline Check"
m.Body := "Here is your daily automated deadline check."

;m.HTMLBody := <img src="%imagePath%" alt="%image%">

m.Display ; Comment out to not show the window before sending
;m.Send