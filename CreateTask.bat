SCHTASKS /CREATE /SC DAILY /TN "PHADeadlineEmailer" /TR "%cd%\SendEmail.exe" /ST 05:00
pause