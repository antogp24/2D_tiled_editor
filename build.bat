@echo off

IF "%~1"=="" GOTO DEBUG
IF "%~1"=="debug" GOTO DEBUG
IF "%~1"=="release" GOTO RELEASE

:DEBUG
del *.pdb
odin build src -out:bin/game_editor.exe -debug -define:AUTO_SAVE=true -show-timings
echo Done building game_editor in debug mode.
GOTO DONE

:RELEASE
odin build src -out:bin/game_editor.exe -o:speed -show-timings -subsystem:windows -define:AUTO_SAVE=true
echo Done building game_editor in release mode.
GOTO DONE

:DONE
if %ERRORLEVEL%==0 bin\game_editor.exe