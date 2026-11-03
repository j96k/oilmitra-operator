@echo off
REM Local helper. If Flutter is not on PATH, set FLUTTER_HOME below or in your shell.
REM Example: set "FLUTTER_HOME=C:\src\flutter"
if defined FLUTTER_HOME set "PATH=%FLUTTER_HOME%\bin;%PATH%"
if not defined PUB_CACHE set "PUB_CACHE=%~dp0.pub-cache"
