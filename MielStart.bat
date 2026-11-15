@echo off
rem Starts Miel Monteur - Recht Door Zee! with the dialogue fix. Needs 32-bit PowerShell.
"%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0MielStart.ps1" %*
if errorlevel 1 pause
