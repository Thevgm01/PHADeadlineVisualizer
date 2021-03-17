SCHTASKS /CREATE /SC DAILY /TN "PHADeadlineEmailer" /TR "%cd%\SendEmail.exe" /ST 08:00
pause