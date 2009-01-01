@echo off
cls
REM del /Q *.obj 2> NUL
del tccide.exe 2> NUL
del /q tccide.map 2> NUL
dfl -release src\*.d src\tccide.res -oftccide
IF ERRORLEVEL 1 GOTO error
if NOT EXIST tccide.exe GOTO end
REM upx tccide.exe
:end
del /Q *.obj 2> NUL
del /q tccide.map 2> NUL
tccide.exe
GOTO end2

:error
del tccide.exe

:end2
