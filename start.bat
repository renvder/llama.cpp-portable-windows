@echo off
chcp 65001 >nul
cd /d "%~dp0"

rem Always use the Windows PowerShell 5.1 shipped with Windows 11.
rem The launcher itself handles execution-policy and downloaded-file blocking.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0llama-oneclick.ps1"

pause
